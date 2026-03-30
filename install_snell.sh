#!/usr/bin/env bash
set -euo pipefail

DEFAULT_VERSION_V4="4.1.1"
DEFAULT_VERSION_V5="5.0.1"
VERSION=""
SNELL_MAJOR=""
ACTION=""
REMOVE_SCRIPT="false"
PROFILE_NAME=""
PRINT_CLIENT="false"
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
PROFILES_DIR="/etc/snell/profiles"
PROFILE_TEMPLATE_SERVICE_PATH="/etc/systemd/system/snell@.service"
PROFILE_VERSION_DIR="/etc/snell/profile-versions"
BBR_SYSCTL_PATH="/etc/sysctl.d/99-snell-bbr.conf"
DOCKER_DIR="/etc/snell/docker"
DOCKER_CONFIG_PATH="/etc/snell/docker/snell-server.conf"
DOCKER_COMPOSE_PATH="/etc/snell/docker/compose.yaml"
DOCKER_CONTAINER_NAME="snell-docker"
STLS_BIN_PATH="/usr/local/bin/shadow-tls"
STLS_SERVICE_PATH="/etc/systemd/system/shadowtls.service"
STLS_ENV_PATH="/etc/snell/shadowtls.env"
STLS_RELEASE_API="https://api.github.com/repos/ihciah/shadow-tls/releases/latest"
STLS_VERSION="3"
STLS_PORT="443"
STLS_PASSWORD=""
STLS_SNI="gateway.icloud.com"
STLS_UPSTREAM=""
STLS_BACKEND_PSK=""
STLS_BACKEND_MAJOR="unknown"
STLS_BACKEND_LABEL=""

show_help() {
  cat <<'EOF'
Snell 一键安装脚本（Linux + systemd）

用法:
  sudo bash install_snell.sh [选项]
  # 若检测到已安装且未指定 --action，默认走 update

选项:
  --action <install|update|uninstall|config|restart|status|script-update|profile-add|profile-list|profile-remove|bbr-enable|bbr-disable|bbr-status|docker-deploy|docker-remove|docker-status|stls-deploy|stls-remove|stls-status|print-client>
                              选择操作（安装/更新/卸载/配置/重启/状态/脚本更新/多用户/BBR/Docker/ShadowTLS）
  --name <profile_name>       Profile 名称（多用户动作时使用）
  --print-client              仅输出当前客户端配置（不安装/不更新）
  --remove-script             卸载后删除当前脚本文件
  --major <4|5>               选择安装主版本（推荐）
  --version <ver>             指定精确版本（如 4.1.1 / 5.0.1）
  --port <port>               监听端口（安装时不传则随机）
  --psk <psk>                 指定预共享密钥（不传则自动生成）
  --ipv6 <true|false>         是否启用 IPv6，默认: false
  --dns "<dns1,dns2>"         可选 DNS 参数（v4.1+ 支持）
  --egress-interface <iface>  可选 egress-interface 参数（v5 支持）
  --stls-version <2|3>        ShadowTLS 版本（默认 3）
  --stls-port <port>          ShadowTLS 监听端口（默认 443）
  --stls-password <password>  ShadowTLS 密码（不传则自动生成）
  --stls-sni <sni>            ShadowTLS SNI（默认 gateway.icloud.com）
  --stls-upstream <ip:port>   ShadowTLS 上游地址（默认自动选择）
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
  sudo bash install_snell.sh --action profile-add --name hk-a --major 5 --port 31001
  sudo bash install_snell.sh --action profile-list
  sudo bash install_snell.sh --action profile-remove --name hk-a
  sudo bash install_snell.sh --action bbr-status
  sudo bash install_snell.sh --action bbr-enable
  sudo bash install_snell.sh --action docker-deploy --major 5 --port 31001
  sudo bash install_snell.sh --action docker-status
  sudo bash install_snell.sh --action docker-remove
  sudo bash install_snell.sh --action stls-deploy
  sudo bash install_snell.sh --action stls-status
  sudo bash install_snell.sh --action stls-remove
  sudo bash install_snell.sh --print-client
  sudo bash install_snell.sh --print-client --name hk-a
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
      --name)
        PROFILE_NAME="${2:-}"; shift 2 ;;
      --print-client)
        PRINT_CLIENT="true"; shift ;;
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
      --stls-version)
        STLS_VERSION="${2:-}"; shift 2 ;;
      --stls-port)
        STLS_PORT="${2:-}"; shift 2 ;;
      --stls-password)
        STLS_PASSWORD="${2:-}"; shift 2 ;;
      --stls-sni)
        STLS_SNI="${2:-}"; shift 2 ;;
      --stls-upstream)
        STLS_UPSTREAM="${2:-}"; shift 2 ;;
      --skip-firewall)
        SKIP_FIREWALL="true"; shift ;;
      -h|--help)
        show_help; exit 0 ;;
      *)
        die "未知参数: $1（使用 --help 查看帮助）" ;;
    esac
  done
}

is_snell_installed() {
  if [[ -f "$CONFIG_PATH" || -f "$BIN_PATH" || -f "$SERVICE_PATH" ]]; then
    return 0
  fi
  if command -v systemctl >/dev/null 2>&1; then
    systemctl list-unit-files --type=service 2>/dev/null | awk '{print $1}' | grep -Fxq 'snell.service'
    return $?
  fi
  return 1
}

unit_state() {
  local unit="$1"
  if ! command -v systemctl >/dev/null 2>&1; then
    echo "no-systemd"
    return 0
  fi
  if systemctl is-active --quiet "$unit" 2>/dev/null; then
    echo "active"
    return 0
  fi
  if systemctl list-unit-files --type=service 2>/dev/null | awk '{print $1}' | grep -Fxq "$unit"; then
    echo "inactive"
  else
    echo "not-installed"
  fi
}

count_profiles() {
  local count conf
  count=0
  if [[ -d "$PROFILES_DIR" ]]; then
    for conf in "$PROFILES_DIR"/*.conf; do
      [[ -e "$conf" ]] || continue
      count=$((count + 1))
    done
  fi
  echo "$count"
}

count_active_profile_services() {
  local c
  c=0
  if command -v systemctl >/dev/null 2>&1; then
    c="$(systemctl list-units --all --type=service 'snell@*.service' --no-legend 2>/dev/null | awk '$3=="active" && $4=="running"{c++} END{print c+0}')"
  fi
  echo "${c:-0}"
}

format_kb_human() {
  local kb="$1"
  awk -v kb="$kb" 'BEGIN{
    if (kb >= 1048576) printf "%.1fG", kb/1048576;
    else if (kb >= 1024) printf "%.1fM", kb/1024;
    else printf "%dK", kb;
  }'
}

get_cpu_usage_pct() {
  local user1 nice1 sys1 idle1 iow1 irq1 sirq1 stl1 total1 idleall1
  local user2 nice2 sys2 idle2 iow2 irq2 sirq2 stl2 total2 idleall2
  local diff_total diff_idle usage
  if [[ ! -r /proc/stat ]]; then
    echo "N/A"
    return 0
  fi
  read -r _ user1 nice1 sys1 idle1 iow1 irq1 sirq1 stl1 _ < /proc/stat || { echo "N/A"; return 0; }
  total1=$((user1 + nice1 + sys1 + idle1 + iow1 + irq1 + sirq1 + stl1))
  idleall1=$((idle1 + iow1))
  sleep 0.15
  read -r _ user2 nice2 sys2 idle2 iow2 irq2 sirq2 stl2 _ < /proc/stat || { echo "N/A"; return 0; }
  total2=$((user2 + nice2 + sys2 + idle2 + iow2 + irq2 + sirq2 + stl2))
  idleall2=$((idle2 + iow2))
  diff_total=$((total2 - total1))
  diff_idle=$((idleall2 - idleall1))
  if (( diff_total <= 0 )); then
    echo "N/A"
    return 0
  fi
  usage=$(( (100 * (diff_total - diff_idle) + diff_total / 2) / diff_total ))
  echo "${usage}%"
}

get_mem_usage_summary() {
  local total avail used pct
  if [[ ! -r /proc/meminfo ]]; then
    echo "N/A"
    return 0
  fi
  total="$(awk '/MemTotal:/{print $2}' /proc/meminfo)"
  avail="$(awk '/MemAvailable:/{print $2}' /proc/meminfo)"
  if [[ -z "$total" || -z "$avail" || "$total" == "0" ]]; then
    echo "N/A"
    return 0
  fi
  used=$((total - avail))
  pct=$(( (used * 100 + total / 2) / total ))
  echo "$(format_kb_human "$used")/$(format_kb_human "$total") (${pct}%)"
}

get_disk_usage_summary() {
  if ! command -v df >/dev/null 2>&1; then
    echo "N/A"
    return 0
  fi
  df -hP / 2>/dev/null | awk 'NR==2{print $3 "/" $2 " (" $5 ")"}'
}

get_system_usage_summary() {
  echo "CPU $(get_cpu_usage_pct) | MEM $(get_mem_usage_summary) | DISK $(get_disk_usage_summary)"
}

get_snell_runtime_summary() {
  local state listen major
  state="$(unit_state 'snell.service')"
  listen="$(config_get_value_from_file "$CONFIG_PATH" "listen")"
  major="$(get_installed_major)"
  echo "service=${state}, version=${major}, listen=${listen:-N/A}"
}

get_profile_runtime_summary() {
  local total active
  total="$(count_profiles)"
  active="$(count_active_profile_services)"
  echo "profiles=${total}, active=${active}"
}

get_bbr_runtime_summary() {
  local cc qdisc
  cc="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo unknown)"
  qdisc="$(sysctl -n net.core.default_qdisc 2>/dev/null || echo unknown)"
  echo "congestion=${cc}, qdisc=${qdisc}"
}

get_docker_runtime_summary() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "docker=not-installed"
    return 0
  fi
  if ! docker info >/dev/null 2>&1; then
    echo "docker=daemon-down"
    return 0
  fi
  if docker ps --format '{{.Names}}' | grep -Fxq "$DOCKER_CONTAINER_NAME"; then
    echo "container=running(${DOCKER_CONTAINER_NAME})"
  elif docker ps -a --format '{{.Names}}' | grep -Fxq "$DOCKER_CONTAINER_NAME"; then
    echo "container=stopped(${DOCKER_CONTAINER_NAME})"
  else
    echo "container=not-created"
  fi
}

get_stls_runtime_summary() {
  local state listen upstream
  state="$(unit_state 'shadowtls.service')"
  listen="$(sed -n 's/^STLS_LISTEN=//p' "$STLS_ENV_PATH" 2>/dev/null | head -n 1)"
  upstream="$(sed -n 's/^STLS_UPSTREAM=//p' "$STLS_ENV_PATH" 2>/dev/null | head -n 1)"
  echo "service=${state}, listen=${listen:-N/A}, upstream=${upstream:-N/A}"
}

print_menu_header() {
  local title="$1"
  local runtime="$2"
  if [[ -t 1 ]] && command -v clear >/dev/null 2>&1; then
    clear
  fi
  echo "========================================"
  echo "$title"
  echo "运行: ${runtime}"
  echo "资源: $(get_system_usage_summary)"
  echo "========================================"
}

choose_action_from_snell_menu() {
  local default_action="$1"
  local default_choice prompt_hint choice
  if [[ "$default_action" == "update" ]]; then
    default_choice="0"
    prompt_hint="（已安装，推荐 2 更新；默认 0 返回）"
  else
    default_choice="1"
    prompt_hint="（默认 1）"
  fi

  while true; do
    print_menu_header "Snell 主服务" "$(get_snell_runtime_summary)"
    echo "  1) 安装 Snell"
    echo "  2) 更新 Snell（保留现有配置）"
    echo "  3) 卸载 Snell（删除服务与配置）"
    echo "  4) 查看当前配置"
    echo "  5) 重启 Snell 服务"
    echo "  6) 查看 Snell 状态"
    echo "  0) 返回上一级"
    read -r -p "请输入 0-6 ${prompt_hint}: " choice
    choice="${choice:-$default_choice}"
    case "$choice" in
      1) ACTION="install"; return 0 ;;
      2) ACTION="update"; return 0 ;;
      3) ACTION="uninstall"; return 0 ;;
      4) ACTION="config"; return 0 ;;
      5) ACTION="restart"; return 0 ;;
      6) ACTION="status"; return 0 ;;
      0) return 1 ;;
      *) echo "输入无效，请输入 0 到 6。" ;;
    esac
  done
}

choose_action_from_profile_menu() {
  local choice
  while true; do
    print_menu_header "多用户 Profile 管理" "$(get_profile_runtime_summary)"
    echo "  1) 新增 Profile 端口"
    echo "  2) 查看 Profile 列表"
    echo "  3) 删除 Profile"
    echo "  0) 返回上一级"
    read -r -p "请输入 0-3: " choice
    case "$choice" in
      1) ACTION="profile-add"; return 0 ;;
      2) ACTION="profile-list"; return 0 ;;
      3) ACTION="profile-remove"; return 0 ;;
      0) return 1 ;;
      *) echo "输入无效，请输入 0 到 3。" ;;
    esac
  done
}

choose_action_from_bbr_menu() {
  local choice
  while true; do
    print_menu_header "BBR 管理" "$(get_bbr_runtime_summary)"
    echo "  1) 启用 BBR"
    echo "  2) 关闭 BBR"
    echo "  3) 查看 BBR 状态"
    echo "  0) 返回上一级"
    read -r -p "请输入 0-3: " choice
    case "$choice" in
      1) ACTION="bbr-enable"; return 0 ;;
      2) ACTION="bbr-disable"; return 0 ;;
      3) ACTION="bbr-status"; return 0 ;;
      0) return 1 ;;
      *) echo "输入无效，请输入 0 到 3。" ;;
    esac
  done
}

choose_action_from_docker_menu() {
  local choice
  while true; do
    print_menu_header "Docker 模式" "$(get_docker_runtime_summary)"
    echo "  1) 部署 Snell（Docker）"
    echo "  2) 移除 Snell（Docker）"
    echo "  3) 查看 Docker 状态"
    echo "  0) 返回上一级"
    read -r -p "请输入 0-3: " choice
    case "$choice" in
      1) ACTION="docker-deploy"; return 0 ;;
      2) ACTION="docker-remove"; return 0 ;;
      3) ACTION="docker-status"; return 0 ;;
      0) return 1 ;;
      *) echo "输入无效，请输入 0 到 3。" ;;
    esac
  done
}

choose_action_from_stls_menu() {
  local choice
  while true; do
    print_menu_header "ShadowTLS 管理" "$(get_stls_runtime_summary)"
    echo "  1) 部署 ShadowTLS"
    echo "  2) 移除 ShadowTLS"
    echo "  3) 查看 ShadowTLS 状态"
    echo "  0) 返回上一级"
    read -r -p "请输入 0-3: " choice
    case "$choice" in
      1) ACTION="stls-deploy"; return 0 ;;
      2) ACTION="stls-remove"; return 0 ;;
      3) ACTION="stls-status"; return 0 ;;
      0) return 1 ;;
      *) echo "输入无效，请输入 0 到 3。" ;;
    esac
  done
}

choose_action_from_client_menu() {
  local choice input_name
  while true; do
    print_menu_header "客户端配置输出" "$(get_snell_runtime_summary)"
    echo "  1) 输出全部客户端节点"
    echo "  2) 仅输出指定 name（main 或 profile）"
    echo "  0) 返回上一级"
    read -r -p "请输入 0-2: " choice
    case "$choice" in
      1)
        PROFILE_NAME=""
        ACTION="print-client"
        return 0
        ;;
      2)
        read -r -p "请输入 name（main 或 profile 名）: " input_name
        input_name="${input_name:-}"
        [[ -n "$input_name" ]] || { echo "name 不能为空。"; continue; }
        PROFILE_NAME="$input_name"
        ACTION="print-client"
        return 0
        ;;
      0) return 1 ;;
      *) echo "输入无效，请输入 0 到 2。" ;;
    esac
  done
}

choose_action_from_script_menu() {
  local choice
  while true; do
    print_menu_header "脚本管理" "script-update=available"
    echo "  1) 更新本脚本"
    echo "  0) 返回上一级"
    read -r -p "请输入 0-1: " choice
    case "$choice" in
      1) ACTION="script-update"; return 0 ;;
      0) return 1 ;;
      *) echo "输入无效，请输入 0 或 1。" ;;
    esac
  done
}

resolve_action_choice() {
  local default_snell_action main_choice
  local snell_state profile_state bbr_state docker_state stls_state
  local bbr_cc docker_brief stls_brief

  if [[ -z "$ACTION" && "$PRINT_CLIENT" == "true" ]]; then
    ACTION="print-client"
    return 0
  fi

  if [[ -n "$ACTION" ]]; then
    case "$ACTION" in
      install|update|uninstall|config|restart|status|script-update|profile-add|profile-list|profile-remove|bbr-enable|bbr-disable|bbr-status|docker-deploy|docker-remove|docker-status|stls-deploy|stls-remove|stls-status|print-client) return 0 ;;
      *) die "--action 不支持。可选: install/update/uninstall/config/restart/status/script-update/profile-add/profile-list/profile-remove/bbr-enable/bbr-disable/bbr-status/docker-deploy/docker-remove/docker-status/stls-deploy/stls-remove/stls-status/print-client" ;;
    esac
  fi

  if is_snell_installed; then
    default_snell_action="update"
  else
    default_snell_action="install"
  fi

  if [[ -t 0 ]]; then
    while true; do
      snell_state="$(unit_state 'snell.service')/v$(get_installed_major)"
      profile_state="$(count_profiles)/$(count_active_profile_services)"
      bbr_cc="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo unknown)"
      bbr_state="${bbr_cc}"
      docker_brief="$(get_docker_runtime_summary)"
      docker_state="${docker_brief#container=}"
      docker_state="${docker_state#docker=}"
      stls_brief="$(get_stls_runtime_summary)"
      stls_state="${stls_brief#service=}"
      stls_state="${stls_state%%,*}"
      print_menu_header "Snell 管理主菜单" "$snell_state"
      echo "类目状态: S[${snell_state}] P[${profile_state}] B[${bbr_state}] D[${docker_state}] T[${stls_state}]"
      echo
      echo "请选择类目："
      echo "  1) Snell 主服务"
      echo "  2) 多用户 Profile"
      echo "  3) BBR"
      echo "  4) Docker"
      echo "  5) ShadowTLS"
      echo "  6) 客户端配置"
      echo "  7) 脚本管理"
      echo "  0) 退出"
      read -r -p "请输入 0-7（默认 1）: " main_choice
      main_choice="${main_choice:-1}"
      case "$main_choice" in
        1) if choose_action_from_snell_menu "$default_snell_action"; then return 0; fi ;;
        2) if choose_action_from_profile_menu; then return 0; fi ;;
        3) if choose_action_from_bbr_menu; then return 0; fi ;;
        4) if choose_action_from_docker_menu; then return 0; fi ;;
        5) if choose_action_from_stls_menu; then return 0; fi ;;
        6) if choose_action_from_client_menu; then return 0; fi ;;
        7) if choose_action_from_script_menu; then return 0; fi ;;
        0) die "已取消操作" ;;
        *) echo "输入无效，请输入 0 到 7。" ;;
      esac
    done
  else
    if [[ "$default_snell_action" == "update" ]]; then
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
  if [[ "$ACTION" != "install" && "$ACTION" != "profile-add" && "$ACTION" != "docker-deploy" ]]; then
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

generate_random_secret() {
  local length="${1:-24}"
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c "$length"
  else
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$length"
  fi
}

detect_shadowtls_asset() {
  local machine
  machine="$(uname -m)"
  case "$machine" in
    x86_64|amd64) echo "shadow-tls-x86_64-unknown-linux-musl" ;;
    aarch64|arm64) echo "shadow-tls-aarch64-unknown-linux-musl" ;;
    armv7l|armv7) echo "shadow-tls-armv7-unknown-linux-musleabihf" ;;
    armv6l|arm) echo "shadow-tls-arm-unknown-linux-musleabi" ;;
    *) die "ShadowTLS 暂不支持当前架构: $machine" ;;
  esac
}

resolve_stls_upstream() {
  local choices_upstream choices_psk choices_major choices_label
  local idx conf listen port psk major name version_path choice_index
  choices_upstream=()
  choices_psk=()
  choices_major=()
  choices_label=()

  if [[ -f "$CONFIG_PATH" ]]; then
    listen="$(config_get_value_from_file "$CONFIG_PATH" "listen")"
    psk="$(config_get_value_from_file "$CONFIG_PATH" "psk")"
    port="${listen##*:}"
    if [[ -n "$port" && "$port" != "$listen" ]]; then
      choices_upstream+=("127.0.0.1:${port}")
      choices_psk+=("$psk")
      choices_major+=("$(get_installed_major)")
      choices_label+=("main(snell.service)")
    fi
  fi

  if [[ -d "$PROFILES_DIR" ]]; then
    for conf in "$PROFILES_DIR"/*.conf; do
      [[ -e "$conf" ]] || continue
      name="$(basename "$conf" .conf)"
      listen="$(config_get_value_from_file "$conf" "listen")"
      psk="$(config_get_value_from_file "$conf" "psk")"
      port="${listen##*:}"
      version_path="$(profile_version_path "$name")"
      major="unknown"
      if [[ -f "$version_path" ]]; then
        case "$(tr -d '[:space:]' < "$version_path")" in
          4.*|4) major="4" ;;
          5.*|5) major="5" ;;
          *) major="unknown" ;;
        esac
      fi
      if [[ -n "$port" && "$port" != "$listen" ]]; then
        choices_upstream+=("127.0.0.1:${port}")
        choices_psk+=("$psk")
        choices_major+=("$major")
        choices_label+=("profile:${name}")
      fi
    done
  fi

  if [[ -n "$STLS_UPSTREAM" ]]; then
    for idx in "${!choices_upstream[@]}"; do
      if [[ "${choices_upstream[$idx]}" == "$STLS_UPSTREAM" ]]; then
        STLS_BACKEND_PSK="${choices_psk[$idx]}"
        STLS_BACKEND_MAJOR="${choices_major[$idx]}"
        STLS_BACKEND_LABEL="${choices_label[$idx]}"
        return 0
      fi
    done
    STLS_BACKEND_LABEL="manual"
    STLS_BACKEND_PSK=""
    STLS_BACKEND_MAJOR="unknown"
    return 0
  fi

  if [[ "${#choices_upstream[@]}" -eq 0 ]]; then
    die "未找到可用 Snell 上游。请先安装 Snell 或创建 Profile。"
  fi

  choice_index=0
  if [[ "${#choices_upstream[@]}" -gt 1 && -t 0 ]]; then
    echo "请选择 ShadowTLS 上游:"
    idx=1
    while [[ $idx -le ${#choices_upstream[@]} ]]; do
      echo "  ${idx}) ${choices_label[$((idx-1))]} -> ${choices_upstream[$((idx-1))]}"
      idx=$((idx+1))
    done
    read -r -p "输入序号（默认 1）: " choice_index
    choice_index="${choice_index:-1}"
    [[ "$choice_index" =~ ^[0-9]+$ ]] || die "无效选择"
    (( choice_index >= 1 && choice_index <= ${#choices_upstream[@]} )) || die "无效选择"
    choice_index=$((choice_index-1))
  fi

  STLS_UPSTREAM="${choices_upstream[$choice_index]}"
  STLS_BACKEND_PSK="${choices_psk[$choice_index]}"
  STLS_BACKEND_MAJOR="${choices_major[$choice_index]}"
  STLS_BACKEND_LABEL="${choices_label[$choice_index]}"
}

resolve_stls_options() {
  local upstream_port
  if [[ -z "$STLS_PASSWORD" ]]; then
    STLS_PASSWORD="$(generate_random_secret 20)"
  fi

  if [[ -t 0 ]]; then
    local input_port input_sni input_version
    read -r -p "ShadowTLS 监听端口（默认 ${STLS_PORT}）: " input_port
    if [[ -n "${input_port:-}" ]]; then
      STLS_PORT="$input_port"
    fi
    read -r -p "ShadowTLS SNI（默认 ${STLS_SNI}）: " input_sni
    if [[ -n "${input_sni:-}" ]]; then
      STLS_SNI="$input_sni"
    fi
    read -r -p "ShadowTLS 版本 2/3（默认 ${STLS_VERSION}）: " input_version
    if [[ -n "${input_version:-}" ]]; then
      STLS_VERSION="$input_version"
    fi
  fi

  [[ "$STLS_PORT" =~ ^[0-9]+$ ]] || die "--stls-port 必须为数字"
  (( STLS_PORT >= 1 && STLS_PORT <= 65535 )) || die "--stls-port 必须在 1-65535 之间"
  [[ "$STLS_VERSION" == "2" || "$STLS_VERSION" == "3" ]] || die "--stls-version 仅支持 2 或 3"
  [[ -n "$STLS_PASSWORD" ]] || die "--stls-password 不能为空"
  [[ "$STLS_PASSWORD" != *" "* ]] || die "--stls-password 不能包含空格"
  [[ "$STLS_UPSTREAM" == *:* || -z "$STLS_UPSTREAM" ]] || die "--stls-upstream 必须是 host:port"
  [[ "$STLS_SNI" != *" "* ]] || die "--stls-sni 不能包含空格"

  resolve_stls_upstream
  [[ "$STLS_UPSTREAM" == *:* ]] || die "无法确定 ShadowTLS 上游地址"
  upstream_port="${STLS_UPSTREAM##*:}"
  [[ "$upstream_port" =~ ^[0-9]+$ ]] || die "ShadowTLS 上游端口无效: ${STLS_UPSTREAM}"
  case "${STLS_UPSTREAM%:*}" in
    127.0.0.1|0.0.0.0|localhost|::1)
      if [[ "${STLS_UPSTREAM##*:}" == "$STLS_PORT" ]]; then
        die "本地上游端口不能与 ShadowTLS 监听端口相同: ${STLS_PORT}"
      fi
      ;;
    *)
      ;;
  esac
}

config_get_value() {
  local key="$1"
  config_get_value_from_file "$CONFIG_PATH" "$key"
}

config_get_value_from_file() {
  local file="$1"
  local key="$2"
  if [[ ! -f "$file" ]]; then
    return 0
  fi
  sed -n "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*//p" "$file" | head -n 1
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

major_from_version_text() {
  local ver="$1"
  case "$ver" in
    4.*|4) echo "4" ;;
    5.*|5) echo "5" ;;
    *) echo "unknown" ;;
  esac
}

get_profile_major() {
  local name="$1"
  local version_path ver
  version_path="$(profile_version_path "$name")"
  if [[ -f "$version_path" ]]; then
    ver="$(tr -d '[:space:]' < "$version_path")"
    major_from_version_text "$ver"
    return 0
  fi
  echo "unknown"
}

is_local_host() {
  local host="$1"
  case "$host" in
    127.0.0.1|localhost|0.0.0.0|::1) return 0 ;;
    *) return 1 ;;
  esac
}

resolve_stls_backend_by_upstream() {
  local upstream="$1"
  local host port listen main_port conf name conf_port psk

  STLS_BACKEND_PSK=""
  STLS_BACKEND_MAJOR="unknown"
  STLS_BACKEND_LABEL="manual"

  [[ "$upstream" == *:* ]] || return 0
  host="${upstream%:*}"
  port="${upstream##*:}"
  [[ "$port" =~ ^[0-9]+$ ]] || return 0
  is_local_host "$host" || return 0

  if [[ -f "$CONFIG_PATH" ]]; then
    listen="$(config_get_value_from_file "$CONFIG_PATH" "listen")"
    main_port="${listen##*:}"
    if [[ "$main_port" == "$port" ]]; then
      psk="$(config_get_value_from_file "$CONFIG_PATH" "psk")"
      STLS_BACKEND_PSK="$psk"
      STLS_BACKEND_MAJOR="$(get_installed_major)"
      STLS_BACKEND_LABEL="main(snell.service)"
      return 0
    fi
  fi

  if [[ -d "$PROFILES_DIR" ]]; then
    for conf in "$PROFILES_DIR"/*.conf; do
      [[ -e "$conf" ]] || continue
      name="$(basename "$conf" .conf)"
      listen="$(config_get_value_from_file "$conf" "listen")"
      conf_port="${listen##*:}"
      if [[ "$conf_port" == "$port" ]]; then
        psk="$(config_get_value_from_file "$conf" "psk")"
        STLS_BACKEND_PSK="$psk"
        STLS_BACKEND_MAJOR="$(get_profile_major "$name")"
        STLS_BACKEND_LABEL="profile:${name}"
        return 0
      fi
    done
  fi
}

profile_name_valid() {
  local name="$1"
  [[ "$name" =~ ^[A-Za-z0-9_-]+$ ]]
}

resolve_profile_name() {
  if [[ -n "$PROFILE_NAME" ]]; then
    profile_name_valid "$PROFILE_NAME" || die "Profile 名称仅支持字母/数字/_/-"
    return 0
  fi

  if [[ -t 0 ]]; then
    local input_name
    read -r -p "请输入 Profile 名称（字母/数字/_/-）: " input_name
    PROFILE_NAME="${input_name:-}"
    [[ -n "$PROFILE_NAME" ]] || die "Profile 名称不能为空"
    profile_name_valid "$PROFILE_NAME" || die "Profile 名称仅支持字母/数字/_/-"
    return 0
  fi

  die "请通过 --name 指定 Profile 名称"
}

profile_conf_path() {
  local name="$1"
  echo "${PROFILES_DIR}/${name}.conf"
}

profile_version_path() {
  local name="$1"
  echo "${PROFILE_VERSION_DIR}/${name}.version"
}

ensure_profile_template_service() {
  cat > "$PROFILE_TEMPLATE_SERVICE_PATH" <<EOF
[Unit]
Description=Snell Profile Service (%i)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${BIN_PATH} -c ${PROFILES_DIR}/%i.conf
Restart=on-failure
RestartSec=3
LimitNOFILE=512000

[Install]
WantedBy=multi-user.target
EOF
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

write_config_file() {
  local target_path="$1"
  local cfg_dir
  cfg_dir="$(dirname "$target_path")"
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
  } > "$target_path"

  chmod 600 "$target_path"
}

write_config() {
  write_config_file "$CONFIG_PATH"
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

try_configure_firewall_port() {
  local fw_port="$1"
  if [[ "$SKIP_FIREWALL" == "true" ]]; then
    log "已跳过防火墙步骤"
    return 0
  fi

  if command -v ufw >/dev/null 2>&1; then
    ufw allow "${fw_port}/tcp" || true
    ufw allow "${fw_port}/udp" || true
    log "已尝试通过 ufw 放行 ${fw_port}/tcp 和 ${fw_port}/udp"
  elif command -v firewall-cmd >/dev/null 2>&1; then
    firewall-cmd --permanent --add-port="${fw_port}/tcp" || true
    firewall-cmd --permanent --add-port="${fw_port}/udp" || true
    firewall-cmd --reload || true
    log "已尝试通过 firewalld 放行 ${fw_port}/tcp 和 ${fw_port}/udp"
  else
    log "未检测到 ufw/firewalld，请自行放行端口 ${fw_port}（TCP/UDP）"
  fi
}

try_configure_firewall() {
  try_configure_firewall_port "$PORT"
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

print_direct_node_example() {
  local node_name="$1"
  local pub_ip="$2"
  local port="$3"
  local psk="$4"
  local major="$5"

  if [[ "$major" == "5" ]]; then
    echo "  ${node_name} = snell, ${pub_ip}, ${port}, psk=${psk}, version=5, reuse=true, tfo=true"
  elif [[ "$major" == "4" ]]; then
    echo "  ${node_name} = snell, ${pub_ip}, ${port}, psk=${psk}, version=4, reuse=true, tfo=true"
  else
    echo "  ${node_name}-snellv4 = snell, ${pub_ip}, ${port}, psk=${psk}, version=4, reuse=true, tfo=true"
    echo "  ${node_name}-snellv5 = snell, ${pub_ip}, ${port}, psk=${psk}, version=5, reuse=true, tfo=true"
  fi
}

run_print_client_flow() {
  local pub_ip region_tag found_any listen psk port major
  local conf name node_name stls_listen stls_port stls_upstream stls_password stls_sni stls_version
  found_any="false"

  pub_ip="$(get_public_ip)"
  if [[ -z "$pub_ip" ]]; then
    pub_ip="<你的服务器IP>"
  fi
  region_tag="$(get_ip_region_tag "$pub_ip")"

  echo
  echo "========================================"
  echo "客户端配置输出（Surge）"
  echo "========================================"
  echo "服务器 IP: ${pub_ip}"
  echo "节点前缀: ${region_tag}"

  if [[ -f "$CONFIG_PATH" ]] && { [[ -z "$PROFILE_NAME" ]] || [[ "$PROFILE_NAME" == "main" ]]; }; then
    listen="$(config_get_value_from_file "$CONFIG_PATH" "listen")"
    psk="$(config_get_value_from_file "$CONFIG_PATH" "psk")"
    port="${listen##*:}"
    major="$(get_installed_major)"
    if [[ -n "$port" && "$port" != "$listen" && -n "$psk" ]]; then
      found_any="true"
      echo
      echo "[Main] snell.service"
      if [[ "$major" == "4" || "$major" == "5" ]]; then
        node_name="${region_tag}-snellv${major}"
      else
        node_name="${region_tag}"
      fi
      print_direct_node_example "$node_name" "$pub_ip" "$port" "$psk" "$major"
    fi
  fi

  if [[ -d "$PROFILES_DIR" ]]; then
    for conf in "$PROFILES_DIR"/*.conf; do
      [[ -e "$conf" ]] || continue
      name="$(basename "$conf" .conf)"
      if [[ -n "$PROFILE_NAME" && "$PROFILE_NAME" != "$name" ]]; then
        continue
      fi
      listen="$(config_get_value_from_file "$conf" "listen")"
      psk="$(config_get_value_from_file "$conf" "psk")"
      port="${listen##*:}"
      major="$(get_profile_major "$name")"
      if [[ -n "$port" && "$port" != "$listen" && -n "$psk" ]]; then
        found_any="true"
        if [[ "$major" == "4" || "$major" == "5" ]]; then
          node_name="${region_tag}-${name}-snellv${major}"
        else
          node_name="${region_tag}-${name}"
        fi
        echo
        echo "[Profile] ${name}"
        print_direct_node_example "$node_name" "$pub_ip" "$port" "$psk" "$major"
      fi
    done
  fi

  if [[ -f "$STLS_ENV_PATH" ]]; then
    stls_listen="$(sed -n 's/^STLS_LISTEN=//p' "$STLS_ENV_PATH" | head -n 1)"
    stls_upstream="$(sed -n 's/^STLS_UPSTREAM=//p' "$STLS_ENV_PATH" | head -n 1)"
    stls_password="$(sed -n 's/^STLS_PASSWORD=//p' "$STLS_ENV_PATH" | head -n 1)"
    stls_sni="$(sed -n 's/^STLS_SNI=//p' "$STLS_ENV_PATH" | head -n 1)"
    stls_version="$(sed -n 's/^STLS_VERSION=//p' "$STLS_ENV_PATH" | head -n 1)"
    stls_port="${stls_listen##*:}"

    if [[ -n "$stls_port" && "$stls_port" != "$stls_listen" ]]; then
      resolve_stls_backend_by_upstream "$stls_upstream"
      found_any="true"
      echo
      echo "[ShadowTLS] shadowtls.service"
      echo "  upstream: ${stls_upstream:-unknown} (${STLS_BACKEND_LABEL})"
      STLS_PASSWORD="${stls_password:-<stls-password>}"
      STLS_SNI="${stls_sni:-gateway.icloud.com}"
      STLS_VERSION="${stls_version:-3}"
      print_stls_node_example "$pub_ip" "$region_tag" "$stls_port" "$STLS_BACKEND_PSK" "$STLS_BACKEND_MAJOR"
    fi
  fi

  if [[ "$found_any" != "true" ]]; then
    if [[ -n "$PROFILE_NAME" ]]; then
      die "未找到可用配置（name=${PROFILE_NAME}）"
    fi
    die "未找到可用配置，请先安装 Snell 或创建 Profile"
  fi

  cat <<EOF

常用命令:
  bash install_snell.sh --print-client
  bash install_snell.sh --print-client --name main
  bash install_snell.sh --print-client --name <profile_name>
EOF
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

run_profile_add_flow() {
  local conf_path version_path pub_ip region_tag node_name

  validate_args
  resolve_profile_name
  command -v systemctl >/dev/null 2>&1 || die "profile-add 需要 systemd/systemctl"
  conf_path="$(profile_conf_path "$PROFILE_NAME")"
  version_path="$(profile_version_path "$PROFILE_NAME")"

  [[ ! -f "$conf_path" ]] || die "Profile 已存在: ${PROFILE_NAME}"

  log "创建 Profile: ${PROFILE_NAME}"
  install_deps
  generate_psk
  download_and_install_binary

  write_config_file "$conf_path"
  mkdir -p "$PROFILE_VERSION_DIR"
  printf '%s\n' "$VERSION" > "$version_path"
  chmod 600 "$version_path" || true

  ensure_profile_template_service
  systemctl daemon-reload
  systemctl enable --now "snell@${PROFILE_NAME}.service"

  try_configure_firewall

  pub_ip="$(get_public_ip)"
  if [[ -z "$pub_ip" ]]; then
    pub_ip="<你的服务器IP>"
  fi
  region_tag="$(get_ip_region_tag "$pub_ip")"
  node_name="${region_tag}-${PROFILE_NAME}-snellv${SNELL_MAJOR}"

  cat <<EOF

========================================
Profile 创建完成
========================================
Profile: ${PROFILE_NAME}
版本: v${VERSION}
配置文件: ${conf_path}
端口: ${PORT}
PSK: ${PSK}
服务:
  systemctl status snell@${PROFILE_NAME}.service --no-pager

节点示例:
  ${node_name} = snell, ${pub_ip}, ${PORT}, psk=${PSK}, version=${SNELL_MAJOR}, reuse=true, tfo=true
EOF
}

run_profile_list_flow() {
  local pub_ip region_tag found conf name listen port psk ver major status node_name version_path has_systemctl
  found="false"
  has_systemctl="false"
  if command -v systemctl >/dev/null 2>&1; then
    has_systemctl="true"
  fi
  pub_ip="$(get_public_ip)"
  if [[ -z "$pub_ip" ]]; then
    pub_ip="<你的服务器IP>"
  fi
  region_tag="$(get_ip_region_tag "$pub_ip")"

  echo
  echo "========================================"
  echo "Snell Profiles"
  echo "========================================"

  if [[ ! -d "$PROFILES_DIR" ]]; then
    echo "未找到 Profile 目录: ${PROFILES_DIR}"
    return 0
  fi

  for conf in "$PROFILES_DIR"/*.conf; do
    [[ -e "$conf" ]] || continue
    found="true"
    name="$(basename "$conf" .conf)"
    listen="$(config_get_value_from_file "$conf" "listen")"
    psk="$(config_get_value_from_file "$conf" "psk")"
    port="${listen##*:}"
    ver=""
    version_path="$(profile_version_path "$name")"
    if [[ -f "$version_path" ]]; then
      ver="$(tr -d '[:space:]' < "$version_path")"
    fi
    case "$ver" in
      4.*|4) major="4" ;;
      5.*|5) major="5" ;;
      *) major="unknown" ;;
    esac
    if [[ "$has_systemctl" == "true" ]] && systemctl is-active --quiet "snell@${name}.service"; then
      status="active"
    else
      status="inactive"
    fi
    node_name="${region_tag}-${name}-snellv${major}"

    echo "Profile: ${name}"
    echo "  状态: ${status}"
    echo "  端口: ${port}"
    echo "  版本: ${ver:-unknown}"
    echo "  节点: ${node_name} = snell, ${pub_ip}, ${port}, psk=${psk}, version=${major}, reuse=true, tfo=true"
    echo
  done

  if [[ "$found" != "true" ]]; then
    echo "当前没有 Profile。可用命令:"
    echo "  bash install_snell.sh --action profile-add --name hk-a --major 5 --port 31001"
  fi
}

run_profile_remove_flow() {
  local conf_path version_path has_systemctl
  has_systemctl="false"
  if command -v systemctl >/dev/null 2>&1; then
    has_systemctl="true"
  fi
  resolve_profile_name
  conf_path="$(profile_conf_path "$PROFILE_NAME")"
  version_path="$(profile_version_path "$PROFILE_NAME")"

  if [[ "$has_systemctl" == "true" ]]; then
    if [[ ! -f "$conf_path" ]] && ! systemctl list-unit-files | grep -Eq "^snell@${PROFILE_NAME}\\.service"; then
      die "Profile 不存在: ${PROFILE_NAME}"
    fi
  elif [[ ! -f "$conf_path" ]]; then
    die "Profile 不存在: ${PROFILE_NAME}"
  fi

  if [[ "$has_systemctl" == "true" ]] && systemctl list-unit-files | grep -Eq "^snell@${PROFILE_NAME}\\.service"; then
    systemctl stop "snell@${PROFILE_NAME}.service" || true
    systemctl disable "snell@${PROFILE_NAME}.service" || true
  fi

  rm -f "$conf_path" "$version_path"
  cleanup_empty_parent "$PROFILES_DIR"
  cleanup_empty_parent "$PROFILE_VERSION_DIR"
  if [[ "$has_systemctl" == "true" ]]; then
    systemctl daemon-reload || true
  fi

  log "Profile 已删除: ${PROFILE_NAME}"
}

run_bbr_status_flow() {
  local current_cc available_cc current_qdisc
  current_cc="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo unknown)"
  available_cc="$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null || echo unknown)"
  current_qdisc="$(sysctl -n net.core.default_qdisc 2>/dev/null || echo unknown)"

  cat <<EOF

========================================
BBR 状态
========================================
当前拥塞算法: ${current_cc}
可用拥塞算法: ${available_cc}
当前队列算法: ${current_qdisc}
配置文件: ${BBR_SYSCTL_PATH}
EOF
}

run_bbr_enable_flow() {
  local available_cc
  command -v sysctl >/dev/null 2>&1 || die "未找到 sysctl，无法配置 BBR"

  available_cc="$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null || true)"
  if ! echo "$available_cc" | grep -qw bbr; then
    modprobe tcp_bbr 2>/dev/null || true
    available_cc="$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null || true)"
  fi
  echo "$available_cc" | grep -qw bbr || die "当前内核不支持 BBR"

  cat > "$BBR_SYSCTL_PATH" <<EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

  sysctl -w net.core.default_qdisc=fq >/dev/null || true
  sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null || true
  sysctl --system >/dev/null || true
  log "BBR 已启用"
  run_bbr_status_flow
}

run_bbr_disable_flow() {
  command -v sysctl >/dev/null 2>&1 || die "未找到 sysctl，无法配置拥塞算法"

  rm -f "$BBR_SYSCTL_PATH"
  sysctl -w net.ipv4.tcp_congestion_control=cubic >/dev/null || true
  sysctl -w net.core.default_qdisc=fq_codel >/dev/null || true
  sysctl --system >/dev/null || true
  log "BBR 配置已关闭（已切回 cubic/fq_codel）"
  run_bbr_status_flow
}

docker_require() {
  command -v docker >/dev/null 2>&1 || die "未检测到 docker，请先安装 Docker"
  docker info >/dev/null 2>&1 || die "Docker daemon 不可用，请先启动 Docker"
}

docker_compose_up() {
  if docker compose version >/dev/null 2>&1; then
    docker compose -f "$DOCKER_COMPOSE_PATH" up -d
  elif command -v docker-compose >/dev/null 2>&1; then
    docker-compose -f "$DOCKER_COMPOSE_PATH" up -d
  else
    die "未检测到 docker compose，请安装 Docker Compose"
  fi
}

docker_compose_down() {
  if docker compose version >/dev/null 2>&1; then
    docker compose -f "$DOCKER_COMPOSE_PATH" down
  elif command -v docker-compose >/dev/null 2>&1; then
    docker-compose -f "$DOCKER_COMPOSE_PATH" down
  else
    docker rm -f "$DOCKER_CONTAINER_NAME" >/dev/null 2>&1 || true
  fi
}

run_docker_deploy_flow() {
  local pub_ip region_tag node_name

  validate_args
  install_deps
  generate_psk
  download_and_install_binary

  mkdir -p "$DOCKER_DIR"
  write_config_file "$DOCKER_CONFIG_PATH"
  write_version_marker

  cat > "$DOCKER_COMPOSE_PATH" <<EOF
services:
  snell:
    image: alpine:3.20
    container_name: ${DOCKER_CONTAINER_NAME}
    network_mode: host
    restart: unless-stopped
    command: ["/snell-server", "-c", "/etc/snell/snell-server.conf"]
    volumes:
      - ${BIN_PATH}:/snell-server:ro
      - ${DOCKER_CONFIG_PATH}:/etc/snell/snell-server.conf:ro
EOF

  docker_require

  if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet snell.service; then
    log "检测到原生 snell.service 正在运行，先停止以避免端口冲突"
    systemctl stop snell.service || true
  fi

  docker_compose_up
  try_configure_firewall

  pub_ip="$(get_public_ip)"
  if [[ -z "$pub_ip" ]]; then
    pub_ip="<你的服务器IP>"
  fi
  region_tag="$(get_ip_region_tag "$pub_ip")"
  node_name="${region_tag}-snellv${SNELL_MAJOR}"

  cat <<EOF

========================================
Docker 模式部署完成
========================================
版本: v${VERSION}
容器名: ${DOCKER_CONTAINER_NAME}
Compose 文件: ${DOCKER_COMPOSE_PATH}
配置文件: ${DOCKER_CONFIG_PATH}
端口: ${PORT}
PSK: ${PSK}
节点示例:
  ${node_name} = snell, ${pub_ip}, ${PORT}, psk=${PSK}, version=${SNELL_MAJOR}, reuse=true, tfo=true
EOF
}

run_docker_remove_flow() {
  local answer
  docker_require
  docker_compose_down

  if [[ -t 0 ]]; then
    read -r -p "是否删除 Docker 配置目录 ${DOCKER_DIR} ? [y/N]: " answer
    case "${answer:-N}" in
      y|Y|yes|YES)
        rm -rf "$DOCKER_DIR"
        log "已删除 Docker 配置目录: ${DOCKER_DIR}"
        ;;
      *)
        log "已保留 Docker 配置目录: ${DOCKER_DIR}"
        ;;
    esac
  fi
}

run_docker_status_flow() {
  docker_require
  docker ps -a --filter "name=^/${DOCKER_CONTAINER_NAME}$"
  if [[ -f "$DOCKER_COMPOSE_PATH" ]]; then
    echo
    echo "Compose 文件: ${DOCKER_COMPOSE_PATH}"
    echo "配置文件: ${DOCKER_CONFIG_PATH}"
  fi
}

fetch_shadowtls_release_json() {
  curl -fsSL --retry 3 --retry-delay 2 "$STLS_RELEASE_API"
}

extract_shadowtls_tag() {
  local json="$1"
  printf '%s\n' "$json" | sed -n 's/^[[:space:]]*"tag_name":[[:space:]]*"\(.*\)",$/\1/p' | head -n 1
}

extract_shadowtls_download_url() {
  local json="$1"
  local asset="$2"
  printf '%s\n' "$json" \
    | sed -n 's/^[[:space:]]*"browser_download_url":[[:space:]]*"\(.*\)",$/\1/p' \
    | grep -E "/${asset}$" \
    | head -n 1
}

install_shadowtls_binary() {
  local asset release_json release_tag download_url tmp_bin
  asset="$(detect_shadowtls_asset)"
  release_json="$(fetch_shadowtls_release_json)" || die "获取 ShadowTLS Release 信息失败"
  release_tag="$(extract_shadowtls_tag "$release_json")"
  download_url="$(extract_shadowtls_download_url "$release_json" "$asset")"
  [[ -n "$download_url" ]] || die "未找到匹配当前架构的 ShadowTLS 二进制: ${asset}"

  tmp_bin="/tmp/${asset}.$$"
  log "下载 ShadowTLS ${release_tag:-latest}: ${download_url}"
  curl -fL --retry 3 --retry-delay 2 -o "$tmp_bin" "$download_url"
  install -m 0755 "$tmp_bin" "$STLS_BIN_PATH"
  rm -f "$tmp_bin"
  log "ShadowTLS 二进制已安装: ${STLS_BIN_PATH}"
}

write_stls_env() {
  local env_dir
  env_dir="$(dirname "$STLS_ENV_PATH")"
  mkdir -p "$env_dir"

  cat > "$STLS_ENV_PATH" <<EOF
STLS_VERSION=${STLS_VERSION}
STLS_LISTEN=0.0.0.0:${STLS_PORT}
STLS_PASSWORD=${STLS_PASSWORD}
STLS_SNI=${STLS_SNI}
STLS_UPSTREAM=${STLS_UPSTREAM}
STLS_BACKEND_LABEL=${STLS_BACKEND_LABEL}
STLS_BACKEND_MAJOR=${STLS_BACKEND_MAJOR}
EOF
  chmod 600 "$STLS_ENV_PATH"
}

write_stls_service() {
  cat > "$STLS_SERVICE_PATH" <<EOF
[Unit]
Description=ShadowTLS Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
EnvironmentFile=${STLS_ENV_PATH}
ExecStart=${STLS_BIN_PATH} --v\${STLS_VERSION} server --listen \${STLS_LISTEN} --server \${STLS_UPSTREAM} --tls \${STLS_SNI} --password \${STLS_PASSWORD}
Restart=on-failure
RestartSec=3
LimitNOFILE=512000

[Install]
WantedBy=multi-user.target
EOF
}

print_stls_node_example() {
  local pub_ip="$1"
  local region_tag="$2"
  local port="$3"
  local backend_psk="$4"
  local backend_major="$5"
  local node_v4 node_v5

  node_v4="${region_tag}-snellv4"
  node_v5="${region_tag}-snellv5"

  if [[ -z "$backend_psk" || "$backend_major" == "unknown" ]]; then
    cat <<EOF
未能自动识别上游 Snell 的 PSK/版本，请手动替换:
  ${node_v4} = snell, ${pub_ip}, ${port}, psk=<upstream-psk>, version=4, reuse=true, tfo=true, shadow-tls-password=${STLS_PASSWORD}, shadow-tls-sni=${STLS_SNI}, shadow-tls-version=${STLS_VERSION}
  ${node_v5} = snell, ${pub_ip}, ${port}, psk=<upstream-psk>, version=5, reuse=true, tfo=true, shadow-tls-password=${STLS_PASSWORD}, shadow-tls-sni=${STLS_SNI}, shadow-tls-version=${STLS_VERSION}
EOF
    return 0
  fi

  if [[ "$backend_major" == "5" ]]; then
    cat <<EOF
${node_v5} = snell, ${pub_ip}, ${port}, psk=${backend_psk}, version=5, reuse=true, tfo=true, shadow-tls-password=${STLS_PASSWORD}, shadow-tls-sni=${STLS_SNI}, shadow-tls-version=${STLS_VERSION}
${node_v4} = snell, ${pub_ip}, ${port}, psk=${backend_psk}, version=4, reuse=true, tfo=true, shadow-tls-password=${STLS_PASSWORD}, shadow-tls-sni=${STLS_SNI}, shadow-tls-version=${STLS_VERSION}
EOF
  else
    cat <<EOF
${node_v4} = snell, ${pub_ip}, ${port}, psk=${backend_psk}, version=4, reuse=true, tfo=true, shadow-tls-password=${STLS_PASSWORD}, shadow-tls-sni=${STLS_SNI}, shadow-tls-version=${STLS_VERSION}
EOF
  fi
}

run_stls_deploy_flow() {
  local pub_ip region_tag current_stls_port
  command -v systemctl >/dev/null 2>&1 || die "stls-deploy 需要 systemd/systemctl"

  current_stls_port=""
  if [[ -f "$STLS_ENV_PATH" ]]; then
    current_stls_port="$(sed -n 's/^STLS_LISTEN=.*:\([0-9][0-9]*\)$/\1/p' "$STLS_ENV_PATH" | head -n 1)"
  fi
  if is_port_in_use "$STLS_PORT"; then
    if ! systemctl is-active --quiet shadowtls.service || [[ "$current_stls_port" != "$STLS_PORT" ]]; then
      die "ShadowTLS 端口已被占用: ${STLS_PORT}"
    fi
  fi

  install_deps
  install_shadowtls_binary
  write_stls_env
  write_stls_service

  systemctl daemon-reload
  systemctl enable shadowtls.service >/dev/null 2>&1 || true
  if systemctl is-active --quiet shadowtls.service; then
    systemctl restart shadowtls.service
  else
    systemctl start shadowtls.service
  fi
  try_configure_firewall_port "$STLS_PORT"

  pub_ip="$(get_public_ip)"
  if [[ -z "$pub_ip" ]]; then
    pub_ip="<你的服务器IP>"
  fi
  region_tag="$(get_ip_region_tag "$pub_ip")"

  cat <<EOF

========================================
ShadowTLS 部署完成
========================================
服务: shadowtls.service
二进制: ${STLS_BIN_PATH}
环境文件: ${STLS_ENV_PATH}
监听端口: ${STLS_PORT}
上游: ${STLS_UPSTREAM} (${STLS_BACKEND_LABEL})
密码: ${STLS_PASSWORD}
SNI: ${STLS_SNI}
版本: v${STLS_VERSION}

状态查看:
  systemctl status shadowtls.service --no-pager
  journalctl -u shadowtls.service -f

Surge 节点示例（Snell + ShadowTLS）:
$(print_stls_node_example "$pub_ip" "$region_tag" "$STLS_PORT" "$STLS_BACKEND_PSK" "$STLS_BACKEND_MAJOR")
EOF
}

run_stls_status_flow() {
  if command -v systemctl >/dev/null 2>&1; then
    systemctl status shadowtls.service --no-pager || true
  else
    log "未检测到 systemctl"
  fi

  if [[ -f "$STLS_ENV_PATH" ]]; then
    # shellcheck disable=SC1090
    source "$STLS_ENV_PATH"
    cat <<EOF

========================================
ShadowTLS 配置
========================================
监听: ${STLS_LISTEN:-unknown}
上游: ${STLS_UPSTREAM:-unknown}
SNI: ${STLS_SNI:-unknown}
版本: ${STLS_VERSION:-unknown}
EOF
  else
    log "未找到 ShadowTLS 环境文件: ${STLS_ENV_PATH}"
  fi
}

run_stls_remove_flow() {
  local remove_bin_answer
  if command -v systemctl >/dev/null 2>&1; then
    if systemctl list-unit-files | grep -Eq '^shadowtls\.service'; then
      systemctl stop shadowtls.service || true
      systemctl disable shadowtls.service || true
    fi
  fi

  rm -f "$STLS_SERVICE_PATH"
  rm -f "$STLS_ENV_PATH"

  if [[ -f "$STLS_BIN_PATH" ]]; then
    if [[ -t 0 ]]; then
      read -r -p "是否删除 ShadowTLS 二进制 ${STLS_BIN_PATH} ? [y/N]: " remove_bin_answer
      case "${remove_bin_answer:-N}" in
        y|Y|yes|YES) rm -f "$STLS_BIN_PATH" ;;
        *) ;;
      esac
    else
      rm -f "$STLS_BIN_PATH"
    fi
  fi

  if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload || true
  fi
  log "ShadowTLS 已移除"
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
  if [[ -f "$PROFILE_TEMPLATE_SERVICE_PATH" ]]; then
    rm -f "$PROFILE_TEMPLATE_SERVICE_PATH"
    log "已删除 Profile 模板服务: $PROFILE_TEMPLATE_SERVICE_PATH"
  fi
  if command -v systemctl >/dev/null 2>&1; then
    while IFS= read -r unit_name; do
      unit_name="${unit_name##* }"
      [[ -n "$unit_name" ]] || continue
      systemctl stop "$unit_name" || true
      systemctl disable "$unit_name" || true
    done < <(systemctl list-unit-files --type=service | awk '/^snell@.*\.service/{print $1}')
  fi
  if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload || true
  fi

  if [[ -f "$CONFIG_PATH" ]]; then
    rm -f "$CONFIG_PATH"
    log "已删除配置文件: $CONFIG_PATH"
  fi
  cleanup_empty_parent "$cfg_dir"
  rm -rf "$PROFILES_DIR" "$PROFILE_VERSION_DIR"
  rm -f "$VERSION_MARK_PATH"
  rm -f "$BBR_SYSCTL_PATH"
  rm -rf "$DOCKER_DIR"
  if command -v systemctl >/dev/null 2>&1; then
    if systemctl list-unit-files | grep -Eq '^shadowtls\.service'; then
      systemctl stop shadowtls.service || true
      systemctl disable shadowtls.service || true
    fi
  fi
  rm -f "$STLS_SERVICE_PATH" "$STLS_ENV_PATH"
  rm -f "$STLS_BIN_PATH"

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

  if [[ "$ACTION" == "install" || "$ACTION" == "update" || "$ACTION" == "profile-add" || "$ACTION" == "docker-deploy" ]]; then
    resolve_version_choice
  fi
  if [[ "$ACTION" == "install" || "$ACTION" == "profile-add" || "$ACTION" == "docker-deploy" ]]; then
    resolve_install_port
  fi
  if [[ "$ACTION" == "stls-deploy" ]]; then
    resolve_stls_options
  fi

  case "$ACTION" in
    install) run_install_flow ;;
    update) run_update_flow ;;
    uninstall) run_uninstall_flow ;;
    config) run_config_flow ;;
    restart) run_restart_flow ;;
    status) run_status_flow ;;
    script-update) run_script_update_flow ;;
    profile-add) run_profile_add_flow ;;
    profile-list) run_profile_list_flow ;;
    profile-remove) run_profile_remove_flow ;;
    bbr-enable) run_bbr_enable_flow ;;
    bbr-disable) run_bbr_disable_flow ;;
    bbr-status) run_bbr_status_flow ;;
    docker-deploy) run_docker_deploy_flow ;;
    docker-remove) run_docker_remove_flow ;;
    docker-status) run_docker_status_flow ;;
    stls-deploy) run_stls_deploy_flow ;;
    stls-remove) run_stls_remove_flow ;;
    stls-status) run_stls_status_flow ;;
    print-client) run_print_client_flow ;;
    *) die "未知操作: $ACTION" ;;
  esac
}

main "$@"
