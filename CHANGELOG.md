# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). There are no tagged releases; the versions below are the ones named in the script.

## [Unreleased]

### Added

- CI checks `dyndns.sh` with `bash -n` and ShellCheck on every push and pull request, and Dependabot keeps the GitHub Actions current.
- `tests/test.sh` runs the script against stubs for `ssh`, `dig`, `mailx` and the other commands and checks each case, including forged DNS answers. CI runs it too.
- `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, issue and pull request templates.

### Changed

- The license is now the GNU General Public License v3.0 (GPL-3.0), in `LICENSE` with the unchanged standard text. Up to this change, `LICENSE.md` held the text of the GNU Lesser General Public License v3.0, although the commit that added it in 2015 named the GPL. Every version before this change stays available under LGPL-3.0, so existing forks and copies keep the terms they were made under.
- The configuration lives outside the script, in `~/.config/dyndns/config` (see `config.example`), or wherever `DYNDNS_CONFIG` points. The script stops with an error when the file is missing. The repository no longer holds credentials, not even placeholders. (2026-09-11)
- Before it looks up the IP, the script checks whether the machine is online, and waits 30 seconds when it is not. (2026-09-11)
- The messages of `ssh-agent` and `ssh-add` are no longer hidden. (2026-09-11)
- No output when the IP has not changed. (2017-01-05)
- The notification mail names the new IP in its body, not only in the subject. (2016-01-06)
- `dyndns.sh` passes ShellCheck. Variables are quoted where splitting them was never intended; `DNS_RESOLVER` and `MAILTO` are still split on purpose. The behaviour is unchanged.
- The README describes the requirements, the setup and what the script does on each run.

### Security

- The WAN IP from the DNS answer has to be a single IPv4 address now. Before, the script put whatever the answer held into the SQL statement and into the command line it runs on the Plesk server over SSH, so a forged DNS answer could have changed other records or run commands there. Anything else is logged and mailed as an error, and nothing is sent to the server.

### Fixed

- Every run started an `ssh-agent` and left it running, one more process every five minutes from cron. The script now stops its agent however the run ends.
- `config.example` had wrong values for two settings: `DNS_RESOLVER` has to be a query that returns your WAN IP (`myip.opendns.com @resolver1.opendns.com`), not a name server, and `DNS_TABLE` is `psa.dns_recs` in Plesk. A configuration copied from it would have written the address of the name server into your record. (Wrong since 2026-09-11.)

## [0.2] - 2015-12-10

### Changed

- `mysql` runs with `--batch` and `--skip-column-names` for the `SELECT`.

### Fixed

- The script stops when it gets no WAN IP, after one more try, instead of writing an empty address.

## [0.1] - 2015-12-08

- First release.

[Unreleased]: https://github.com/derblub/dyndns/compare/5e08742...HEAD
[0.2]: https://github.com/derblub/dyndns/commit/5e08742
[0.1]: https://github.com/derblub/dyndns/commit/a4d3f76
