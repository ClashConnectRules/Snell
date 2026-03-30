# Snell 一键安装/更新脚本

[![Platform](https://img.shields.io/badge/Platform-Linux-2ea44f?style=for-the-badge)](https://www.kernel.org/)
[![Shell](https://img.shields.io/badge/Shell-Bash-121011?logo=gnu-bash&logoColor=white&style=for-the-badge)](https://www.gnu.org/software/bash/)
[![systemd](https://img.shields.io/badge/Init-systemd-003b57?logo=systemd&logoColor=white&style=for-the-badge)](https://systemd.io/)
[![Stars](https://img.shields.io/github/stars/ClashConnectRules/Snell?style=for-the-badge)](https://github.com/ClashConnectRules/Snell/stargazers)
[![Last Commit](https://img.shields.io/github/last-commit/ClashConnectRules/Snell?style=for-the-badge)](https://github.com/ClashConnectRules/Snell/commits/main)

用于 Linux + systemd 环境的 Snell 服务端部署脚本，支持安装/更新/卸载、多用户管理、ShadowTLS、Docker、BBR 以及客户端节点一键输出。

- English: [README.md](./README.md)
- 仓库地址: `https://github.com/ClashConnectRules/Snell.git`

## 目录

- [功能特性](#功能特性)
- [快速开始](#快速开始)
- [交互菜单](#交互菜单)
- [常用命令速查](#常用命令速查)
- [参数说明](#参数说明)
- [安装后文件位置](#安装后文件位置)
- [Surge 示例](#surge-示例)
- [FAQ](#faq)
- [贡献指南](#贡献指南)
- [参考](#参考)
- [免责声明](#免责声明)

## 功能特性

- 支持 Snell `v4` / `v5` 安装与更新
- 分层 2 级交互菜单（按类目管理）
- 菜单头部展示资源占用：`CPU / MEM / DISK`
- 主服务管理：安装/更新/卸载/配置/重启/状态
- Profile 多用户端口：新增/列表/删除
- BBR：启用/关闭/状态
- Docker 模式：部署/移除/状态
- ShadowTLS：部署/移除/状态（支持交互选择上游）
- 支持随时重打客户端节点：`--print-client`
- 自动尝试放行防火墙（`ufw` / `firewalld`）

## 快速开始

### 方式 1：直链执行（推荐）

```bash
curl -fsSL https://cdn.jsdelivr.net/gh/ClashConnectRules/Snell@main/install_snell.sh -o install_snell.sh \
  || curl -fsSL https://fastly.jsdelivr.net/gh/ClashConnectRules/Snell@main/install_snell.sh -o install_snell.sh
grep -q '^#!/usr/bin/env bash' install_snell.sh && chmod +x install_snell.sh && bash install_snell.sh
```

如果当前用户不是 root，请把 `bash install_snell.sh` 改成 `sudo bash install_snell.sh`。

### 方式 2：克隆仓库执行

```bash
git clone https://github.com/ClashConnectRules/Snell.git
cd Snell
chmod +x install_snell.sh
bash install_snell.sh
```

## 交互菜单

脚本已从“平铺长菜单”升级为“类目菜单”：

- `Snell 主服务`
- `Profile`
- `BBR`
- `Docker`
- `ShadowTLS`
- `客户端配置`
- `脚本管理`

说明：

- 交互模式下，操作成功/失败后都会返回菜单，不会强制退出。
- 在已安装机器上，Snell 子菜单会提示“推荐更新”，默认回车为返回，避免误操作。

## 常用命令速查

### 主服务

```bash
sudo bash install_snell.sh --action install --major 4
sudo bash install_snell.sh --action install --major 5 --port 22333
sudo bash install_snell.sh --action update --major 5
sudo bash install_snell.sh --action uninstall
sudo bash install_snell.sh --action config
sudo bash install_snell.sh --action restart
sudo bash install_snell.sh --action status
```

### Profile 多用户

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

### Docker 模式

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

### 客户端配置输出

```bash
sudo bash install_snell.sh --print-client
sudo bash install_snell.sh --print-client --name main
sudo bash install_snell.sh --print-client --name hk-a
```

### 脚本管理

```bash
sudo bash install_snell.sh --action script-update
sudo bash install_snell.sh --action purge-all
```

### 指定精确版本

```bash
sudo bash install_snell.sh --action install --version 4.1.1
sudo bash install_snell.sh --action update --version 5.0.1
```

## 参数说明

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

## 安装后文件位置

- Snell 二进制: `/usr/local/bin/snell-server`
- Snell 配置文件: `/etc/snell/snell-server.conf`
- Snell 服务文件: `/etc/systemd/system/snell.service`
- ShadowTLS 二进制: `/usr/local/bin/shadow-tls`
- ShadowTLS 环境文件: `/etc/snell/shadowtls.env`
- ShadowTLS 服务文件: `/etc/systemd/system/shadowtls.service`

## Surge 示例

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

Q: `update` 会覆盖端口和 PSK 吗？  
A: 不会。`update` 只替换二进制并重启服务，保留现有配置。

Q: 不重装怎么重新输出节点？  
A: 使用 `sudo bash install_snell.sh --print-client`。

Q: 端口已放行但还是连不上？  
A: 请同时检查云厂商安全组和系统防火墙，并确认同端口 TCP/UDP 都放行。

Q: 非交互环境怎么运行？  
A: 显式传入 `--action` 和 `--major`（或 `--version`）。

## 贡献指南

欢迎提交 Issue / PR。

1. Fork 仓库并创建分支（`feat/xxx` 或 `fix/xxx`）
2. 本地先跑语法检查：`bash -n install_snell.sh`
3. 提交 PR，说明动机、影响和验证步骤

## 参考

- Snell Release Notes: https://kb.nssurge.com/surge-knowledge-base/zh/release-notes/snell
- 官方下载源: https://dl.nssurge.com/snell/

## 免责声明

本项目仅用于合法合规用途，请遵守当地法律法规与服务商条款。
