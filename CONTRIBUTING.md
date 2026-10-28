# Contributing

Thanks for taking the time. Reports from a Plesk version I have not tested are the most useful contribution: the script writes straight into the Plesk database, so it depends on its table layout.

## Reporting a problem

Open an [issue](https://github.com/derblub/dyndns/issues/new/choose) with:

- the output of the run and the matching lines from `LOG_FILE`, with host names and addresses removed,
- your Plesk version and the system the script runs on.

## Development setup

There is nothing to build. You need bash, [ShellCheck](https://www.shellcheck.net) and a Plesk server you may change DNS records on.

```console
$ git clone https://github.com/derblub/dyndns
$ cd dyndns
$ cp config.example /tmp/dyndns-test.conf    # point it at a test subdomain
$ DYNDNS_CONFIG=/tmp/dyndns-test.conf ./dyndns.sh
```

`DYNDNS_CONFIG` keeps your test configuration apart from the one in `~/.config/dyndns/config`. Use a subdomain that nothing else depends on.

Before you open a pull request:

```console
$ bash -n dyndns.sh tests/test.sh
$ shellcheck -x dyndns.sh tests/test.sh
$ tests/test.sh
```

CI runs the same checks. `-x` lets ShellCheck read `config.example`, so a new setting belongs in that file too.

`tests/test.sh` needs no server: it runs `dyndns.sh` with stubs for `ssh`, `dig`, `mailx`, `wget` and `ssh-agent` in front of `PATH`, records every call, and checks what the script did in each case. A change in behaviour needs a case there.

## Where things live

| File | What it does |
| --- | --- |
| `dyndns.sh` | The script: finds the WAN IP, compares it with the last one and the DNS record, and updates the record in the Plesk database over SSH |
| `config.example` | Every setting with an example value. Copy it to `~/.config/dyndns/config` |
| `tests/test.sh` | Runs the script against stubs and checks each case: unchanged IP, update, failed update, no connection, no IP, and answers that are not an IPv4 address |

## Pull requests

- One topic per pull request. Say which Plesk version you tested it with.
- Keep existing configurations working: a new setting needs a default, or a note in `CHANGELOG.md` on what to add.
- Describe the user-visible change in `CHANGELOG.md` under "Unreleased".
- By contributing you agree that your contribution is licensed under the [GNU General Public License v3.0](LICENSE).

Everyone taking part is expected to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
