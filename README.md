# Snell One-Click Install/Update Script

[![Platform](https://img.shields.io/badge/Platform-Linux-2ea44f?style=for-the-badge)](https://www.kernel.org/)
[![Shell](https://img.shields.io/badge/Shell-Bash-121011?logo=gnu-bash&logoColor=white&style=for-the-badge)](https://www.gnu.org/software/bash/)
[![systemd](https://img.shields.io/badge/Init-systemd-003b57?logo=systemd&logoColor=white&style=for-the-badge)](https://systemd.io/)
[![Stars](https://img.shields.io/github/stars/ClashConnectRules/Snell?style=for-the-badge)](https://github.com/ClashConnectRules/Snell/stargazers)
[![Last Commit](https://img.shields.io/github/last-commit/ClashConnectRules/Snell?style=for-the-badge)](https://github.com/ClashConnectRules/Snell/commits/main)

A Linux + systemd oriented Snell server deployment script with interactive install/update/uninstall flow, v4/v5 selection, auto config generation, and systemd service setup.

- 中文文档: [README_ZH.md](./README_ZH.md)
- Repository: `https://github.com/ClashConnectRules/Snell.git`
- Script URL: `https://raw.githubusercontent.com/ClashConnectRules/Snell/main/install_snell.sh`

## Table of Contents

- [Features](#features)
- [Supported Versions and Architectures](#supported-versions-and-architectures)
- [How to Use](#how-to-use)
- [Arguments](#arguments)
- [Installed File Paths](#installed-file-paths)
- [Operations](#operations)
- [Surge Example Config](#surge-example-config)
- [FAQ](#faq)
- [Contributing](#contributing)
- [References](#references)
- [Disclaimer](#disclaimer)

## Features

- Interactive action menu: `install`, `update`, or `uninstall`
- Grouped 2-level interactive menu (by category) for easier management
- Auto-default to `update` when an existing installation is detected
- Interactive version selection: Snell `v4` or `v5`
- Auto-detect architecture and download official binary
- Auto-generate `/etc/snell/snell-server.conf`
- Auto-create/start `systemd` service `snell.service`
- Auto-allow firewall rules (`ufw` / `firewalld`) when available
- Update mode keeps existing config and backs up previous binary
- Node name format uses IP region prefix: `<region>-snellv4` / `<region>-snellv5`
- Built-in management actions: `config`, `restart`, `status`, `script-update`
- Profile-based multi-user port management: `profile-add`, `profile-list`, `profile-remove`
- BBR switches: `bbr-enable`, `bbr-disable`, `bbr-status`
- Docker deployment mode: `docker-deploy`, `docker-remove`, `docker-status`
- ShadowTLS deployment: `stls-deploy`, `stls-status`, `stls-remove` (with interactive upstream selection)
- Reprint client nodes at any time: `--print-client` (no reinstall needed)
- Menu header shows runtime status and system usage (`CPU / MEM / DISK`)

## Supported Versions and Architectures

Supported versions:

- Snell v4: `4.1.1`
- Snell v5: `5.0.1`

Supported architectures:

- `amd64`
- `i386`
- `aarch64`
- `armv7l`

## How to Use

### Option 1: Clone the repository (recommended)

```bash
git clone https://github.com/ClashConnectRules/Snell.git
cd Snell
chmod +x install_snell.sh
bash install_snell.sh
```

If your current user is not root, run `sudo bash install_snell.sh`.

### Option 2: Run via direct script URL

```bash
for u in \
"https://raw.githubusercontent.com/ClashConnectRules/Snell/main/install_snell.sh" \
"https://cdn.jsdelivr.net/gh/ClashConnectRules/Snell@main/install_snell.sh" \
"https://fastly.jsdelivr.net/gh/ClashConnectRules/Snell@main/install_snell.sh"
do
  if curl -fsSL "$u" -o install_snell.sh && grep -q '^#!/usr/bin/env bash' install_snell.sh; then
    chmod +x install_snell.sh && bash install_snell.sh
    break
  fi
done
```

If your current user is not root, replace `bash install_snell.sh` with `sudo bash install_snell.sh`.

### Non-interactive examples

If Snell is already installed and `--action` is omitted, the script defaults to `update`.

Install v4:

```bash
sudo bash install_snell.sh --action install --major 4
```

Install v5 with custom port:

```bash
sudo bash install_snell.sh --action install --major 5 --port 22333
```

Update to v4:

```bash
sudo bash install_snell.sh --action update --major 4
```

Update to v5:

```bash
sudo bash install_snell.sh --action update --major 5
```

Uninstall Snell service and files:

```bash
sudo bash install_snell.sh --action uninstall
```

Uninstall and delete the script itself:

```bash
sudo bash install_snell.sh --action uninstall --remove-script
```

Show current configuration:

```bash
sudo bash install_snell.sh --action config
```

Restart Snell service:

```bash
sudo bash install_snell.sh --action restart
```

Show Snell status:

```bash
sudo bash install_snell.sh --action status
```

Update this script itself:

```bash
sudo bash install_snell.sh --action script-update
```

Add a profile user/port:

```bash
sudo bash install_snell.sh --action profile-add --name hk-a --major 5 --port 31001
```

List all profile users:

```bash
sudo bash install_snell.sh --action profile-list
```

Remove a profile user:

```bash
sudo bash install_snell.sh --action profile-remove --name hk-a
```

Enable BBR:

```bash
sudo bash install_snell.sh --action bbr-enable
```

Check BBR status:

```bash
sudo bash install_snell.sh --action bbr-status
```

Deploy in Docker mode:

```bash
sudo bash install_snell.sh --action docker-deploy --major 5 --port 31001
```

Show Docker mode status:

```bash
sudo bash install_snell.sh --action docker-status
```

Remove Docker mode:

```bash
sudo bash install_snell.sh --action docker-remove
```

Deploy ShadowTLS in front of Snell:

```bash
sudo bash install_snell.sh --action stls-deploy
```

Show ShadowTLS status:

```bash
sudo bash install_snell.sh --action stls-status
```

Remove ShadowTLS:

```bash
sudo bash install_snell.sh --action stls-remove
```

Reprint all current client nodes:

```bash
sudo bash install_snell.sh --print-client
```

Reprint one specific profile:

```bash
sudo bash install_snell.sh --print-client --name hk-a
```

Pin exact version:

```bash
sudo bash install_snell.sh --action install --version 4.1.1
sudo bash install_snell.sh --action update --version 5.0.1
```

## Arguments

```text
--action <install|update|uninstall|config|restart|status|script-update|profile-add|profile-list|profile-remove|bbr-enable|bbr-disable|bbr-status|docker-deploy|docker-remove|docker-status|stls-deploy|stls-remove|stls-status|print-client>
                          Select operation
--name <profile_name>       Profile name for profile actions
--print-client              Print current client nodes only
--remove-script             Delete current script after uninstall
--major <4|5>               Select major version
--version <ver>             Exact version (e.g. 4.1.1 / 5.0.1)
--port <port>               Listen port (random by default on install)
--psk <psk>                 Pre-shared key (auto-generated if omitted)
--ipv6 <true|false>         Enable IPv6, default false
--dns "<dns1,dns2>"         Optional DNS parameter
--egress-interface <iface>  Optional egress interface (v5 only)
--stls-version <2|3>        ShadowTLS version (default 3)
--stls-port <port>          ShadowTLS listen port (default 443)
--stls-password <password>  ShadowTLS password (auto if omitted)
--stls-sni <sni>            ShadowTLS SNI (default gateway.icloud.com)
--stls-upstream <ip:port>   ShadowTLS upstream Snell address (auto-select if omitted)
--skip-firewall             Skip firewall setup
-h, --help                  Show help
```

## Installed File Paths

- Binary: `/usr/local/bin/snell-server`
- Config: `/etc/snell/snell-server.conf`
- Service: `/etc/systemd/system/snell.service`
- ShadowTLS binary: `/usr/local/bin/shadow-tls`
- ShadowTLS env: `/etc/snell/shadowtls.env`
- ShadowTLS service: `/etc/systemd/system/shadowtls.service`

## Operations

```bash
systemctl status snell.service --no-pager
systemctl restart snell.service
journalctl -u snell.service -f
```

## Surge Example Config

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

Q: Does update overwrite my port/PSK?  
A: No. `update` only replaces the binary and restarts the service. Existing config is preserved.

Q: How can I roll back after a failed update?  
A: The previous binary is backed up as `/usr/local/bin/snell-server.bak.YYYYmmddHHMMSS`.

Q: Port is open but still cannot connect, why?  
A: Check both cloud security groups and local firewall. Make sure TCP/UDP for the same port are both allowed.

Q: How to run in CI/non-interactive shell?  
A: Pass `--action` and `--major` (or `--version`) explicitly.

Q: How do I reprint nodes without reinstalling?  
A: Run `sudo bash install_snell.sh --print-client` (or add `--name <profile_name>`).

## Contributing

Issues and PRs are welcome.

1. Fork this repo and create your branch (`feat/xxx` or `fix/xxx`)
2. Validate script syntax: `bash -n install_snell.sh`
3. Open a PR with context, impact, and verification steps

Recommended PR focus:

- Backward compatibility
- Clear logging/observability
- Security and safe defaults

## References

- Snell Release Notes: https://kb.nssurge.com/surge-knowledge-base/zh/release-notes/snell
- Official downloads: https://dl.nssurge.com/snell/

## Disclaimer

This project is for legal and compliant use only. Please follow local laws and provider policies.
