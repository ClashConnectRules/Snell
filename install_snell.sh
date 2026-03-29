#!/usr/bin/env bash
set -euo pipefail

DEFAULT_VERSION_V4="4.1.1"
DEFAULT_VERSION_V5="5.0.1"
VERSION=""
SNELL_MAJOR=""
ACTION=""
REMOVE_SCRIPT="false"
PORT=""
PORT_SET_BY_USER="false"
PSK=""
IPV6="false"
DNS_SERVERS=""
EGRESS_INTERFACE=""
SKIP_FIREWALL="false"
CONFIG_PATH="/etc/snell/snell-server.conf"
BIN_PATH="/usr/local/bin/snell-server"
SERVICE_PATH="/etc/systemd/system/snell.service"
VERSION_MARK_PATH="/etc/snell/version"
SCRIPT_UPDATE_URL="https://raw.githubusercontent.com/ClashConnectRules/Snell/main/install_snell.sh"

show_help() {
  cat <<'EOF'
Snell 一键安装脚本（Linux + systemd）

用法:
  sudo bash install_snell.sh [选项]
  # 若检测到已安装且未指定 --action，默认走 update

选项:
  --action <install|update|uninstall|config|restart|status|script-update>
                              选择操作（安装/更新/卸载/查看配置/重启/状态/更新脚本）
  --remove-script             卸载后删除当前脚本文件
  --major <4|5>               选择安装主版本（推荐）
  --version <ver>             指定精确版本（如 4.1.1 / 5.0.1）
  --port <port>               监听端口（安装时不传则随机）
  --psk <psk>                 指定预共享密钥（不传则自动生成）
  --ipv6 <true|false>         是否启用 IPv6，默认: false
  --dns "<dns1,dns2>"         可选 DNS 参数（v4.1+ 支持）
  --egress-interface <iface>  可选 egress-interface 参数（v5 支持）
  --skip-firewall             跳过防火墙放行步骤
  -h, --help                  显示帮助

示例:
  sudo bash install_snell.sh                # 启动后交互选择操作与版本
  sudo bash install_snell.sh --action update --major 5
  sudo bash install_snell.sh --action uninstall
  sudo bash install_snell.sh --action uninstall --remove-script
  sudo bash install_snell.sh --action config
  sudo bash install_snell.sh --action restart
  sudo bash install_snell.sh --action status
  sudo bash install_snell.sh --action script-update
  sudo bash install_snell.sh --major 4
  sudo bash install_snell.sh --major 5 --port 22333
  sudo bash install_snell.sh --port 22333 --ipv6 false
  sudo bash install_snell.sh --port 22333 --psk "YourStrongPSK"
  sudo bash install_snell.sh --version 4.1.1 --dns "1.1.1.1,8.8.8.8"
EOF
}

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*"
}

die() {
  printf '错误: %s\n' "$*" >&2
  exit 1
}

need_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    die "请使用 root 运行（例如: sudo bash install_snell.sh）"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --action)
        ACTION="${2:-}"; shift 2 ;;
      --remove-script)
        REMOVE_SCRIPT="true"; shift ;;
      --major)
        SNELL_MAJOR="${2:-}"; shift 2 ;;
      --version)
        VERSION="${2:-}"; shift 2 ;;
      --port)
        PORT="${2:-}"; PORT_SET_BY_USER="true"; shift 2 ;;
      --psk)
        PSK="${2:-}"; shift 2 ;;
      --ipv6)
        IPV6="${2:-}"; shift 2 ;;
      --dns)
        DNS_SERVERS="${2:-}"; shift 2 ;;
      --egress-interface)
        EGRESS_INTERFACE="${2:-}"; shift 2 ;;
      --skip-firewall)
        SKIP_FIREWALL="true"; shift ;;
      -h|--help)
        show_help; exit 0 ;;
      *)
        die "未知参数: $1（使用 --help 查看帮助）" ;;
    esac
  done
}

resolve_action_choice() {
  local installed default_choice prompt_hint

  if [[ -n "$ACTION" ]]; then
    case "$ACTION" in
      install|update|uninstall|config|restart|status|script-update) return 0 ;;
      *) die "--action 不支持。可选: install/update/uninstall/config/restart/status/script-update" ;;
    esac
  fi

  installed="false"
  if [[ -f "$CONFIG_PATH" || -f "$BIN_PATH" || -f "$SERVICE_PATH" ]]; then
    installed="true"
  elif command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files | grep -Eq '^snell\.service'; then
    installed="true"
  fi

  if [[ "$installed" == "true" ]]; then
    default_choice="2"
    prompt_hint="（检测到已安装，默认 2 更新）"
  else
    default_choice="1"
    prompt_hint="（默认 1）"
  fi

  if [[ -t 0 ]]; then
    local choice
    printf '请选择操作：\n'
    printf '  1) 安装 Snell\n'
    printf '  2) 更新 Snell（保留现有配置）\n'
    printf '  3) 卸载 Snell（删除服务与配置）\n'
    printf '  4) 查看当前配置\n'
    printf '  5) 重启 Snell 服务\n'
    printf '  6) 查看 Snell 状态\n'
    printf '  7) 更新本脚本\n'
    while true; do
      read -r -p "请输入 1/2/3/4/5/6/7 ${prompt_hint}: " choice
      choice="${choice:-$default_choice}"
      case "$choice" in
        1)
          ACTION="install"
          break
          ;;
        2)
          ACTION="update"
          break
          ;;
        3)
          ACTION="uninstall"
          break
          ;;
        4)
          ACTION="config"
          break
          ;;
        5)
          ACTION="restart"
          break
          ;;
        6)
          ACTION="status"
          break
          ;;
        7)
          ACTION="script-update"
          break
          ;;
        *)
          printf '输入无效，请输入 1、2、3、4、5、6 或 7。\n'
          ;;
      esac
    done
  else
    if [[ "$installed" == "true" ]]; then
      ACTION="update"
      log "检测到已安装 Snell，未指定 --action 时默认执行 update"
    else
      ACTION="install"
    fi
  fi
}

resolve_version_choice() {
  if [[ -n "$VERSION" ]]; then
    case "$VERSION" in
      4.*) SNELL_MAJOR="4" ;;
      5.*) SNELL_MAJOR="5" ;;
      *) SNELL_MAJOR="" ;;
    esac
    return 0
  fi

  if [[ -n "$SNELL_MAJOR" ]]; then
    case "$SNELL_MAJOR" in
      4) VERSION="$DEFAULT_VERSION_V4" ;;
      5) VERSION="$DEFAULT_VERSION_V5" ;;
      *) die "--major 仅支持 4 或 5" ;;
    esac
    return 0
  fi

  if [[ -t 0 ]]; then
    local choice
    printf '请选择 Snell 主版本：\n'
    printf '  1) v4 (%s)\n' "$DEFAULT_VERSION_V4"
    printf '  2) v5 (%s)\n' "$DEFAULT_VERSION_V5"

    while true; do
      read -r -p "请输入 1/2（默认 2）: " choice
      choice="${choice:-2}"
      case "$choice" in
        1|4)
          SNELL_MAJOR="4"
          VERSION="$DEFAULT_VERSION_V4"
          break
          ;;
        2|5)
          SNELL_MAJOR="5"
          VERSION="$DEFAULT_VERSION_V5"
          break
          ;;
        *)
          printf '输入无效，请输入 1 或 2。\n'
          ;;
      esac
    done
  else
    die "当前是非交互环境，请使用 --major 4|5 或 --version x.y.z 指定版本"
  fi
}

validate_args() {
  [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "--version 格式应为 x.y.z"
  if [[ -z "$SNELL_MAJOR" ]]; then
    case "$VERSION" in
      4.*) SNELL_MAJOR="4" ;;
      5.*) SNELL_MAJOR="5" ;;
      *) die "当前脚本仅支持 Snell v4/v5，请使用 4.x.x 或 5.x.x" ;;
    esac
  fi

  if [[ -n "$PORT" ]]; then
    [[ "$PORT" =~ ^[0-9]+$ ]] || die "--port 必须为数字"
    (( PORT >= 1 && PORT <= 65535 )) || die "--port 必须在 1-65535 之间"
  fi
  [[ "$IPV6" == "true" || "$IPV6" == "false" ]] || die "--ipv6 仅支持 true 或 false"

  if [[ "$SNELL_MAJOR" == "4" && -n "$EGRESS_INTERFACE" ]]; then
    die "--egress-interface 仅适用于 Snell v5"
  fi
}

is_port_in_use() {
  local port="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -lntu 2>/dev/null | awk 'NR>1{print $5}' | grep -E -q "(^|[:.])${port}$"
    return $?
  fi
  return 1
}

random_port() {
  local p i
  for i in $(seq 1 200); do
    if command -v shuf >/dev/null 2>&1; then
      p="$(shuf -i 10000-65535 -n 1)"
    else
      p="$(( (RANDOM % 55536) + 10000 ))"
    fi
    if ! is_port_in_use "$p"; then
      echo "$p"
      return 0
    fi
  done
  echo "6160"
}

resolve_install_port() {
  if [[ "$ACTION" != "install" ]]; then
    return 0
  fi

  if [[ "$PORT_SET_BY_USER" == "true" ]]; then
    return 0
  fi

  if [[ -t 0 ]]; then
    local input_port
    read -r -p "请输入监听端口（回车使用随机端口）: " input_port
    if [[ -n "${input_port:-}" ]]; then
      PORT="$input_port"
      PORT_SET_BY_USER="true"
      return 0
    fi
  fi

  PORT="$(random_port)"
  log "未指定端口，已自动选择随机端口: ${PORT}"
}

config_get_value() {
  local key="$1"
  if [[ ! -f "$CONFIG_PATH" ]]; then
    return 0
  fi
  sed -n "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*//p" "$CONFIG_PATH" | head -n 1
}

get_installed_major() {
  local ver
  if [[ -f "$VERSION_MARK_PATH" ]]; then
    ver="$(tr -d '[:space:]' < "$VERSION_MARK_PATH")"
    case "$ver" in
      4.*) echo "4"; return 0 ;;
      5.*) echo "5"; return 0 ;;
      4|5) echo "$ver"; return 0 ;;
      *) ;;
    esac
  fi
  echo "unknown"
}

detect_arch() {
  local machine
  machine="$(uname -m)"
  case "$machine" in
    x86_64|amd64) echo "amd64" ;;
    i386|i686) echo "i386" ;;
    aarch64|arm64) echo "aarch64" ;;
    armv7l|armv7) echo "armv7l" ;;
    *) die "不支持的架构: $machine" ;;
  esac
}

install_deps() {
  if command -v curl >/dev/null 2>&1 && \
     (command -v unzip >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1 || command -v bsdtar >/dev/null 2>&1); then
    log "依赖已满足（curl + 压缩解包工具），跳过安装"
    return 0
  fi

  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    if ! apt-get update -y; then
      log "apt-get update 失败，尝试直接安装依赖（可能是第三方源签名问题）"
    fi
    apt-get install -y curl unzip || die "apt-get 安装依赖失败，请修复软件源后重试"
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y curl unzip || die "dnf 安装依赖失败"
  elif command -v yum >/dev/null 2>&1; then
    yum install -y curl unzip || die "yum 安装依赖失败"
  elif command -v apk >/dev/null 2>&1; then
    apk add --no-cache curl unzip || die "apk 安装依赖失败"
  else
    die "无法识别包管理器，请手动安装 curl 和 unzip"
  fi
}

extract_snell_binary() {
  local zip_file="$1"

  if command -v unzip >/dev/null 2>&1; then
    unzip -o "$zip_file" -d /tmp >/dev/null
    return 0
  fi

  if command -v bsdtar >/dev/null 2>&1; then
    bsdtar -xf "$zip_file" -C /tmp
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$zip_file" <<'PY'
import sys
import zipfile

zip_path = sys.argv[1]
with zipfile.ZipFile(zip_path, "r") as zf:
    zf.extractall("/tmp")
PY
    return 0
  fi

  die "未找到可用解压工具（unzip/bsdtar/python3）"
}

generate_psk() {
  if [[ -n "$PSK" ]]; then
    return 0
  fi

  if command -v openssl >/dev/null 2>&1; then
    PSK="$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c 32)"
  else
    PSK="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32)"
  fi

  [[ -n "$PSK" ]] || die "自动生成 PSK 失败，请手动通过 --psk 指定"
}

download_and_install_binary() {
  local arch url tmp_zip
  arch="$(detect_arch)"
  url="https://dl.nssurge.com/snell/snell-server-v${VERSION}-linux-${arch}.zip"
  tmp_zip="/tmp/snell-server-v${VERSION}-linux-${arch}.zip"

  log "下载: $url"
  curl -fL --retry 3 --retry-delay 2 -o "$tmp_zip" "$url"

  log "安装二进制到 $BIN_PATH"
  extract_snell_binary "$tmp_zip"
  install -m 0755 /tmp/snell-server "$BIN_PATH"
  rm -f "$tmp_zip" /tmp/snell-server
}

write_config() {
  local cfg_dir
  cfg_dir="$(dirname "$CONFIG_PATH")"
  mkdir -p "$cfg_dir"

  {
    echo "[snell-server]"
    echo "listen = 0.0.0.0:${PORT}"
    echo "psk = ${PSK}"
    echo "ipv6 = ${IPV6}"
    if [[ -n "$DNS_SERVERS" ]]; then
      echo "dns = ${DNS_SERVERS}"
    fi
    if [[ -n "$EGRESS_INTERFACE" ]]; then
      echo "egress-interface = ${EGRESS_INTERFACE}"
    fi
  } > "$CONFIG_PATH"

  chmod 600 "$CONFIG_PATH"
}

write_service() {
  cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=Snell Proxy Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${BIN_PATH} -c ${CONFIG_PATH}
Restart=on-failure
RestartSec=3
LimitNOFILE=512000

[Install]
WantedBy=multi-user.target
EOF
}

try_configure_firewall() {
  if [[ "$SKIP_FIREWALL" == "true" ]]; then
    log "已跳过防火墙步骤"
    return 0
  fi

  if command -v ufw >/dev/null 2>&1; then
    ufw allow "${PORT}/tcp" || true
    ufw allow "${PORT}/udp" || true
    log "已尝试通过 ufw 放行 ${PORT}/tcp 和 ${PORT}/udp"
  elif command -v firewall-cmd >/dev/null 2>&1; then
    firewall-cmd --permanent --add-port="${PORT}/tcp" || true
    firewall-cmd --permanent --add-port="${PORT}/udp" || true
    firewall-cmd --reload || true
    log "已尝试通过 firewalld 放行 ${PORT}/tcp 和 ${PORT}/udp"
  else
    log "未检测到 ufw/firewalld，请自行放行端口 ${PORT}（TCP/UDP）"
  fi
}

start_service() {
  systemctl daemon-reload
  systemctl enable snell.service >/dev/null 2>&1 || true

  if systemctl is-active --quiet snell.service; then
    log "检测到 snell.service 已在运行，执行重启以应用新配置"
    systemctl restart snell.service
  else
    systemctl start snell.service
  fi
}

get_public_ip() {
  local ip
  ip="$(curl -4 -fsS --max-time 3 https://api.ipify.org || true)"
  if [[ -z "$ip" ]]; then
    ip="$(curl -4 -fsS --max-time 3 https://ipv4.icanhazip.com 2>/dev/null | tr -d '[:space:]' || true)"
  fi
  echo "$ip"
}

json_value() {
  local json="$1"
  local key="$2"
  printf '%s' "$json" | tr -d '\n' | sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p"
}

sanitize_region_tag() {
  local raw="$1"
  printf '%s' "$raw" \
    | sed 's/[[:space:]]\+/-/g; s/[^A-Za-z0-9._-]/-/g; s/--\+/-/g; s/^-//; s/-$//'
}

get_ip_region_tag() {
  local ip body country region tag
  ip="$1"
  tag=""

  if [[ -z "$ip" || "$ip" == "<你的服务器IP>" ]]; then
    echo "region"
    return 0
  fi

  body="$(curl -fsS --max-time 4 "https://ipapi.co/${ip}/json/" 2>/dev/null || true)"
  country="$(json_value "$body" "country_name")"
  region="$(json_value "$body" "region")"

  if [[ -z "$country" && -z "$region" ]]; then
    body="$(curl -fsS --max-time 4 "https://ipwho.is/${ip}" 2>/dev/null || true)"
    country="$(json_value "$body" "country")"
    region="$(json_value "$body" "region")"
  fi

  if [[ -n "$country" && -n "$region" && "$country" != "$region" ]]; then
    tag="${country}-${region}"
  elif [[ -n "$country" ]]; then
    tag="$country"
  elif [[ -n "$region" ]]; then
    tag="$region"
  else
    tag="$ip"
  fi

  tag="$(sanitize_region_tag "$tag")"
  if [[ -z "$tag" ]]; then
    tag="$ip"
  fi
  echo "$tag"
}

print_node_examples() {
  local pub_ip="$1"
  local region_tag="$2"
  local port="$3"
  local psk="$4"
  local major="$5"
  local node_v4 node_v5

  node_v4="${region_tag}-snellv4"
  node_v5="${region_tag}-snellv5"

  if [[ "$major" == "5" ]]; then
    cat <<EOF

Surge 节点示例（Snell v5）:
  ${node_v5} = snell, ${pub_ip}, ${port}, psk=${psk}, version=5, reuse=true, tfo=true

兼容模式（客户端按 v4 连接）:
  ${node_v4} = snell, ${pub_ip}, ${port}, psk=${psk}, version=4, reuse=true, tfo=true
EOF
  elif [[ "$major" == "4" ]]; then
    cat <<EOF

Surge 节点示例（Snell v4）:
  ${node_v4} = snell, ${pub_ip}, ${port}, psk=${psk}, version=4, reuse=true, tfo=true
EOF
  else
    cat <<EOF

Surge 节点示例（版本未知，建议先确认客户端版本）:
  ${node_v4} = snell, ${pub_ip}, ${port}, psk=${psk}, version=4, reuse=true, tfo=true
  ${node_v5} = snell, ${pub_ip}, ${port}, psk=${psk}, version=5, reuse=true, tfo=true
EOF
  fi
}

write_version_marker() {
  local cfg_dir
  cfg_dir="$(dirname "$VERSION_MARK_PATH")"
  mkdir -p "$cfg_dir"
  printf '%s\n' "$VERSION" > "$VERSION_MARK_PATH"
  chmod 600 "$VERSION_MARK_PATH" || true
}

print_summary() {
  local pub_ip region_tag
  pub_ip="$(get_public_ip)"
  if [[ -z "$pub_ip" ]]; then
    pub_ip="<你的服务器IP>"
  fi
  region_tag="$(get_ip_region_tag "$pub_ip")"

  cat <<EOF

========================================
Snell 安装完成
========================================
版本: v${VERSION}
二进制: ${BIN_PATH}
配置文件: ${CONFIG_PATH}
端口: ${PORT}
PSK: ${PSK}
IPv6: ${IPV6}
服务状态:
  systemctl status snell.service --no-pager
常用命令:
  systemctl restart snell.service
  journalctl -u snell.service -f
节点名称前缀:
  ${region_tag}
EOF

  print_node_examples "$pub_ip" "$region_tag" "$PORT" "$PSK" "$SNELL_MAJOR"
}

run_install_flow() {
  validate_args

  log "已选择 Snell v${VERSION}"
  log "安装依赖"
  install_deps
  generate_psk

  log "下载并安装 Snell v${VERSION}"
  download_and_install_binary

  log "写入配置文件"
  write_config
  write_version_marker

  log "写入 systemd 服务"
  write_service

  log "启动服务"
  start_service

  try_configure_firewall
  print_summary
}

run_update_flow() {
  local backup_path="" cfg_backup_path=""

  [[ -f "$CONFIG_PATH" ]] || die "未找到配置文件 ${CONFIG_PATH}，请先执行安装流程"

  if [[ "$PORT_SET_BY_USER" == "true" ]]; then
    log "update 模式不会修改端口，已忽略 --port=${PORT}"
  fi

  validate_args
  log "已选择更新到 Snell v${VERSION}"
  log "安装依赖"
  install_deps

  if [[ -f "$BIN_PATH" ]]; then
    backup_path="${BIN_PATH}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$BIN_PATH" "$backup_path"
    log "已备份旧二进制: ${backup_path}"
  fi
  if [[ -f "$CONFIG_PATH" ]]; then
    cfg_backup_path="${CONFIG_PATH}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$CONFIG_PATH" "$cfg_backup_path"
    log "已备份配置文件: ${cfg_backup_path}"
  fi

  log "下载并安装 Snell v${VERSION}"
  download_and_install_binary
  write_version_marker

  if systemctl list-unit-files | grep -Eq '^snell\.service'; then
    log "重启 snell.service"
    systemctl daemon-reload
    systemctl restart snell.service
  else
    log "未检测到 snell.service，请手动启动服务"
  fi

  cat <<EOF

========================================
Snell 更新完成
========================================
版本: v${VERSION}
二进制: ${BIN_PATH}
配置文件: ${CONFIG_PATH}（已保留）
服务状态:
  systemctl status snell.service --no-pager

常用命令:
  systemctl restart snell.service
  journalctl -u snell.service -f
EOF
}

run_config_flow() {
  local pub_ip region_tag major listen psk port

  [[ -f "$CONFIG_PATH" ]] || die "未找到配置文件 ${CONFIG_PATH}"
  pub_ip="$(get_public_ip)"
  if [[ -z "$pub_ip" ]]; then
    pub_ip="<你的服务器IP>"
  fi
  region_tag="$(get_ip_region_tag "$pub_ip")"
  major="$(get_installed_major)"
  listen="$(config_get_value "listen")"
  psk="$(config_get_value "psk")"
  port="${listen##*:}"
  if [[ -z "$port" || "$port" == "$listen" ]]; then
    port="<port>"
  fi

  cat <<EOF

========================================
当前 Snell 配置
========================================
配置文件: ${CONFIG_PATH}
版本标记: ${major}
listen: ${listen}
psk: ${psk}
ipv6: $(config_get_value "ipv6")
dns: $(config_get_value "dns")
egress-interface: $(config_get_value "egress-interface")
EOF

  print_node_examples "$pub_ip" "$region_tag" "$port" "$psk" "$major"
}

run_restart_flow() {
  if ! command -v systemctl >/dev/null 2>&1; then
    die "未检测到 systemctl，无法重启服务"
  fi
  if ! systemctl list-unit-files | grep -Eq '^snell\.service'; then
    die "未检测到 snell.service，请先安装"
  fi
  systemctl daemon-reload
  systemctl restart snell.service
  log "snell.service 已重启"
  systemctl status snell.service --no-pager || true
}

run_status_flow() {
  local listen
  if command -v systemctl >/dev/null 2>&1; then
    systemctl status snell.service --no-pager || true
  else
    log "未检测到 systemctl"
  fi

  listen="$(config_get_value "listen")"
  if [[ -n "$listen" && "$listen" == *:* ]]; then
    local port
    port="${listen##*:}"
    if command -v ss >/dev/null 2>&1; then
      echo
      echo "端口监听（${port}）:"
      ss -lntup | grep -E "[.:]${port}[[:space:]]" || true
    fi
  fi
}

run_script_update_flow() {
  local script_self tmp_new
  script_self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
  tmp_new="/tmp/install_snell.sh.new.$$"

  log "下载最新脚本: ${SCRIPT_UPDATE_URL}"
  curl -fsSL -o "$tmp_new" "$SCRIPT_UPDATE_URL"
  grep -q '^#!/usr/bin/env bash' "$tmp_new" || die "下载的脚本内容异常，已取消更新"

  if cmp -s "$tmp_new" "$script_self"; then
    rm -f "$tmp_new"
    log "当前已是最新脚本，无需更新"
    return 0
  fi

  install -m 0755 "$tmp_new" "$script_self"
  rm -f "$tmp_new"
  log "脚本更新完成: ${script_self}"
}

confirm_uninstall() {
  if [[ -t 0 ]]; then
    local answer
    read -r -p "确认卸载 Snell 并删除服务/配置/二进制？[y/N]: " answer
    case "${answer:-N}" in
      y|Y|yes|YES) return 0 ;;
      *) die "已取消卸载" ;;
    esac
  fi
}

cleanup_empty_parent() {
  local dir="$1"
  if [[ -d "$dir" ]] && [[ -z "$(ls -A "$dir" 2>/dev/null)" ]]; then
    rmdir "$dir" || true
  fi
}

run_uninstall_flow() {
  local script_self cfg_dir removed_script
  removed_script="false"
  script_self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
  cfg_dir="$(dirname "$CONFIG_PATH")"

  confirm_uninstall
  log "开始卸载 Snell"

  if command -v systemctl >/dev/null 2>&1; then
    if systemctl list-unit-files | grep -Eq '^snell\.service'; then
      systemctl stop snell.service || true
      systemctl disable snell.service || true
      log "已停止并禁用 snell.service"
    else
      log "未检测到 snell.service，跳过 stop/disable"
    fi
  else
    log "未检测到 systemctl，跳过服务管理"
  fi

  if [[ -f "$SERVICE_PATH" ]]; then
    rm -f "$SERVICE_PATH"
    log "已删除服务文件: $SERVICE_PATH"
  fi
  if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload || true
  fi

  if [[ -f "$CONFIG_PATH" ]]; then
    rm -f "$CONFIG_PATH"
    log "已删除配置文件: $CONFIG_PATH"
  fi
  cleanup_empty_parent "$cfg_dir"

  if [[ -f "$BIN_PATH" ]]; then
    rm -f "$BIN_PATH"
    log "已删除二进制: $BIN_PATH"
  fi
  rm -f "${BIN_PATH}.bak".* 2>/dev/null || true

  if [[ "$REMOVE_SCRIPT" != "true" && -t 0 ]]; then
    local answer
    read -r -p "是否同时删除当前脚本 ${script_self} ? [y/N]: " answer
    case "${answer:-N}" in
      y|Y|yes|YES) REMOVE_SCRIPT="true" ;;
      *) ;;
    esac
  fi

  if [[ "$REMOVE_SCRIPT" == "true" && -f "$script_self" ]]; then
    rm -f "$script_self"
    removed_script="true"
  fi

  cat <<EOF

========================================
Snell 卸载完成
========================================
已删除:
  - $SERVICE_PATH
  - $CONFIG_PATH
  - $BIN_PATH
EOF

  if [[ "$removed_script" == "true" ]]; then
    cat <<EOF
  - $script_self
EOF
  fi
}

main() {
  parse_args "$@"
  need_root
  resolve_action_choice

  if [[ "$ACTION" == "install" || "$ACTION" == "update" ]]; then
    resolve_version_choice
  fi
  if [[ "$ACTION" == "install" ]]; then
    resolve_install_port
  fi

  case "$ACTION" in
    install) run_install_flow ;;
    update) run_update_flow ;;
    uninstall) run_uninstall_flow ;;
    config) run_config_flow ;;
    restart) run_restart_flow ;;
    status) run_status_flow ;;
    script-update) run_script_update_flow ;;
    *) die "未知操作: $ACTION" ;;
  esac
}

main "$@"
