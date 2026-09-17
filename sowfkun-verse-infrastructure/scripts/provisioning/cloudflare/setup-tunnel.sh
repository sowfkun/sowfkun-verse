#!/usr/bin/env bash
set -eo pipefail

# ==============================================================================
# SOWFKUN VERSE - CLOUDFLARE ZERO-TRUST TUNNEL PROVISIONER
# Supports: Ubuntu 22.04 / 24.04 (Docker Compose & Standalone Container)
# Usage:
#   sudo bash setup-tunnel.sh --token=eyJhIjoi...
#   sudo bash setup-tunnel.sh (Interactive)
# ==============================================================================

TOKEN_INPUT=""
APP_NETWORK="app_net"
CONTAINER_NAME="app_cloudflared"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --token=*) TOKEN_INPUT="${1#*=}" ;;
        --token|-t) TOKEN_INPUT="$2"; shift ;;
        --network=*) APP_NETWORK="${1#*=}" ;;
        --name=*) CONTAINER_NAME="${1#*=}" ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

if [[ $EUID -ne 0 ]]; then
   echo "❌ Script này bắt buộc phải chạy dưới quyền root (sudo)!"
   exit 1
fi

echo "================================================================="
echo "🚀 SOWFKUN VERSE - CLOUDFLARE TUNNEL PROVISIONER"
echo "================================================================="

# 1. Prompt for token if not provided
if [[ -z "$TOKEN_INPUT" ]]; then
    read -rp "👉 Nhập Cloudflare Tunnel Token: " TOKEN_INPUT
fi

if [[ -z "$TOKEN_INPUT" ]]; then
    echo "❌ Token không được để trống!"
    exit 1
fi

# 2. Ensure Docker and Network exist
if ! command -v docker &>/dev/null; then
    echo "❌ Docker chưa được cài đặt trên máy chủ!"
    exit 1
fi

if ! docker network inspect "$APP_NETWORK" &>/dev/null; then
    echo "⚙️ Đang tạo Docker Network: $APP_NETWORK..."
    docker network create "$APP_NETWORK"
fi

# 3. Stop old container if exists
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "🔄 Đang dừng và xóa container cũ [${CONTAINER_NAME}]..."
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
fi

# 4. Run Cloudflared container
echo "📦 Đang khởi chạy Cloudflare Tunnel container [${CONTAINER_NAME}]..."
docker run -d \
  --name "$CONTAINER_NAME" \
  --restart unless-stopped \
  --network "$APP_NETWORK" \
  cloudflare/cloudflared:latest tunnel --no-autoupdate run --token "$TOKEN_INPUT"

echo ""
echo "✅ Container [${CONTAINER_NAME}] đã khởi chạy thành công!"
echo "📋 Kiểm tra logs:"
docker logs --tail 10 "$CONTAINER_NAME"

echo ""
echo "================================================================="
echo "🎉 CLOUDFLARE TUNNEL SẴN SÀNG!"
echo "📌 Vui lòng cấu hình Public Hostname trên Cloudflare Dashboard:"
echo "   - Service Type: HTTP"
echo "   - URL: app_api:8080"
echo "================================================================="
