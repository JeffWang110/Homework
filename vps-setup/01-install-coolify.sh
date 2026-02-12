#!/bin/bash
#
# Step 1: 安裝 Coolify
# Coolify = 自架版 Vercel/Netlify，支援 Git push 自動部署
#
# 功能：
#   - 自動部署（Git push → build → deploy）
#   - 自動 SSL 憑證（Let's Encrypt）
#   - 反向代理（Traefik）
#   - Docker 容器管理
#   - 資料庫一鍵部署（PostgreSQL, Redis, MongoDB...）

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[COOLIFY]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[COOLIFY]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[COOLIFY]${NC} $1"; }
log_error() { echo -e "${RED}[COOLIFY]${NC} $1"; }

# ============================================================
# 檢查 Docker
# ============================================================
if ! command -v docker &>/dev/null; then
    log_error "Docker 未安裝，請先執行 setup-all.sh 或手動安裝 Docker"
    exit 1
fi

# ============================================================
# 安裝 Coolify
# ============================================================
install_coolify() {
    log_info "開始安裝 Coolify..."
    log_info "這會安裝 Coolify v4 (最新穩定版)"

    # Coolify 官方一鍵安裝指令
    curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash

    log_ok "Coolify 安裝完成！"
}

# ============================================================
# 等待 Coolify 啟動
# ============================================================
wait_for_coolify() {
    log_info "等待 Coolify 啟動..."
    local max_attempts=30
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000 | grep -q "200\|302"; then
            log_ok "Coolify 已啟動！"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 5
    done

    log_warn "Coolify 可能還在啟動中，請稍後手動檢查 http://your-ip:8000"
}

# ============================================================
# 顯示設定指引
# ============================================================
show_post_install_guide() {
    local VPS_IP
    VPS_IP=$(curl -s ifconfig.me 2>/dev/null || echo "your-vps-ip")

    echo ""
    log_ok "============================================"
    log_ok "  Coolify 安裝完成！"
    log_ok "============================================"
    echo ""
    log_info "存取 Coolify 控制台："
    log_info "  http://${VPS_IP}:8000"
    echo ""
    log_info "接下來的設定步驟："
    echo ""
    echo "  Step 1: 開啟瀏覽器，進入 http://${VPS_IP}:8000"
    echo "  Step 2: 建立管理員帳號"
    echo "  Step 3: 連接 GitHub"
    echo "          Settings → Git → Add GitHub App"
    echo "          授權後可自動偵測你的 repos"
    echo ""
    echo "  Step 4: 部署第一個專案"
    echo "          Projects → New → 選擇 GitHub repo"
    echo "          Coolify 會自動偵測 Dockerfile 或 docker-compose.yml"
    echo ""
    echo "  Step 5: 設定域名"
    echo "          在專案設定中填入域名（如 agents.jeffwang.work）"
    echo "          Coolify 會自動設定 Traefik 反向代理 + Let's Encrypt SSL"
    echo ""
    echo "  Step 6: 設定自動部署"
    echo "          在 GitHub repo 設定中啟用 Webhook"
    echo "          之後每次 git push 就會自動部署"
    echo ""
    log_info "常用 Coolify 指令："
    echo "  查看狀態:    docker ps | grep coolify"
    echo "  查看 log:    docker logs coolify -f --tail 100"
    echo "  重啟 Coolify: docker restart coolify"
    echo ""
}

# ============================================================
# 主流程
# ============================================================
main() {
    install_coolify
    wait_for_coolify
    show_post_install_guide
}

main "$@"
