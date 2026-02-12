#!/bin/bash
#
# Quick Deploy - 單一專案快速部署到 VPS
# ============================================================
#
# 用途：當你不想用 Coolify，只想快速把一個專案部署上去
#
# 使用方式：
#   在你的專案根目錄執行：
#   bash quick-deploy.sh <vps-user>@<vps-ip> <domain>
#
# 範例：
#   bash quick-deploy.sh root@your-vps-ip agents.jeffwang.work

set -euo pipefail

# ============================================================
# 參數
# ============================================================
VPS_HOST="${1:-}"
DOMAIN="${2:-}"
APP_NAME="${3:-$(basename "$(pwd)")}"
REMOTE_DIR="/opt/apps/$APP_NAME"

if [ -z "$VPS_HOST" ]; then
    echo "用法: bash quick-deploy.sh <user@vps-ip> [domain] [app-name]"
    echo ""
    echo "範例:"
    echo "  bash quick-deploy.sh root@1.2.3.4 agents.jeffwang.work"
    echo "  bash quick-deploy.sh root@1.2.3.4 agents.jeffwang.work my-agent"
    exit 1
fi

echo "=========================================="
echo "  Quick Deploy"
echo "=========================================="
echo "  VPS:      $VPS_HOST"
echo "  Domain:   ${DOMAIN:-none}"
echo "  App:      $APP_NAME"
echo "  Remote:   $REMOTE_DIR"
echo "=========================================="
echo ""

# ============================================================
# Step 1: 確認檔案
# ============================================================
echo "[1/5] 檢查專案檔案..."

if [ ! -f "docker-compose.yml" ] && [ ! -f "docker-compose.yaml" ] && [ ! -f "Dockerfile" ]; then
    echo "警告：找不到 docker-compose.yml 或 Dockerfile"
    echo "將嘗試使用 Node.js 部署方式"
    DEPLOY_MODE="nodejs"
else
    DEPLOY_MODE="docker"
fi

echo "  部署模式: $DEPLOY_MODE"

# ============================================================
# Step 2: 同步檔案到 VPS
# ============================================================
echo "[2/5] 同步檔案到 VPS..."

ssh "$VPS_HOST" "mkdir -p $REMOTE_DIR"

rsync -avz --progress \
    --exclude 'node_modules' \
    --exclude '.git' \
    --exclude '.next' \
    --exclude 'dist' \
    --exclude '.env.local' \
    ./ "$VPS_HOST:$REMOTE_DIR/"

echo "  檔案同步完成"

# ============================================================
# Step 3: 在 VPS 上建構並部署
# ============================================================
echo "[3/5] 在 VPS 上建構..."

if [ "$DEPLOY_MODE" = "docker" ]; then
    ssh "$VPS_HOST" "cd $REMOTE_DIR && docker compose down 2>/dev/null; docker compose up -d --build"
else
    ssh "$VPS_HOST" << REMOTE_SCRIPT
cd $REMOTE_DIR
# 安裝依賴
if [ -f package-lock.json ]; then
    npm ci --production
elif [ -f yarn.lock ]; then
    yarn install --production
elif [ -f requirements.txt ]; then
    pip install -r requirements.txt
fi
# 建構
npm run build 2>/dev/null || true
# 用 PM2 管理 Node.js 進程
if ! command -v pm2 &>/dev/null; then
    npm install -g pm2
fi
pm2 delete $APP_NAME 2>/dev/null || true
pm2 start npm --name "$APP_NAME" -- start
pm2 save
REMOTE_SCRIPT
fi

echo "  建構完成"

# ============================================================
# Step 4: 設定 Nginx 反向代理（如果有域名）
# ============================================================
if [ -n "$DOMAIN" ]; then
    echo "[4/5] 設定 Nginx 反向代理..."

    ssh "$VPS_HOST" << NGINX_SCRIPT
# 安裝 Nginx 和 Certbot（如果沒有）
if ! command -v nginx &>/dev/null; then
    apt-get install -y -qq nginx
fi
if ! command -v certbot &>/dev/null; then
    apt-get install -y -qq certbot python3-certbot-nginx
fi

# 建立 Nginx 設定
cat > /etc/nginx/sites-available/$APP_NAME << 'NGINX_EOF'
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
NGINX_EOF

ln -sf /etc/nginx/sites-available/$APP_NAME /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

# SSL 憑證
certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN 2>/dev/null || \
    echo "SSL 設定可能需要手動處理（域名可能還沒指向此 IP）"
NGINX_SCRIPT

    echo "  Nginx 設定完成"
else
    echo "[4/5] 跳過 Nginx 設定（未提供域名）"
fi

# ============================================================
# Step 5: 驗證
# ============================================================
echo "[5/5] 驗證部署..."

ssh "$VPS_HOST" << CHECK_SCRIPT
echo ""
echo "容器狀態:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | head -10 || true
echo ""
echo "PM2 狀態:"
pm2 list 2>/dev/null || true
CHECK_SCRIPT

echo ""
echo "=========================================="
echo "  部署完成！"
echo "=========================================="
if [ -n "$DOMAIN" ]; then
    echo "  https://$DOMAIN"
else
    echo "  http://$VPS_HOST:3000"
fi
echo "=========================================="
