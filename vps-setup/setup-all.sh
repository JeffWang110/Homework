#!/bin/bash
#
# VPS Deployment Setup - Master Script
# 用途：一鍵在 VPS 上安裝 Coolify + Claude Code + tmux 部署環境
#
# 使用方式：
#   curl -fsSL <your-repo-raw-url>/vps-setup/setup-all.sh | bash
#   或
#   git clone <your-repo> && cd Homework/vps-setup && bash setup-all.sh
#
# 前置需求：
#   - Ubuntu 22.04+ 或 Debian 12+ VPS
#   - Root 或 sudo 權限
#   - 至少 2GB RAM（Coolify 需要）
#   - 域名已指向 VPS IP（如 agents.jeffwang.work）

set -euo pipefail

# ============================================================
# 顏色輸出
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ============================================================
# 檢查環境
# ============================================================
check_requirements() {
    log_info "檢查系統環境..."

    if [ "$(id -u)" -ne 0 ]; then
        log_error "請使用 root 或 sudo 執行此腳本"
        exit 1
    fi

    # 檢查 OS
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        log_info "作業系統: $PRETTY_NAME"
    fi

    # 檢查記憶體
    TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$TOTAL_MEM" -lt 1800 ]; then
        log_warn "記憶體只有 ${TOTAL_MEM}MB，建議至少 2GB"
        read -rp "是否繼續？(y/N) " confirm
        [ "$confirm" != "y" ] && exit 1
    fi

    log_ok "環境檢查通過"
}

# ============================================================
# 安裝基礎套件
# ============================================================
install_base_packages() {
    log_info "安裝基礎套件..."
    apt-get update -qq
    apt-get install -y -qq \
        curl \
        wget \
        git \
        tmux \
        htop \
        ufw \
        fail2ban \
        unzip \
        jq \
        ca-certificates \
        gnupg \
        lsb-release
    log_ok "基礎套件安裝完成"
}

# ============================================================
# 設定防火牆
# ============================================================
setup_firewall() {
    log_info "設定防火牆 (UFW)..."
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 22/tcp    # SSH
    ufw allow 80/tcp    # HTTP
    ufw allow 443/tcp   # HTTPS
    ufw allow 8000/tcp  # Coolify UI
    ufw --force enable
    log_ok "防火牆設定完成"
}

# ============================================================
# 安裝 Docker（如果還沒裝）
# ============================================================
install_docker() {
    if command -v docker &>/dev/null; then
        log_ok "Docker 已安裝: $(docker --version)"
        return
    fi

    log_info "安裝 Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable --now docker
    log_ok "Docker 安裝完成: $(docker --version)"
}

# ============================================================
# 主選單
# ============================================================
show_menu() {
    echo ""
    echo "=========================================="
    echo "  VPS Deployment Setup"
    echo "  Jeff's AI Agent Infrastructure"
    echo "=========================================="
    echo ""
    echo "  1) 完整安裝（Coolify + Claude Code + tmux）"
    echo "  2) 只裝 Coolify"
    echo "  3) 只裝 Claude Code"
    echo "  4) 只設定 tmux + SSH"
    echo "  5) 只設定防火牆"
    echo "  0) 離開"
    echo ""
    read -rp "請選擇 [0-5]: " choice
}

# ============================================================
# 執行子腳本
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run_coolify_install() {
    bash "$SCRIPT_DIR/01-install-coolify.sh"
}

run_claude_code_install() {
    bash "$SCRIPT_DIR/02-install-claude-code.sh"
}

run_tmux_ssh_setup() {
    bash "$SCRIPT_DIR/03-setup-tmux-ssh.sh"
}

# ============================================================
# 主流程
# ============================================================
main() {
    check_requirements

    show_menu

    case "$choice" in
        1)
            install_base_packages
            setup_firewall
            install_docker
            run_coolify_install
            run_claude_code_install
            run_tmux_ssh_setup
            ;;
        2)
            install_base_packages
            install_docker
            run_coolify_install
            ;;
        3)
            install_base_packages
            run_claude_code_install
            ;;
        4)
            run_tmux_ssh_setup
            ;;
        5)
            setup_firewall
            ;;
        0)
            log_info "離開"
            exit 0
            ;;
        *)
            log_error "無效選項"
            exit 1
            ;;
    esac

    echo ""
    log_ok "=========================================="
    log_ok "  設定完成！"
    log_ok "=========================================="
    echo ""
    log_info "下一步："
    log_info "  1. 開啟 Coolify: http://your-vps-ip:8000"
    log_info "  2. 啟動 Claude Code: tmux new -s claude && claude"
    log_info "  3. 綁定 GitHub repo 到 Coolify 開始自動部署"
    echo ""
}

main "$@"
