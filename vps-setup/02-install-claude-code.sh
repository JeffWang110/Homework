#!/bin/bash
#
# Step 2: 安裝 Claude Code 到 VPS
# 讓你可以 SSH 進 VPS 後用自然語言管理伺服器
#
# 用途：
#   - 用自然語言查 log、除錯、改設定
#   - 直接叫 Claude 幫你部署新容器
#   - 管理 Docker、Nginx、系統設定
#   - 搭配 tmux 保持 session 不斷線

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[CLAUDE]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[CLAUDE]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[CLAUDE]${NC} $1"; }
log_error() { echo -e "${RED}[CLAUDE]${NC} $1"; }

# ============================================================
# 安裝 Node.js (Claude Code 需要 Node.js 18+)
# ============================================================
install_nodejs() {
    if command -v node &>/dev/null; then
        NODE_VER=$(node -v)
        log_ok "Node.js 已安裝: $NODE_VER"

        # 檢查版本是否 >= 18
        NODE_MAJOR=$(echo "$NODE_VER" | cut -d'.' -f1 | tr -d 'v')
        if [ "$NODE_MAJOR" -lt 18 ]; then
            log_warn "Node.js 版本過低，需要 18+，正在升級..."
        else
            return 0
        fi
    fi

    log_info "安裝 Node.js 20 LTS..."

    # 使用 NodeSource 安裝
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y -qq nodejs

    log_ok "Node.js 安裝完成: $(node -v)"
}

# ============================================================
# 安裝 Claude Code
# ============================================================
install_claude_code() {
    log_info "安裝 Claude Code..."

    npm install -g @anthropic-ai/claude-code

    log_ok "Claude Code 安裝完成！"
}

# ============================================================
# 設定 API Key
# ============================================================
setup_api_key() {
    echo ""
    log_info "設定 Anthropic API Key"
    echo ""

    # 檢查是否已設定
    if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
        log_ok "ANTHROPIC_API_KEY 已設定"
        return 0
    fi

    echo "你需要一個 Anthropic API key 才能使用 Claude Code"
    echo "取得方式: https://console.anthropic.com/settings/keys"
    echo ""
    read -rp "請輸入你的 ANTHROPIC_API_KEY（或按 Enter 稍後設定）: " api_key

    if [ -n "$api_key" ]; then
        # 寫入 bashrc
        echo "" >> ~/.bashrc
        echo "# Claude Code API Key" >> ~/.bashrc
        echo "export ANTHROPIC_API_KEY=\"$api_key\"" >> ~/.bashrc

        export ANTHROPIC_API_KEY="$api_key"
        log_ok "API Key 已儲存到 ~/.bashrc"
    else
        log_warn "稍後請手動設定："
        echo "  echo 'export ANTHROPIC_API_KEY=\"your-key\"' >> ~/.bashrc"
        echo "  source ~/.bashrc"
    fi
}

# ============================================================
# 建立 Claude Code 便捷指令
# ============================================================
create_aliases() {
    log_info "建立便捷指令..."

    cat >> ~/.bashrc << 'ALIASES'

# ============================================================
# Claude Code 便捷指令
# ============================================================
# 啟動 Claude Code（在 tmux 中）
alias cc='claude'
alias ccs='tmux new-session -s claude "claude"'
alias cca='tmux attach -t claude 2>/dev/null || tmux new-session -s claude "claude"'

# 常用部署指令
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dlogs='docker logs -f --tail 100'
alias dstop='docker stop'
alias drestart='docker restart'

# 系統監控
alias ports='ss -tlnp'
alias mem='free -h'
alias disk='df -h'
ALIASES

    log_ok "便捷指令已加入 ~/.bashrc"
    echo ""
    echo "  cc      - 啟動 Claude Code"
    echo "  ccs     - 在新 tmux session 中啟動 Claude Code"
    echo "  cca     - 連接到現有 Claude Code session（沒有就建新的）"
    echo "  dps     - 查看 Docker 容器狀態"
    echo "  dlogs   - 查看容器 log"
}

# ============================================================
# 顯示使用指引
# ============================================================
show_usage_guide() {
    echo ""
    log_ok "============================================"
    log_ok "  Claude Code 安裝完成！"
    log_ok "============================================"
    echo ""
    log_info "使用方式："
    echo ""
    echo "  1. 直接啟動："
    echo "     $ claude"
    echo ""
    echo "  2. 在 tmux 中啟動（推薦，斷線不會中斷）："
    echo "     $ tmux new -s claude"
    echo "     $ claude"
    echo ""
    echo "  3. 用便捷指令："
    echo "     $ cca    # 自動連接或建立 Claude session"
    echo ""
    log_info "使用範例："
    echo ""
    echo "  > 幫我查看最近的 Nginx error log"
    echo "  > 用 Docker 部署一個 PostgreSQL 資料庫"
    echo "  > 幫我看 agents.jeffwang.work 為什麼回 502"
    echo "  > 把這個 Python 服務包成 Docker container 部署"
    echo ""
}

# ============================================================
# 主流程
# ============================================================
main() {
    install_nodejs
    install_claude_code
    setup_api_key
    create_aliases
    show_usage_guide
}

main "$@"
