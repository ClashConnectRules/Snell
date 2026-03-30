# Snell 一键安装/更新脚本

[![Platform](https://img.shields.io/badge/Platform-Linux-2ea44f?style=for-the-badge)](https://www.kernel.org/)
[![Shell](https://img.shields.io/badge/Shell-Bash-121011?logo=gnu-bash&logoColor=white&style=for-the-badge)](https://www.gnu.org/software/bash/)
[![systemd](https://img.shields.io/badge/Init-systemd-003b57?logo=systemd&logoColor=white&style=for-the-badge)](https://systemd.io/)
[![Stars](https://img.shields.io/github/stars/ClashConnectRules/Snell?style=for-the-badge)](https://github.com/ClashConnectRules/Snell/stargazers)
[![Last Commit](https://img.shields.io/github/last-commit/ClashConnectRules/Snell?style=for-the-badge)](https://github.com/ClashConnectRules/Snell/commits/main)

用于 Linux + systemd 环境的 Snell 服务端部署脚本，支持交互式安装/更新/卸载、v4/v5 版本选择、自动生成配置、自动创建服务。

- English: [README.md](./README.md)
- 仓库地址: `https://github.com/ClashConnectRules/Snell.git`
- 脚本地址: `https://raw.githubusercontent.com/ClashConnectRules/Snell/main/install_snell.sh`

## 目录

- [功能特性](#功能特性)
- [支持版本与架构](#支持版本与架构)
- [如何使用](#如何使用)
- [参数说明](#参数说明)
- [安装后文件位置](#安装后文件位置)
- [运维命令](#运维命令)
- [Surge 配置示例](#surge-配置示例)
- [FAQ](#faq)
- [贡献指南](#贡献指南)
- [参考](#参考)
- [免责声明](#免责声明)

## 功能特性

- 交互式菜单：先选 `安装`、`更新` 或 `卸载`
- 检测到已安装时，默认操作自动切到 `更新`
- 交互式版本：再选 Snell `v4` 或 `v5`
- 自动识别架构并下载官方二进制
- 自动生成 `/etc/snell/snell-server.conf`
- 自动生成并启动 `systemd` 服务 `snell.service`
- 自动尝试放行防火墙（`ufw` / `firewalld`）
- 更新模式保留原配置，并备份旧二进制
- 节点名统一为 IP 地区前缀：`<region>-snellv4` / `<region>-snellv5`
- 内置管理动作：`config`、`restart`、`status`、`script-update`
- Profile 化多用户端口管理：`profile-add`、`profile-list`、`profile-remove`
- BBR 开关：`bbr-enable`、`bbr-disable`、`bbr-status`
- Docker 部署模式：`docker-deploy`、`docker-remove`、`docker-status`
- ShadowTLS 部署：`stls-deploy`、`stls-status`、`stls-remove`（支持交互选择上游）
- 支持随时重打节点：`--print-client`（无需重装）

## 支持版本与架构

支持版本:

- Snell v4: `4.1.1`
- Snell v5: `5.0.1`

支持架构:

- `amd64`
- `i386`
- `aarch64`
- `armv7l`

## 如何使用

### 方式 1：克隆仓库后执行（推荐）

```bash
git clone https://github.com/ClashConnectRules/Snell.git
cd Snell
chmod +x install_snell.sh
bash install_snell.sh
```

如果当前用户不是 root，请使用 `sudo bash install_snell.sh`。

### 方式 2：脚本直链一键执行

```bash
curl -L https://raw.githubusercontent.com/ClashConnectRules/Snell/main/install_snell.sh -o install_snell.sh && chmod +x install_snell.sh && bash install_snell.sh
```

如果当前用户不是 root，请把最后一段改为 `sudo bash install_snell.sh`。

### 非交互执行示例

若系统已安装 Snell 且未传 `--action`，脚本会默认执行 `update`。

安装 v4:

```bash
sudo bash install_snell.sh --action install --major 4
```

安装 v5 并指定端口:

```bash
sudo bash install_snell.sh --action install --major 5 --port 22333
```

更新到 v4:

```bash
sudo bash install_snell.sh --action update --major 4
```

更新到 v5:

```bash
sudo bash install_snell.sh --action update --major 5
```

卸载 Snell 服务与文件:

```bash
sudo bash install_snell.sh --action uninstall
```

卸载并删除当前脚本:

```bash
sudo bash install_snell.sh --action uninstall --remove-script
```

查看当前配置:

```bash
sudo bash install_snell.sh --action config
```

重启 Snell 服务:

```bash
sudo bash install_snell.sh --action restart
```

查看 Snell 状态:

```bash
sudo bash install_snell.sh --action status
```

更新本脚本:

```bash
sudo bash install_snell.sh --action script-update
```

新增 Profile 用户端口:

```bash
sudo bash install_snell.sh --action profile-add --name hk-a --major 5 --port 31001
```

查看 Profile 列表:

```bash
sudo bash install_snell.sh --action profile-list
```

删除 Profile:

```bash
sudo bash install_snell.sh --action profile-remove --name hk-a
```

启用 BBR:

```bash
sudo bash install_snell.sh --action bbr-enable
```

查看 BBR 状态:

```bash
sudo bash install_snell.sh --action bbr-status
```

Docker 模式部署:

```bash
sudo bash install_snell.sh --action docker-deploy --major 5 --port 31001
```

查看 Docker 状态:

```bash
sudo bash install_snell.sh --action docker-status
```

移除 Docker 模式:

```bash
sudo bash install_snell.sh --action docker-remove
```

给 Snell 前置部署 ShadowTLS:

```bash
sudo bash install_snell.sh --action stls-deploy
```

查看 ShadowTLS 状态:

```bash
sudo bash install_snell.sh --action stls-status
```

移除 ShadowTLS:

```bash
sudo bash install_snell.sh --action stls-remove
```

重打当前所有客户端节点:

```bash
sudo bash install_snell.sh --print-client
```

仅重打指定 Profile 节点:

```bash
sudo bash install_snell.sh --print-client --name hk-a
```

指定精确版本:

```bash
sudo bash install_snell.sh --action install --version 4.1.1
sudo bash install_snell.sh --action update --version 5.0.1
```

## 参数说明

```text
--action <install|update|uninstall|config|restart|status|script-update|profile-add|profile-list|profile-remove|bbr-enable|bbr-disable|bbr-status|docker-deploy|docker-remove|docker-status|stls-deploy|stls-remove|stls-status|print-client>
                          选择操作（安装/更新/卸载/查看配置/重启/状态/更新脚本/多用户/BBR/Docker/ShadowTLS）
--name <profile_name>       Profile 名称（多用户动作时使用）
--print-client              仅输出当前客户端节点
--remove-script             卸载后删除当前脚本文件
--major <4|5>               选择主版本
--version <ver>             指定精确版本（如 4.1.1 / 5.0.1）
--port <port>               监听端口（安装时默认随机）
--psk <psk>                 指定 PSK（不传则自动生成）
--ipv6 <true|false>         是否启用 IPv6，默认 false
--dns "<dns1,dns2>"         可选 DNS 参数
--egress-interface <iface>  可选出口网卡（仅 v5）
--stls-version <2|3>        ShadowTLS 版本（默认 3）
--stls-port <port>          ShadowTLS 监听端口（默认 443）
--stls-password <password>  ShadowTLS 密码（不传自动生成）
--stls-sni <sni>            ShadowTLS SNI（默认 gateway.icloud.com）
--stls-upstream <ip:port>   ShadowTLS 上游 Snell 地址（不传自动选择）
--skip-firewall             跳过防火墙放行
-h, --help                  显示帮助
```

## 安装后文件位置

- 二进制: `/usr/local/bin/snell-server`
- 配置文件: `/etc/snell/snell-server.conf`
- 服务文件: `/etc/systemd/system/snell.service`
- ShadowTLS 二进制: `/usr/local/bin/shadow-tls`
- ShadowTLS 环境文件: `/etc/snell/shadowtls.env`
- ShadowTLS 服务文件: `/etc/systemd/system/shadowtls.service`

## 运维命令

```bash
systemctl status snell.service --no-pager
systemctl restart snell.service
journalctl -u snell.service -f
```

## Surge 配置示例

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

Q: 更新会覆盖我的端口和 PSK 吗？  
A: 不会。`update` 仅替换二进制并重启服务，保留现有配置文件。

Q: 更新失败了怎么回滚？  
A: 脚本会自动备份旧二进制到 `/usr/local/bin/snell-server.bak.YYYYmmddHHMMSS`，可手动恢复并重启服务。

Q: 服务器端口已开但仍无法连接？  
A: 请同时检查云厂商安全组和系统防火墙，确保对应端口的 TCP/UDP 均放行。

Q: 非交互环境怎么用？  
A: 请显式传入 `--action` 与 `--major` 或 `--version`。

Q: 不重装怎么重新输出节点？  
A: 使用 `sudo bash install_snell.sh --print-client`，或加 `--name <profile_name>`。

## 贡献指南

欢迎提交 Issue / PR。

1. Fork 本仓库并创建分支（例如 `feat/xxx` 或 `fix/xxx`）
2. 提交修改并确保脚本可通过基本语法检查：`bash -n install_snell.sh`
3. 提交 PR，描述变更动机、影响范围与验证步骤

建议 PR 关注点:

- 向后兼容（尽量不破坏现有参数）
- 可观测性（日志输出清晰）
- 安全性（避免泄露敏感信息）

## 参考

- Snell Release Notes: https://kb.nssurge.com/surge-knowledge-base/zh/release-notes/snell
- 官方下载源: https://dl.nssurge.com/snell/

## 免责声明

本项目仅用于学习与合法合规用途，请遵守当地法律法规与服务商条款。
