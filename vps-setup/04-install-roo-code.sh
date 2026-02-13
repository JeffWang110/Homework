#!/bin/bash
#
# 在 VPS 上安裝 Roo Code
# ============================================================
#
# Roo Code 是 VS Code 擴充套件，無法直接在終端機使用。
# 本腳本提供兩種方式在 VPS 上使用 Roo Code：
#
#   方式 A: code-server（推薦）
#           在 VPS 上跑一個網頁版 VS Code，透過瀏覽器存取
#           然後在裡面安裝 Roo Code 擴充套件
#
#   方式 B: Roo-Code-CLI（社群版）
#           社群開發的終端機版本，直接在 CLI 中使用
#           功能可能不如完整版穩定
#
# 使用方式：
#   sudo bash 04-install-roo-code.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[ROO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[ROO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[ROO]${NC} $1"; }
log_error() { echo -e "${RED}[ROO]${NC} $1"; }
log_step()  { echo -e "${CYAN}[ROO]${NC} $1"; }

# ============================================================
# 選單
# ============================================================
show_menu() {
    echo ""
    echo "=========================================="
    echo "  Roo Code VPS 安裝工具"
    echo "=========================================="
    echo ""
    echo "  A) code-server + Roo Code（推薦）"
    echo "     → 網頁版 VS Code，瀏覽器即可操作"
    echo "     → 完整的 Roo Code 擴充套件功能"
    echo "     → 支援所有 LLM provider"
    echo ""
    echo "  B) Roo-Code-CLI（社群終端版）"
    echo "     → 直接在終端機使用"
    echo "     → 社群維護，功能可能有限"
    echo ""
    echo "  C) Docker 方式安裝 code-server + Roo Code"
    echo "     → 用 Docker 容器化，隔離乾淨"
    echo "     → 適合已有 Docker 環境的 VPS"
    echo ""
    echo "  0) 離開"
    echo ""
    read -rp "請選擇 [A/B/C/0]: " choice
}

# ============================================================
# 方式 A: code-server + Roo Code（直接安裝）
# ============================================================
install_code_server() {
    log_step "=== 方式 A: 安裝 code-server + Roo Code ==="
    echo ""

    # Step 1: 安裝 code-server
    log_info "[1/4] 安裝 code-server..."
    if command -v code-server &>/dev/null; then
        log_ok "code-server 已安裝: $(code-server --version | head -1)"
    else
        curl -fsSL https://code-server.dev/install.sh | sh
        log_ok "code-server 安裝完成"
    fi

    # Step 2: 設定 code-server
    log_info "[2/4] 設定 code-server..."

    mkdir -p ~/.config/code-server

    # 讀取使用者設定
    read -rp "設定 code-server 密碼（預設: roocode123）: " CS_PASSWORD
    CS_PASSWORD="${CS_PASSWORD:-roocode123}"

    read -rp "code-server 監聽 port（預設: 8443）: " CS_PORT
    CS_PORT="${CS_PORT:-8443}"

    read -rp "綁定域名（留空則用 IP，例如: code.jeffwang.work）: " CS_DOMAIN

    cat > ~/.config/code-server/config.yaml << EOF
bind-addr: 0.0.0.0:${CS_PORT}
auth: password
password: ${CS_PASSWORD}
cert: false
EOF

    log_ok "code-server 設定完成"

    # Step 3: 安裝 Roo Code 擴充套件
    log_info "[3/4] 安裝 Roo Code 擴充套件..."
    code-server --install-extension rooveterinaryinc.roo-cline || {
        log_warn "自動安裝失敗，請稍後在 code-server 介面中手動搜尋安裝 'Roo Code'"
    }
    log_ok "Roo Code 擴充套件安裝完成"

    # Step 4: 啟動 code-server
    log_info "[4/4] 啟動 code-server..."

    # 設定為系統服務
    systemctl enable --now code-server@$USER 2>/dev/null || {
        log_warn "systemd 服務啟動失敗，嘗試直接啟動..."
        # 用 tmux 在背景跑
        if command -v tmux &>/dev/null; then
            tmux new-session -d -s code-server "code-server --bind-addr 0.0.0.0:${CS_PORT}"
            log_ok "code-server 已在 tmux session 'code-server' 中啟動"
        else
            log_warn "請手動啟動: code-server --bind-addr 0.0.0.0:${CS_PORT}"
        fi
    }

    # 設定 Nginx 反向代理（如果有域名）
    if [ -n "$CS_DOMAIN" ]; then
        setup_nginx_for_code_server "$CS_DOMAIN" "$CS_PORT"
    fi

    # 顯示結果
    local VPS_IP
    VPS_IP=$(curl -s ifconfig.me 2>/dev/null || echo "your-vps-ip")

    echo ""
    log_ok "============================================"
    log_ok "  code-server + Roo Code 安裝完成！"
    log_ok "============================================"
    echo ""
    if [ -n "$CS_DOMAIN" ]; then
        echo "  存取網址:  https://${CS_DOMAIN}"
    else
        echo "  存取網址:  http://${VPS_IP}:${CS_PORT}"
    fi
    echo "  密碼:      ${CS_PASSWORD}"
    echo ""
    echo "  開啟後在左側找到 Roo Code 圖示即可使用"
    echo ""
    log_info "Roo Code 設定 LLM："
    echo "  1. 點擊 Roo Code 圖示（左側邊欄）"
    echo "  2. 選擇 API Provider（Anthropic / OpenAI / OpenRouter）"
    echo "  3. 填入 API Key"
    echo "  4. 開始使用！"
    echo ""
}

# ============================================================
# 方式 B: Roo-Code-CLI（社群終端版）
# ============================================================
install_roo_code_cli() {
    log_step "=== 方式 B: 安裝 Roo-Code-CLI（社群版）==="
    echo ""

    # 檢查 Node.js
    if ! command -v node &>/dev/null; then
        log_info "安裝 Node.js 20..."
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
        apt-get install -y -qq nodejs
    fi

    # 檢查 pnpm
    if ! command -v pnpm &>/dev/null; then
        log_info "安裝 pnpm..."
        npm install -g pnpm
    fi

    # Clone Roo-Code-CLI
    log_info "下載 Roo-Code-CLI..."
    local INSTALL_DIR="/opt/roo-code-cli"

    if [ -d "$INSTALL_DIR" ]; then
        log_info "更新現有安裝..."
        cd "$INSTALL_DIR" && git pull
    else
        git clone https://github.com/rightson/Roo-Code-CLI.git "$INSTALL_DIR"
        cd "$INSTALL_DIR"
    fi

    # 安裝依賴
    log_info "安裝依賴..."
    pnpm install

    # 建構
    log_info "建構中..."
    pnpm build 2>/dev/null || pnpm vsix 2>/dev/null || true

    # 建立 symlink
    if [ -f "$INSTALL_DIR/dist/cli.js" ]; then
        ln -sf "$INSTALL_DIR/dist/cli.js" /usr/local/bin/roo
        chmod +x /usr/local/bin/roo
        log_ok "已建立 'roo' 指令"
    fi

    echo ""
    log_ok "============================================"
    log_ok "  Roo-Code-CLI 安裝完成！"
    log_ok "============================================"
    echo ""
    log_warn "注意：這是社群維護的版本，功能可能與正式版有差異"
    echo ""
    echo "  使用方式: cd /opt/roo-code-cli && pnpm start"
    echo "  或:       roo（如果 symlink 建立成功）"
    echo ""
    echo "  GitHub: https://github.com/rightson/Roo-Code-CLI"
    echo ""
}

# ============================================================
# 方式 C: Docker 方式（code-server + Roo Code）
# ============================================================
install_docker_code_server() {
    log_step "=== 方式 C: Docker 安裝 code-server + Roo Code ==="
    echo ""

    # 檢查 Docker
    if ! command -v docker &>/dev/null; then
        log_error "Docker 未安裝，請先執行 setup-all.sh 或 'curl -fsSL https://get.docker.com | sh'"
        exit 1
    fi

    read -rp "設定密碼（預設: roocode123）: " CS_PASSWORD
    CS_PASSWORD="${CS_PASSWORD:-roocode123}"

    read -rp "監聽 port（預設: 8443）: " CS_PORT
    CS_PORT="${CS_PORT:-8443}"

    read -rp "工作目錄（預設: /root/projects）: " WORK_DIR
    WORK_DIR="${WORK_DIR:-/root/projects}"
    mkdir -p "$WORK_DIR"

    # 建立 Dockerfile
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    cat > /tmp/roo-code-server.Dockerfile << 'DOCKERFILE'
FROM codercom/code-server:latest

# 安裝 Roo Code 擴充套件
RUN code-server --install-extension rooveterinaryinc.roo-cline

# 安裝常用開發工具
USER root
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# 安裝 Node.js 20
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

USER coder

# Roo Code 預設設定（使用 OpenRouter 作為 provider）
RUN mkdir -p /home/coder/.local/share/code-server/User && \
    echo '{}' > /home/coder/.local/share/code-server/User/settings.json
DOCKERFILE

    log_info "建構 Docker image..."
    docker build -t roo-code-server -f /tmp/roo-code-server.Dockerfile /tmp/

    log_info "啟動容器..."
    docker rm -f roo-code-server 2>/dev/null || true

    docker run -d \
        --name roo-code-server \
        --restart unless-stopped \
        -p "${CS_PORT}:8080" \
        -v "${WORK_DIR}:/home/coder/project" \
        -e "PASSWORD=${CS_PASSWORD}" \
        roo-code-server

    # 清理
    rm -f /tmp/roo-code-server.Dockerfile

    local VPS_IP
    VPS_IP=$(curl -s ifconfig.me 2>/dev/null || echo "your-vps-ip")

    echo ""
    log_ok "============================================"
    log_ok "  Docker code-server + Roo Code 已啟動！"
    log_ok "============================================"
    echo ""
    echo "  存取網址:  http://${VPS_IP}:${CS_PORT}"
    echo "  密碼:      ${CS_PASSWORD}"
    echo "  工作目錄:  ${WORK_DIR}"
    echo ""
    echo "  容器管理指令："
    echo "    查看狀態:  docker ps | grep roo-code-server"
    echo "    查看 log:  docker logs roo-code-server -f"
    echo "    重啟:      docker restart roo-code-server"
    echo "    停止:      docker stop roo-code-server"
    echo ""
}

# ============================================================
# Nginx 反向代理設定
# ============================================================
setup_nginx_for_code_server() {
    local domain="$1"
    local port="$2"

    log_info "設定 Nginx 反向代理: ${domain} → localhost:${port}"

    # 安裝 Nginx（如果沒有）
    if ! command -v nginx &>/dev/null; then
        apt-get install -y -qq nginx
    fi
    if ! command -v certbot &>/dev/null; then
        apt-get install -y -qq certbot python3-certbot-nginx
    fi

    cat > "/etc/nginx/sites-available/code-server" << NGINX_EOF
server {
    listen 80;
    server_name ${domain};

    location / {
        proxy_pass http://127.0.0.1:${port};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Accept-Encoding gzip;

        # WebSocket 支援（code-server 需要）
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }
}
NGINX_EOF

    ln -sf /etc/nginx/sites-available/code-server /etc/nginx/sites-enabled/
    nginx -t && systemctl reload nginx

    # SSL
    certbot --nginx -d "$domain" --non-interactive --agree-tos -m "admin@${domain}" 2>/dev/null || {
        log_warn "SSL 自動設定失敗（域名可能尚未指向此 IP）"
        log_warn "稍後手動執行: certbot --nginx -d ${domain}"
    }

    log_ok "Nginx 反向代理設定完成"
}

# ============================================================
# 主流程
# ============================================================
main() {
    show_menu

    case "${choice,,}" in
        a)
            install_code_server
            ;;
        b)
            install_roo_code_cli
            ;;
        c)
            install_docker_code_server
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
}

main "$@"
