#!/bin/bash
# deploy.sh — SSH 後自動部署腳本
# 使用方式：ssh user@server 'bash -s' < deploy.sh
#       或：在伺服器上直接執行 ./deploy.sh

set -e

REPO_URL="https://github.com/JeffWang110/Homework.git"
BRANCH="master"
DEPLOY_DIR="${DEPLOY_DIR:-/var/www/html}"
TMP_DIR=$(mktemp -d)

echo "=============================="
echo " 自動部署開始"
echo " 目標目錄：$DEPLOY_DIR"
echo " 時間：$(date '+%Y-%m-%d %H:%M:%S')"
echo "=============================="

# 1. 拉取最新程式碼
echo "[1/4] 拉取最新程式碼..."
git clone --depth=1 --branch "$BRANCH" "$REPO_URL" "$TMP_DIR" 2>&1

# 2. 複製網頁檔案
echo "[2/4] 複製網頁檔案..."
mkdir -p "$DEPLOY_DIR"
cp "$TMP_DIR/index.html"  "$DEPLOY_DIR/"
cp "$TMP_DIR/food.html"   "$DEPLOY_DIR/"
[ -f "$TMP_DIR/index2.html" ] && cp "$TMP_DIR/index2.html" "$DEPLOY_DIR/"

# 3. 清理暫存目錄
echo "[3/4] 清理暫存目錄..."
rm -rf "$TMP_DIR"

# 4. 完成
echo "[4/4] 部署完成！"
echo "=============================="
echo " 已部署的檔案："
ls -lh "$DEPLOY_DIR"/*.html 2>/dev/null || echo " (找不到 HTML 檔案)"
echo "=============================="
