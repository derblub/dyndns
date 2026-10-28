# Security policy

## Supported versions

Security fixes go into `master`. Please update before reporting.

## Reporting a vulnerability

Please do not open a public issue. Report it privately through [GitHub's vulnerability reporting](https://github.com/derblub/dyndns/security/advisories/new) or by email to [daniel@pushingpixels.at](mailto:daniel@pushingpixels.at).

You will get an answer within five working days. Once a fix is released, the report is credited in the changelog unless you prefer otherwise.

## What the script does with your data

dyndns runs on your machine and keeps its state in two files you choose, `LOG_FILE` and `LAST_WAN_IP`. It talks to these hosts, and only to these:

- `google.at`, a `wget --spider` request to see whether the machine is online.
- The DNS servers in `DNS_RESOLVER` (by default `resolver1.opendns.com`, which answers with your WAN IP) and your normal resolver, which it asks for the current A record of `DOMAIN`.
- `REMOTEHOST` over SSH, with the key in `IDENTITY`. There it runs `mysql` to read and change the A record in the Plesk database, and `/opt/psa/admin/bin/dnsmng` to apply it. The address from the DNS answer only goes there after the script has checked that it is a single IPv4 address.
- `SMTPSERVER`, to send the notification mails. The script logs in with `SMTPUSER` and `SMTPPASSWORD` after STARTTLS, but tells `mailx` not to verify the server's certificate (`ssl-verify=ignore`). Use an SMTP account that only sends these mails.

The configuration file holds the SMTP password, so keep it readable for your user only (`chmod 600 ~/.config/dyndns/config`) and outside any repository. From cron, the script needs an SSH key without a passphrase for a user on the Plesk server who can change DNS records. Keep that key on a machine only you use.
