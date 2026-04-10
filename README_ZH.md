# Snell 一键脚本

## 优质机场推荐

[![推荐机场](https://img.shields.io/badge/推荐机场-ZRJ-f97316?style=for-the-badge)](https://hizrj.xyz/#/register?code=BwiZnFLE)
[![立即注册](https://img.shields.io/badge/立即注册-Open_Link-0f766e?style=for-the-badge)](https://hizrj.xyz/#/register?code=BwiZnFLE)

> 优质机场推荐: **[ZRJ](https://hizrj.xyz/#/register?code=BwiZnFLE)**

[![Platform](https://img.shields.io/badge/Platform-Linux-2ea44f?style=for-the-badge)](https://www.kernel.org/)
[![Shell](https://img.shields.io/badge/Shell-Bash-121011?logo=gnu-bash&logoColor=white&style=for-the-badge)](https://www.gnu.org/software/bash/)
[![systemd](https://img.shields.io/badge/Init-systemd-003b57?logo=systemd&logoColor=white&style=for-the-badge)](https://systemd.io/)
[![Stars](https://img.shields.io/github/stars/ClashConnectRules/Snell?style=for-the-badge)](https://github.com/ClashConnectRules/Snell/stargazers)
[![Last Commit](https://img.shields.io/github/last-commit/ClashConnectRules/Snell?style=for-the-badge)](https://github.com/ClashConnectRules/Snell/commits/main)

适用于 Linux + systemd 的 Snell 部署脚本，内置菜单管理。

- English: [README.md](./README.md)
- 文档导航: [docs/INDEX.md](./docs/INDEX.md)
- 中文详版: [docs/README_FULL_ZH.md](./docs/README_FULL_ZH.md)
- English Full Docs: [docs/README_FULL.md](./docs/README_FULL.md)
- 仓库地址: `https://github.com/ClashConnectRules/Snell.git`

## 快速开始

直链执行（推荐）：

```bash
curl -fsSL https://cdn.jsdelivr.net/gh/ClashConnectRules/Snell@main/install_snell.sh -o install_snell.sh \
  || curl -fsSL https://fastly.jsdelivr.net/gh/ClashConnectRules/Snell@main/install_snell.sh -o install_snell.sh
grep -q '^#!/usr/bin/env bash' install_snell.sh && chmod +x install_snell.sh && bash install_snell.sh
```

非 root 用户请把 `bash install_snell.sh` 改为 `sudo bash install_snell.sh`。

克隆执行：

```bash
git clone https://github.com/ClashConnectRules/Snell.git
cd Snell
chmod +x install_snell.sh
bash install_snell.sh
```

## 功能速览

- Snell `v4/v5` 安装、更新、卸载
- 分层 2 级交互菜单
- 菜单头部展示 `CPU / MEM / DISK`
- 主服务管理：配置/重启/状态
- Profile 多用户端口：新增/列表/删除
- BBR：启用/关闭/状态
- Docker 模式：部署/移除/状态
- ShadowTLS：部署/移除/状态
- 任意时刻输出客户端节点：`--print-client`

## 常用命令

主服务：

```bash
sudo bash install_snell.sh --action install --major 5 --port 22333
sudo bash install_snell.sh --action update --major 5
sudo bash install_snell.sh --action status
sudo bash install_snell.sh --action restart
sudo bash install_snell.sh --action uninstall
```

Profile：

```bash
sudo bash install_snell.sh --action profile-add --name hk-a --major 5 --port 31001
sudo bash install_snell.sh --action profile-list
sudo bash install_snell.sh --action profile-remove --name hk-a
```

ShadowTLS：

```bash
sudo bash install_snell.sh --action stls-deploy
sudo bash install_snell.sh --action stls-status
sudo bash install_snell.sh --action stls-remove
```

脚本管理：

```bash
sudo bash install_snell.sh --action script-update
sudo bash install_snell.sh --action purge-all
```

客户端配置输出：

```bash
sudo bash install_snell.sh --print-client
sudo bash install_snell.sh --print-client --name main
sudo bash install_snell.sh --print-client --name hk-a
```

## 关键参数

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

完整参数说明、示例、路径、FAQ 请看：
- [docs/INDEX.md](./docs/INDEX.md)
- [docs/README_FULL_ZH.md](./docs/README_FULL_ZH.md)

## 免责声明

本项目仅用于合法合规场景，请遵守当地法律法规与服务商条款。
