# Snell One-Click Install/Update Script

[![Platform](https://img.shields.io/badge/Platform-Linux-2ea44f?style=for-the-badge)](https://www.kernel.org/)
[![Shell](https://img.shields.io/badge/Shell-Bash-121011?logo=gnu-bash&logoColor=white&style=for-the-badge)](https://www.gnu.org/software/bash/)
[![systemd](https://img.shields.io/badge/Init-systemd-003b57?logo=systemd&logoColor=white&style=for-the-badge)](https://systemd.io/)
[![Stars](https://img.shields.io/github/stars/ClashConnectRules/Snell?style=for-the-badge)](https://github.com/ClashConnectRules/Snell/stargazers)
[![Last Commit](https://img.shields.io/github/last-commit/ClashConnectRules/Snell?style=for-the-badge)](https://github.com/ClashConnectRules/Snell/commits/main)

A Linux + systemd oriented Snell server deployment script with interactive install/update flow, v4/v5 selection, auto config generation, and systemd service setup.

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

- Interactive action menu: `install` or `update`
- Interactive version selection: Snell `v4` or `v5`
- Auto-detect architecture and download official binary
- Auto-generate `/etc/snell/snell-server.conf`
- Auto-create/start `systemd` service `snell.service`
- Auto-allow firewall rules (`ufw` / `firewalld`) when available
- Update mode keeps existing config and backs up previous binary

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
sudo bash install_snell.sh
```

### Option 2: Run via direct script URL

```bash
curl -L https://raw.githubusercontent.com/ClashConnectRules/Snell/main/install_snell.sh -o install_snell.sh && chmod +x install_snell.sh && sudo bash install_snell.sh
```

### Non-interactive examples

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

Pin exact version:

```bash
sudo bash install_snell.sh --action install --version 4.1.1
sudo bash install_snell.sh --action update --version 5.0.1
```

## Arguments

```text
--action <install|update>   Select operation
--major <4|5>               Select major version
--version <ver>             Exact version (e.g. 4.1.1 / 5.0.1)
--port <port>               Listen port, default 6160
--psk <psk>                 Pre-shared key (auto-generated if omitted)
--ipv6 <true|false>         Enable IPv6, default false
--dns "<dns1,dns2>"         Optional DNS parameter
--egress-interface <iface>  Optional egress interface (v5 only)
--skip-firewall             Skip firewall setup
-h, --help                  Show help
```

## Installed File Paths

- Binary: `/usr/local/bin/snell-server`
- Config: `/etc/snell/snell-server.conf`
- Service: `/etc/systemd/system/snell.service`

## Operations

```bash
systemctl status snell.service --no-pager
systemctl restart snell.service
journalctl -u snell.service -f
```

## Surge Example Config

Snell v4:

```ini
SnellV4 = snell, <server_ip>, <port>, psk=<psk>, version=4, reuse=true, tfo=true
```

Snell v5:

```ini
SnellV5 = snell, <server_ip>, <port>, psk=<psk>, version=5, reuse=true, tfo=true
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
