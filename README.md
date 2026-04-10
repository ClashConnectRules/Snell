# Snell One-Click Script

## Recommended Provider

[![Provider](https://img.shields.io/badge/Provider-ZRJ-f97316?style=for-the-badge)](https://hizrj.xyz/#/register?code=BwiZnFLE)
[![Register](https://img.shields.io/badge/Register-Open_Link-0f766e?style=for-the-badge)](https://hizrj.xyz/#/register?code=BwiZnFLE)

> 优质机场推荐: **[ZRJ](https://hizrj.xyz/#/register?code=BwiZnFLE)**
>
> 注册地址: <https://hizrj.xyz/#/register?code=BwiZnFLE>

[![Platform](https://img.shields.io/badge/Platform-Linux-2ea44f?style=for-the-badge)](https://www.kernel.org/)
[![Shell](https://img.shields.io/badge/Shell-Bash-121011?logo=gnu-bash&logoColor=white&style=for-the-badge)](https://www.gnu.org/software/bash/)
[![systemd](https://img.shields.io/badge/Init-systemd-003b57?logo=systemd&logoColor=white&style=for-the-badge)](https://systemd.io/)
[![Stars](https://img.shields.io/github/stars/ClashConnectRules/Snell?style=for-the-badge)](https://github.com/ClashConnectRules/Snell/stargazers)
[![Last Commit](https://img.shields.io/github/last-commit/ClashConnectRules/Snell?style=for-the-badge)](https://github.com/ClashConnectRules/Snell/commits/main)

Linux + systemd Snell deployment script with built-in menu management.

- 中文入口: [README_ZH.md](./README_ZH.md)
- Docs Index: [docs/INDEX.md](./docs/INDEX.md)
- Full docs (EN): [docs/README_FULL.md](./docs/README_FULL.md)
- Full docs (ZH): [docs/README_FULL_ZH.md](./docs/README_FULL_ZH.md)
- Repo: `https://github.com/ClashConnectRules/Snell.git`

## Quick Start

Run directly (recommended):

```bash
curl -fsSL https://cdn.jsdelivr.net/gh/ClashConnectRules/Snell@main/install_snell.sh -o install_snell.sh \
  || curl -fsSL https://fastly.jsdelivr.net/gh/ClashConnectRules/Snell@main/install_snell.sh -o install_snell.sh
grep -q '^#!/usr/bin/env bash' install_snell.sh && chmod +x install_snell.sh && bash install_snell.sh
```

If you are not root, replace `bash install_snell.sh` with `sudo bash install_snell.sh`.

Clone mode:

```bash
git clone https://github.com/ClashConnectRules/Snell.git
cd Snell
chmod +x install_snell.sh
bash install_snell.sh
```

## Feature Snapshot

- Snell `v4/v5` install/update/uninstall
- 2-level interactive menu by category
- Runtime header in menu: `CPU / MEM / DISK`
- Main service operations: config/restart/status
- Profile multi-user ports: add/list/remove
- BBR toggle: enable/disable/status
- Docker mode: deploy/remove/status
- ShadowTLS: deploy/remove/status
- Client output anytime: `--print-client`

## Common Commands

Main service:

```bash
sudo bash install_snell.sh --action install --major 5 --port 22333
sudo bash install_snell.sh --action update --major 5
sudo bash install_snell.sh --action status
sudo bash install_snell.sh --action restart
sudo bash install_snell.sh --action uninstall
```

Profiles:

```bash
sudo bash install_snell.sh --action profile-add --name hk-a --major 5 --port 31001
sudo bash install_snell.sh --action profile-list
sudo bash install_snell.sh --action profile-remove --name hk-a
```

ShadowTLS:

```bash
sudo bash install_snell.sh --action stls-deploy
sudo bash install_snell.sh --action stls-status
sudo bash install_snell.sh --action stls-remove
```

Script management:

```bash
sudo bash install_snell.sh --action script-update
sudo bash install_snell.sh --action purge-all
```

Client output:

```bash
sudo bash install_snell.sh --print-client
sudo bash install_snell.sh --print-client --name main
sudo bash install_snell.sh --print-client --name hk-a
```

## Key Arguments

```text
--action <install|update|uninstall|config|restart|status|script-update|purge-all|profile-add|profile-list|profile-remove|bbr-enable|bbr-disable|bbr-status|docker-deploy|docker-remove|docker-status|stls-deploy|stls-remove|stls-status|print-client>
--major <4|5>
--version <x.y.z>
--port <port>
--psk <psk>
--name <profile_name>
--print-client
--stls-version <2|3>
--stls-port <port>
--stls-password <password>
--stls-sni <sni>
--stls-upstream <ip:port>
--skip-firewall
-h, --help
```

For full parameter descriptions, examples, file paths, and FAQ, see:
- [docs/INDEX.md](./docs/INDEX.md)
- [docs/README_FULL.md](./docs/README_FULL.md)

## License & Disclaimer

Use this project only in legal and compliant scenarios.
