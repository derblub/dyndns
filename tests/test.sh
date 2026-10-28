#!/bin/bash
#
# Runs dyndns.sh against stub commands (ssh, dig, mailx, wget, ssh-agent, ...)
# and checks what it does in each case. Nothing leaves the machine.
#
# Usage: tests/test.sh

# The single-quoted strings are code for the stubs and test input; they must not expand here.
# shellcheck disable=SC2016

set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
FAILED=0
N=0

# --- stubs -------------------------------------------------------------------
# Every stub appends one line to $CALLS: its name and arguments, separated by |.
mkdir "$WORK/bin"
stub(){
    printf '#!/bin/bash\nprintf "%%s|" "$(basename "$0")" "$@" >> "$CALLS"; echo >> "$CALLS"\n%s\n' "$2" > "$WORK/bin/$1"
    chmod +x "$WORK/bin/$1"
}
stub date      'echo "28-10-2026 12:00:00"'
stub wget      'exit "${FAKE_WGET:-0}"'
stub sleep     ':'
stub ssh-add   ':'
stub ssh-agent '[ "${1-}" = -k ] && exit 0
printf "SSH_AUTH_SOCK=/tmp/stub.sock; export SSH_AUTH_SOCK;\nSSH_AGENT_PID=4242; export SSH_AGENT_PID;\necho Agent pid 4242;\n"'
stub dig       'case "$*" in *myip*) printf "%b" "${FAKE_MY_IP-}";; *) printf "%b" "${FAKE_DNS_IP-}";; esac'
stub ssh       'case "$*" in *SELECT\ id*) printf "%b" "${FAKE_ROW-}";; *UPDATE*) printf "ROW_COUNT()\n%s\n" "${FAKE_COUNT-1}";; esac'
stub mailx     'cat > /dev/null'

# --- helpers -----------------------------------------------------------------
# run NAME [VAR=value ...]: runs the script with a fresh configuration and state
run(){
    CASE=$1; shift
    CASE_FAILED=0
    N=$((N + 1))
    DIR=$WORK/case$N
    mkdir -p "$DIR/state"
    cat > "$DIR/config" << EOF
DNS_RESOLVER="myip.opendns.com @resolver1.opendns.com"
DNS_TABLE="psa.dns_recs"
REMOTEUSER="user"
REMOTEHOST="plesk.example.com"
MAILTO="you@example.com"
SMTPSERVER="smtp.example.com"
SMTPPORT="587"
SMTPFROM="dyndns@example.com"
SMTPUSER="dyndns@example.com"
SMTPPASSWORD="secret"
IDENTITY="/keys/id_ed25519"
DOMAIN="home.example.com"
LOG_FILE="$DIR/state/dyndns.log"
LAST_WAN_IP="$DIR/state/last-ip"
EOF
    [ -n "${LAST:-}" ] && echo "$LAST" > "$DIR/state/last-ip"
    : > "$DIR/calls"
    env -i HOME="$DIR" PATH="$WORK/bin:/usr/bin:/bin" CALLS="$DIR/calls" \
        DYNDNS_CONFIG="$DIR/config" "$@" bash "$ROOT/dyndns.sh" > "$DIR/out" 2>&1
    STATUS=$?
}

fail(){
    echo "FAIL $CASE: $1"
    CASE_FAILED=1
    FAILED=1
}
expect_status(){ [ "$STATUS" = "$1" ] || fail "exit code $STATUS, expected $1"; }
expect_call(){ grep -qF -- "$1" "$DIR/calls" || fail "no call matching: $1"; }
expect_no_call(){ ! grep -qF -- "$1" "$DIR/calls" || fail "unexpected call: $1"; }
expect_log(){ grep -qF -- "$1" "$DIR/state/dyndns.log" 2> /dev/null || fail "log lacks: $1"; }
expect_agent_stopped(){ expect_call "ssh-agent|-k|"; }
done_case(){ [ "$CASE_FAILED" = 1 ] || echo "ok   $CASE"; }

# --- cases -------------------------------------------------------------------
LAST=1.2.3.4 run unchanged FAKE_MY_IP='1.2.3.4\n' FAKE_DNS_IP='1.2.3.4\n'
expect_status 1
expect_no_call "ssh|"
expect_no_call "mailx|"
expect_agent_stopped
done_case

LAST=1.1.1.1 run changed FAKE_MY_IP='1.2.3.4\n' FAKE_DNS_IP='1.1.1.1\n' FAKE_ROW='7\t1.1.1.1\n'
expect_status 0
expect_call "UPDATE psa.dns_recs SET val='1.2.3.4', displayVal='1.2.3.4' WHERE id=7;"
expect_call "/opt/psa/admin/bin/dnsmng|--update|home.example.com|"
expect_call "mailx|-s|[dyndns] new IP: 1.2.3.4|"
expect_log "new IP: 1.2.3.4"
[ "$(cat "$DIR/state/last-ip")" = 1.2.3.4 ] || fail "last-ip not saved"
expect_agent_stopped
done_case

LAST=1.1.1.1 run update-failed FAKE_MY_IP='1.2.3.4\n' FAKE_DNS_IP='1.1.1.1\n' FAKE_ROW='7\t1.1.1.1\n' FAKE_COUNT=0
expect_status 1
expect_no_call "dnsmng"
expect_log "ERROR: update from 1.1.1.1 to 1.2.3.4 failed"
expect_agent_stopped
done_case

LAST=1.1.1.1 run no-connection FAKE_MY_IP='1.2.3.4\n' FAKE_DNS_IP='1.1.1.1\n' FAKE_ROW=''
expect_status 1
expect_no_call "UPDATE"
expect_log "ERROR: Couldn't connect to user@plesk.example.com"
expect_agent_stopped
done_case

run no-ip FAKE_MY_IP='' FAKE_DNS_IP='1.1.1.1\n'
expect_status 1
expect_no_call "ssh|"
expect_log "ERROR: \$MY_IP is unset or an empty string"
expect_agent_stopped
done_case

# An answer that is not one IPv4 address must never reach SQL or the remote shell.
for bad in '1.2.3.4`touch /tmp/pwned`' "1.2.3.4'; DROP TABLE dns_recs; --" '1.2.3.4\n5.6.7.8' '256.1.1.1' 'evil.example.com.'; do
    LAST=1.1.1.1 run "rejects:$bad" FAKE_MY_IP="$bad\n" FAKE_DNS_IP='1.1.1.1\n' FAKE_ROW='7\t1.1.1.1\n'
    expect_status 1
    expect_no_call "ssh|"
    expect_call "mailx|-s|[dyndns] update error|"
    expect_log "returned no single IPv4 address"
    expect_agent_stopped
    done_case
done

exit $FAILED
