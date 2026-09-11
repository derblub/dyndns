#!/bin/bash
#
# Author: Daniel Kurdoghlian (daniel.k@pushingpixels.at)
# Upstream: https://github.com/derblub/dyndns
# Version: 0.2

# SETTINGS
# -----------------------------------------------------------------------------



# resolver is used to get your current wan-ip
# --- configuration -------------------------------------------------------
# All settings live outside the repository: ~/.config/dyndns/config
# (see config.example). Override the location with DYNDNS_CONFIG.
CONFIG="${DYNDNS_CONFIG:-$HOME/.config/dyndns/config}"
if [ -r "$CONFIG" ]; then
    . "$CONFIG"
else
    echo "dyndns: configuration not found: $CONFIG (see config.example)" >&2
    exit 1
fi



DATE=$(date "+%d-%m-%Y %T")            # date format for log

# -----------------------------------------------------------------------------
# end SETTINGS


# add identity for keyless authentication
eval $(ssh-agent)
ssh-add $IDENTITY

touch $LAST_WAN_IP

write_log(){
    while read text
    do
        # If log file is not defined, just echo the output
        if [ "$LOG_FILE" == "" ]; then
            echo $DATE": $text"
        else
            touch $LOG_FILE
            if [ ! -f $LOG_FILE ]; then
                echo "ERROR! Couldn't create $LOG_FILE"
                exit 1
            fi
            echo $DATE": $text" | tee --append $LOG_FILE
        fi
    done
}

write_wan_ip(){
    while read text
    do
        if [ ! -f $LAST_WAN_IP ]; then
            echo "ERROR! Couldn't create LAST_WAN_IP"
            exit 1
        fi
        echo "$text" > $LAST_WAN_IP
    done
}

send_mail(){
    subject=$1
    body=$2
    cat << EOF | mailx \
                        -s "[dyndns] $subject" \
                        -r "$SMTPFROM" \
                        -S smtp="smtp://$SMTPSERVER:$SMTPPORT" \
                        -S smtp-use-starttls \
                        -S smtp-auth=login \
                        -S smtp-auth-user="$SMTPUSER" \
                        -S smtp-auth-password="$SMTPPASSWORD" \
                        -S ssl-verify=ignore \
                        $(echo ${MAILTO[@]} | tr ' ' ',')
$body
EOF
}

wget -q --tries=10 --timeout=20 --spider https://google.at
if [[ $? -eq 0 ]]; then
    #echo "Online"
    :
else
    #wait some time..
    sleep 30
    #echo "Offline"
    #exit 1
fi


MY_IP=$(dig +short $DNS_RESOLVER)
LAST_SAVED_WAN_IP=$(cat $LAST_WAN_IP)
CURRENT_DNS_IP=$(dig +short $DOMAIN)


# compare 3rd-party ip to last-saved ip, cross check with saved dns
if [[ ${MY_IP} == ${LAST_SAVED_WAN_IP} && ${MY_IP} == ${CURRENT_DNS_IP} ]]; then
    # no output if no errors
    #echo $'all good, nothing to do here! \n\n[image of stickman with jetpack straped on, flying away]'
    exit 1
fi

# check if we really got an IP from $MY_IP
if [[ -z ${MY_IP} ]]; then  # -z == zero-length string
    # lets try again before we quit:
    MY_IP=$(dig +short $DNS_RESOLVER)

    if [[ -z ${MY_IP} ]]; then
        # too bad - still no IP
        echo "ERROR: \$MY_IP is unset or an empty string" | write_log
        send_mail "update error" "$DATE ERROR: \$MY_IP is unset or an empty string"
        exit 1
    fi
fi


# get the row-id of the DNS A-record for $DOMAIN
DNS_ID_VAL=$(ssh $REMOTEUSER@$REMOTEHOST mysql --batch --skip-column-names -e "\"SELECT id, val FROM $DNS_TABLE WHERE host = '$DOMAIN.' AND type = 'A';\"")

if [[ ${DNS_ID_VAL} ]]; then
    # data found in table $DNS_TABLE
    ROW_ID=$(echo "$DNS_ID_VAL" | cut -d$'\t' -f1)
    DNS_IP=$(echo "$DNS_ID_VAL" | cut -d$'\t' -f2)

    # ip in db not same as ip we got via 3rd party provider
    if [[ ${DNS_IP} != ${MY_IP} ]]; then
        # dns ip needs update
        echo "row id $ROW_ID in DB $DNS_TABLE needs update"
        UPDATE_DNS=$(ssh $REMOTEUSER@$REMOTEHOST mysql -e "\"UPDATE $DNS_TABLE SET val='$MY_IP', displayVal='$MY_IP' WHERE id=$ROW_ID; SELECT ROW_COUNT();\"")
        ROWS_AFFECTED=$(echo "$UPDATE_DNS" | tr -d "ROW_COUNT() \n")

        if [[ $ROWS_AFFECTED != 0 ]]; then
            echo "ip changed to $MY_IP"

            echo "updating dns cache for $DOMAIN"
            UPDATE_DNS_C=$(ssh $REMOTEUSER@$REMOTEHOST /opt/psa/admin/bin/dnsmng --update $DOMAIN)

            echo $MY_IP | write_wan_ip  # write new ip to $LAST_WAN_IP
            echo "new IP: $MY_IP" | write_log

            send_mail "new IP: $MY_IP" "$DATE: new IP $MY_IP saved"  # send mail with new ip

        else
            echo "ERROR: update from $DNS_IP to $MY_IP failed" | write_log
            send_mail "update error" "$DATE ERROR: update from $DNS_IP to $MY_IP failed"
            exit 1
        fi
    fi
else
    # remote sql query gave no results
    echo "ERROR: Couldn't connect to $REMOTEUSER@$REMOTEHOST" | write_log
    send_mail "connection error" "$DATE ERROR: Couldn't connect to $REMOTEUSER@$REMOTEHOST"
    exit 1
fi
