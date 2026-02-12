#!/bin/bash
#
# Step 3: 設定 tmux + SSH
# tmux 讓你斷線後 Claude Code session 不會中斷
# SSH key 設定讓你安全連線

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[SETUP]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[SETUP]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[SETUP]${NC} $1"; }

# ============================================================
# 安裝 tmux 配置
# ============================================================
setup_tmux() {
    log_info "設定 tmux..."

    # 安裝 tmux（如果沒有）
    if ! command -v tmux &>/dev/null; then
        apt-get install -y -qq tmux
    fi

    # 複製 tmux 配置
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$SCRIPT_DIR/.tmux.conf" ]; then
        cp "$SCRIPT_DIR/.tmux.conf" ~/.tmux.conf
        log_ok "tmux 配置已安裝"
    else
        # 內建基本配置
        cat > ~/.tmux.conf << 'TMUX_CONF'
# ============================================================
# tmux 配置 - VPS 部署用
# ============================================================

# 使用 Ctrl+a 取代 Ctrl+b（更方便單手操作）
unbind C-b
set -g prefix C-a
bind C-a send-prefix

# 啟用滑鼠支援（方便捲動查看 log）
set -g mouse on

# 256 色支援
set -g default-terminal "screen-256color"

# 增加歷史紀錄
set -g history-limit 50000

# 從 1 開始編號（0 在鍵盤太遠了）
set -g base-index 1
setw -g pane-base-index 1

# 快速切分視窗
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"

# 用 vim 風格切換 pane
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# 快速重載配置
bind r source-file ~/.tmux.conf \; display "Config reloaded!"

# 狀態列
set -g status-style 'bg=#333333 fg=#ffffff'
set -g status-left '#[fg=#000000,bg=#00ff00,bold] #S '
set -g status-right '#[fg=#ffffff] %Y-%m-%d %H:%M '
set -g status-left-length 30

# 自動重新編號視窗
set -g renumber-windows on

# 減少 escape 延遲（vim 使用者需要）
set -sg escape-time 10
TMUX_CONF
        log_ok "tmux 配置已建立"
    fi
}

# ============================================================
# 設定 SSH 安全性
# ============================================================
setup_ssh_security() {
    log_info "強化 SSH 安全性..."

    # 備份原始設定
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

    # 建立安全設定
    cat > /etc/ssh/sshd_config.d/hardened.conf << 'SSH_CONF'
# SSH 安全強化設定
# 由 vps-setup 腳本產生

# 禁用密碼登入（只允許 SSH key）
# 注意：請確保你已經加入 SSH key 再啟用此設定！
# PasswordAuthentication no

# 禁用 root 密碼登入（允許 key 登入）
PermitRootLogin prohibit-password

# 只允許特定使用者（取消註解並填入你的用戶名）
# AllowUsers jeff

# 其他安全設定
MaxAuthTries 5
ClientAliveInterval 300
ClientAliveCountMax 3
X11Forwarding no
SSH_CONF

    log_ok "SSH 安全設定已建立"
    log_warn "注意：密碼登入目前仍然啟用"
    log_warn "請先確認 SSH key 可以登入後，再手動禁用密碼登入"
}

# ============================================================
# 生成/檢查 SSH Key
# ============================================================
setup_ssh_key() {
    log_info "檢查 SSH key..."

    if [ -f ~/.ssh/authorized_keys ] && [ -s ~/.ssh/authorized_keys ]; then
        local key_count
        key_count=$(wc -l < ~/.ssh/authorized_keys)
        log_ok "已有 ${key_count} 個 SSH key 在 authorized_keys 中"
    else
        log_warn "尚未設定 SSH key"
        echo ""
        echo "  請在你的本機執行以下指令來加入 SSH key："
        echo ""
        echo "  # 1. 生成 SSH key（如果還沒有的話）"
        echo "  ssh-keygen -t ed25519 -C \"jeff@vps\""
        echo ""
        echo "  # 2. 複製公鑰到 VPS"
        echo "  ssh-copy-id root@your-vps-ip"
        echo ""
        echo "  # 或手動複製："
        echo "  cat ~/.ssh/id_ed25519.pub | ssh root@your-vps-ip 'cat >> ~/.ssh/authorized_keys'"
        echo ""
    fi
}

# ============================================================
# 設定 fail2ban（防暴力破解）
# ============================================================
setup_fail2ban() {
    log_info "設定 fail2ban..."

    if ! command -v fail2ban-client &>/dev/null; then
        apt-get install -y -qq fail2ban
    fi

    cat > /etc/fail2ban/jail.local << 'F2B_CONF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
F2B_CONF

    systemctl enable --now fail2ban
    log_ok "fail2ban 已啟用（SSH 失敗 3 次封鎖 1 小時）"
}

# ============================================================
# 顯示 tmux 使用教學
# ============================================================
show_tmux_guide() {
    echo ""
    log_ok "============================================"
    log_ok "  tmux + SSH 設定完成！"
    log_ok "============================================"
    echo ""
    log_info "tmux 常用操作："
    echo ""
    echo "  建立 session:    tmux new -s claude"
    echo "  離開 session:    Ctrl+a, d（session 繼續在背景跑）"
    echo "  重新連接:        tmux attach -t claude"
    echo "  列出 sessions:   tmux ls"
    echo ""
    echo "  分割視窗:        Ctrl+a, |（水平）/ Ctrl+a, -（垂直）"
    echo "  切換 pane:       Ctrl+a, h/j/k/l"
    echo "  捲動:            滑鼠滾輪 或 Ctrl+a, ["
    echo ""
    log_info "推薦的 tmux 工作流程："
    echo ""
    echo "  # Session 1: Claude Code（AI 助手）"
    echo "  tmux new -s claude 'claude'"
    echo ""
    echo "  # Session 2: 監控 Docker"
    echo "  tmux new -s monitor 'watch docker ps'"
    echo ""
    echo "  # Session 3: 查看 log"
    echo "  tmux new -s logs 'docker logs -f coolify'"
    echo ""
}

# ============================================================
# 主流程
# ============================================================
main() {
    setup_tmux
    setup_ssh_security
    setup_ssh_key
    setup_fail2ban
    show_tmux_guide
}

main "$@"
