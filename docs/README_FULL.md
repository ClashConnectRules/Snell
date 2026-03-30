# Snell One-Click Install/Update Script

[![Platform](https://img.shields.io/badge/Platform-Linux-2ea44f?style=for-the-badge)](https://www.kernel.org/)
[![Shell](https://img.shields.io/badge/Shell-Bash-121011?logo=gnu-bash&logoColor=white&style=for-the-badge)](https://www.gnu.org/software/bash/)
[![systemd](https://img.shields.io/badge/Init-systemd-003b57?logo=systemd&logoColor=white&style=for-the-badge)](https://systemd.io/)
[![Stars](https://img.shields.io/github/stars/ClashConnectRules/Snell?style=for-the-badge)](https://github.com/ClashConnectRules/Snell/stargazers)
[![Last Commit](https://img.shields.io/github/last-commit/ClashConnectRules/Snell?style=for-the-badge)](https://github.com/ClashConnectRules/Snell/commits/main)

A Linux + systemd oriented Snell deployment script with install/update/uninstall, profile-based multi-user management, ShadowTLS integration, Docker mode, BBR toggle, and client config output.

- 中文文档: [README_ZH.md](./README_ZH.md)
- Repository: `https://github.com/ClashConnectRules/Snell.git`

## Table of Contents

- [Features](#features)
- [Quick Start](#quick-start)
- [Interactive Menu](#interactive-menu)
- [Command Cheatsheet](#command-cheatsheet)
- [Arguments](#arguments)
- [Installed Paths](#installed-paths)
- [Surge Examples](#surge-examples)
- [FAQ](#faq)
- [Contributing](#contributing)
- [References](#references)
- [Disclaimer](#disclaimer)

## Features

- Snell `v4` / `v5` install and update
- Grouped 2-level interactive menu
- Runtime header in menu: `CPU / MEM / DISK`
- Main service management: install/update/uninstall/config/restart/status
- Profile-based multi-user ports: add/list/remove
- BBR toggle: enable/disable/status
- Docker mode: deploy/remove/status
- ShadowTLS: deploy/remove/status (interactive upstream selection)
- Client node reprint anytime: `--print-client`
- Auto firewall opening for `ufw` / `firewalld` (when available)

## Quick Start

### Option 1: Direct run (recommended)

```bash
curl -fsSL https://cdn.jsdelivr.net/gh/ClashConnectRules/Snell@main/install_snell.sh -o install_snell.sh \
  || curl -fsSL https://fastly.jsdelivr.net/gh/ClashConnectRules/Snell@main/install_snell.sh -o install_snell.sh
grep -q '^#!/usr/bin/env bash' install_snell.sh && chmod +x install_snell.sh && bash install_snell.sh
```

If your current user is not root, replace `bash install_snell.sh` with `sudo bash install_snell.sh`.

### Option 2: Clone repository

```bash
git clone https://github.com/ClashConnectRules/Snell.git
cd Snell
chmod +x install_snell.sh
bash install_snell.sh
```

## Interactive Menu

The script now uses category menus instead of a long flat list:

- `Snell Main Service`
- `Profile`
- `BBR`
- `Docker`
- `ShadowTLS`
- `Client Config`
- `Script`

Notes:

- In interactive mode, action success/failure returns to menu (does not force exit).
- In Snell submenu, installed machines show `recommend update` and default to `back` to avoid accidental updates.

## Command Cheatsheet

### Main Service

```bash
sudo bash install_snell.sh --action install --major 4
sudo bash install_snell.sh --action install --major 5 --port 22333
sudo bash install_snell.sh --action update --major 5
sudo bash install_snell.sh --action uninstall
sudo bash install_snell.sh --action config
sudo bash install_snell.sh --action restart
sudo bash install_snell.sh --action status
```

### Profiles

```bash
sudo bash install_snell.sh --action profile-add --name hk-a --major 5 --port 31001
sudo bash install_snell.sh --action profile-list
sudo bash install_snell.sh --action profile-remove --name hk-a
```

### BBR

```bash
sudo bash install_snell.sh --action bbr-enable
sudo bash install_snell.sh --action bbr-disable
sudo bash install_snell.sh --action bbr-status
```

### Docker Mode

```bash
sudo bash install_snell.sh --action docker-deploy --major 5 --port 31001
sudo bash install_snell.sh --action docker-status
sudo bash install_snell.sh --action docker-remove
```

### ShadowTLS

```bash
sudo bash install_snell.sh --action stls-deploy
sudo bash install_snell.sh --action stls-status
sudo bash install_snell.sh --action stls-remove
```

### Client Config Output

```bash
sudo bash install_snell.sh --print-client
sudo bash install_snell.sh --print-client --name main
sudo bash install_snell.sh --print-client --name hk-a
```

### Script Management

```bash
sudo bash install_snell.sh --action script-update
sudo bash install_snell.sh --action purge-all
```

### Pin Exact Version

```bash
sudo bash install_snell.sh --action install --version 4.1.1
sudo bash install_snell.sh --action update --version 5.0.1
```

## Arguments

```text
--action <install|update|uninstall|config|restart|status|script-update|purge-all|profile-add|profile-list|profile-remove|bbr-enable|bbr-disable|bbr-status|docker-deploy|docker-remove|docker-status|stls-deploy|stls-remove|stls-status|print-client>
--name <profile_name>
--print-client
--remove-script
--major <4|5>
--version <ver>
--port <port>
--psk <psk>
--ipv6 <true|false>
--dns "<dns1,dns2>"
--egress-interface <iface>
--stls-version <2|3>
--stls-port <port>
--stls-password <password>
--stls-sni <sni>
--stls-upstream <ip:port>
--skip-firewall
-h, --help
```

## Installed Paths

- Snell binary: `/usr/local/bin/snell-server`
- Snell config: `/etc/snell/snell-server.conf`
- Snell service: `/etc/systemd/system/snell.service`
- ShadowTLS binary: `/usr/local/bin/shadow-tls`
- ShadowTLS env: `/etc/snell/shadowtls.env`
- ShadowTLS service: `/etc/systemd/system/shadowtls.service`

## Surge Examples

Snell v4:

```ini
<region>-snellv4 = snell, <server_ip>, <port>, psk=<psk>, version=4, reuse=true, tfo=true
```

Snell v5:

```ini
<region>-snellv5 = snell, <server_ip>, <port>, psk=<psk>, version=5, reuse=true, tfo=true
```

Snell + ShadowTLS (v3):

```ini
<region>-snellv5 = snell, <server_ip>, <stls_port>, psk=<psk>, version=5, reuse=true, tfo=true, shadow-tls-password=<stls_password>, shadow-tls-sni=<stls_sni>, shadow-tls-version=3
```

## FAQ

Q: Does `update` overwrite port/PSK?  
A: No. `update` only replaces binary and restarts service. Existing config is preserved.

Q: How to reprint client config without reinstall?  
A: Use `sudo bash install_snell.sh --print-client`.

Q: Port is open but still cannot connect?  
A: Check both cloud security groups and local firewall, and allow both TCP/UDP for the same port.

Q: How to run in CI/non-interactive shell?  
A: Pass `--action` and `--major` (or `--version`) explicitly.

## Contributing

Issues and PRs are welcome.

1. Fork this repo and create your branch (`feat/xxx` or `fix/xxx`)
2. Validate syntax: `bash -n install_snell.sh`
3. Open a PR with context, impact, and verification

## References

- Snell Release Notes: https://kb.nssurge.com/surge-knowledge-base/zh/release-notes/snell
- Official Snell download: https://dl.nssurge.com/snell/

## Disclaimer

This project is for legal and compliant use only. Please follow local laws and provider policies.
