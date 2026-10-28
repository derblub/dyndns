<div align="center">

<a href="https://pushingpixels.at">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/assets/logo-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="docs/assets/logo-light.svg">
    <img src="docs/assets/logo.svg" alt="Pushing Pixels" width="96">
  </picture>
</a>

<h1>dyndns</h1>

<p><strong>Updates a DNS A record on your Plesk server over SSH when your WAN IP changes.</strong></p>

<p>
  <a href="https://github.com/derblub/dyndns/actions/workflows/ci.yml"><img src="https://github.com/derblub/dyndns/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://www.shellcheck.net"><img src="https://img.shields.io/badge/shellcheck-clean-brightgreen" alt="ShellCheck clean"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-blue" alt="GPL-3.0 License"></a>
</p>

<p>
  <a href="#requirements">Requirements</a> ·
  <a href="#install">Install</a> ·
  <a href="#configuration">Configuration</a> ·
  <a href="#what-happens-on-each-run">How it works</a> ·
  <a href="#tested-with">Tested with</a> ·
  <a href="CHANGELOG.md">Changelog</a>
</p>

</div>

---

If your Plesk server hosts the DNS for your domain anyway, you don't need a dynamic DNS service for the machine at home: a subdomain on your own server will do. I wrote this script to keep such a subdomain pointed at my home connection.

It runs from cron on a machine behind the changing IP, asks OpenDNS for the current WAN IP and, when it changed, writes it into the Plesk database over SSH, tells Plesk to apply it, and sends you a mail.

## Requirements

On the machine that runs the script:

- bash
- the OpenSSH client (`ssh`, `ssh-agent`, `ssh-add`)
- `dig` (in `dnsutils` or `bind-tools`, depending on the distribution)
- `wget`
- a `mailx` that can send through SMTP with `-S smtp=...`, for example s-nail or heirloom-mailx

On the Plesk server:

- an SSH login with a key, for a user that may run `mysql` on the Plesk database and `/opt/psa/admin/bin/dnsmng`. The script runs both without a password prompt, so put the database credentials in that user's `~/.my.cnf`.

## Install

1. In Plesk, create a subdomain for the machine at home, for example `home.example.com`. It needs no hosting, only its A record.
2. Optional: lower the TTL in the subdomain's SOA record, so that a new IP reaches resolvers sooner.
3. Clone this repository on the machine at home:

   ```console
   $ git clone https://github.com/derblub/dyndns ~/dyndns
   ```

4. Copy the example configuration and fill in your values (see [Configuration](#configuration)). The script refuses to run without it.

   ```console
   $ mkdir -p ~/.config/dyndns ~/.local/state
   $ cp ~/dyndns/config.example ~/.config/dyndns/config
   $ chmod 600 ~/.config/dyndns/config
   ```

5. Run it once by hand and check the output, the log and the record in Plesk:

   ```console
   $ ~/dyndns/dyndns.sh
   ```

6. Add it to your crontab (`crontab -e`), for example every five minutes:

   ```
   */5 * * * * $HOME/dyndns/dyndns.sh >> $HOME/.local/state/dyndns.cron.log 2>&1
   ```

   Call the script itself or `bash dyndns.sh`, not `sh dyndns.sh`: it needs bash. Every run prints the messages of `ssh-agent` and `ssh-add`; the redirect keeps cron from mailing them to you every five minutes. Errors still reach you by mail and in `LOG_FILE`.

## Configuration

The script reads `~/.config/dyndns/config`. To use another file, set `DYNDNS_CONFIG`, for example `DYNDNS_CONFIG=/etc/dyndns.conf dyndns.sh`. The file is sourced by bash, so it uses shell syntax.

| Setting | What it is |
| --- | --- |
| `DNS_RESOLVER` | The `dig` query that returns your WAN IP. Keep `myip.opendns.com @resolver1.opendns.com` unless you have another service that answers the same way. |
| `DNS_TABLE` | The table with the DNS records in the Plesk database: `psa.dns_recs`. |
| `REMOTEUSER`, `REMOTEHOST` | The SSH login on the Plesk server. |
| `IDENTITY` | The SSH key for that login. It must not have a passphrase when the script runs from cron. |
| `DOMAIN` | The record to update, without the trailing dot, for example `home.example.com`. |
| `MAILTO` | Who gets the notification mails. Several addresses separated by spaces, or a bash array. |
| `SMTPSERVER`, `SMTPPORT`, `SMTPFROM`, `SMTPUSER`, `SMTPPASSWORD` | The SMTP account that sends the mails. The script uses STARTTLS. |
| `LOG_FILE` | Where changes and errors are logged. Leave it empty to only print them. |
| `LAST_WAN_IP` | The file that keeps the last IP the script saved. |

## What happens on each run

1. The script reads the configuration, starts an `ssh-agent` and adds the key from `IDENTITY`.
2. It checks whether the machine is online (a `wget --spider` request to `google.at`). If not, it waits 30 seconds and goes on anyway.
3. It asks `DNS_RESOLVER` for the WAN IP and looks up the current A record of `DOMAIN`. If both match the IP in `LAST_WAN_IP`, it stops without further output.
4. If it got no WAN IP, it tries once more, then logs the error, sends a mail and stops. It also stops with an error when the answer is anything but a single IPv4 address, because the address goes into an SQL statement and a command line on the server.
5. Over SSH, it reads the A record of `DOMAIN` from `DNS_TABLE`. If it gets nothing back (no connection, or no such record), it logs a connection error, sends a mail and stops.
6. If the record in the database differs from the WAN IP, it updates the record, runs `dnsmng --update` for `DOMAIN` so that Plesk applies it, saves the IP in `LAST_WAN_IP`, logs it and sends a mail. If the database reports no changed row, it logs and mails that error.

However the run ends, the script stops the `ssh-agent` it started.

The exit code is 1 when nothing changed, as well as on errors, so don't use it to detect failures; the log and the mails are the reliable signal.

## Tested with

- Plesk 10
- Plesk 11.5

Both in 2015. For any other version, check first that `psa.dns_recs` has the columns `host`, `type`, `val` and `displayVal` and that Plesk still uses them, and that `/opt/psa/admin/bin/dnsmng` exists. Without `dnsmng`, you have to make your name server reload the zone yourself.

## Contributing

A report from a Plesk version not listed above is the most useful contribution. See [CONTRIBUTING.md](CONTRIBUTING.md) for how to test changes, and the [Code of Conduct](CODE_OF_CONDUCT.md). Security issues go through [SECURITY.md](SECURITY.md), which also lists every host the script talks to.

## License

[GPL-3.0](LICENSE) © Daniel Kurdoghlian, Pushing Pixels

---

<div align="center">
  <a href="https://pushingpixels.at">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="docs/assets/pushing-pixels-dark.svg">
      <source media="(prefers-color-scheme: light)" srcset="docs/assets/pushing-pixels-light.svg">
      <img src="docs/assets/pushing-pixels.svg" alt="Pushing Pixels" width="320">
    </picture>
  </a>
  <p>Built and maintained by <a href="https://pushingpixels.at">Daniel Kurdoghlian</a> at <a href="https://pushingpixels.at">Pushing Pixels</a> in Vienna.<br>
  I build <a href="https://pushingpixels.at/creates/devops-and-infra">infrastructure that deploys the same way every time</a>, and the pipelines around it.</p>
</div>
