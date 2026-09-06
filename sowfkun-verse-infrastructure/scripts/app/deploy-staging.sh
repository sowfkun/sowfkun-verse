#!/usr/bin/env bash
# ==============================================================================
# Script Triển Khai Thủ Công Backend API trên Staging Server
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

BRANCH="${1:-dev}"

echo "================================================================="
echo "🚀 APPLICATION BACKEND - MANUAL DEPLOY SCRIPT"
echo "👉 Branch: ${BRANCH}"
echo "📁 Root: ${ROOT_DIR}"
echo "================================================================="

cd "${ROOT_DIR}"

# 1. Kéo code mới nhất từ git
echo "📥 1. Kéo mã nguồn mới nhất từ branch ${BRANCH}..."
git fetch origin "${BRANCH}"
git checkout "${BRANCH}"
git pull origin "${BRANCH}"

# 2. Đảm bảo docker network tồn tại
if ! docker network ls | grep -q "app_net"; then
  echo "🌐 2. Khởi tạo Docker network: app_net..."
  docker network create app_net
fi

# 3. Rebuild và khởi động container
echo "🔨 3. Rebuild và chạy container API..."
cd "${ROOT_DIR}/sowfkun-verse-infrastructure/api"
docker compose down || true
docker compose up -d --build --remove-orphans

# 4. Health check
echo "🩺 4. Đang kiểm tra sức khỏe API (/api/v1/security/public-key)..."
sleep 5
for i in {1..10}; do
  if curl -s -f http://localhost:8080/api/v1/security/public-key > /dev/null 2>&1; then
    echo "✅ API KHỞI ĐỘNG THÀNH CÔNG VÀ ĐANG HOẠT ĐỘNG!"
    docker image prune -f > /dev/null 2>&1
    exit 0
  fi
  echo "⏳ Đang đợi API sẵn sàng ($i/10)..."
  sleep 3
done

echo "❌ Lỗi: Healthcheck thất bại! Xem log bên dưới:"
docker logs --tail 50 app_api
exit 1
