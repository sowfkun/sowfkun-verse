#!/usr/bin/env bash
set -eo pipefail

# ==============================================================================
# SCRIPT TỰ ĐỘNG KHỞI TẠO & CẤU HÌNH REPLICA SET CHO MONGODB ATLAS LOCAL
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ -f .env ]; then
    # Nạp biến môi trường từ .env
    set -a
    [ -f .env ] && . .env
    set +a
fi

CONTAINER_NAME="${MONGO_CONTAINER_NAME:-app_mongo}"
TARGET_HOST="127.0.0.1:${MONGO_PORT:-27017}"

echo "⏳ Đang chờ MongoDB container [$CONTAINER_NAME] khởi động và đạt trạng thái healthy..."

max_attempts=40
attempt=0
health_status="starting"

while [ $attempt -lt $max_attempts ]; do
    health_status=$(docker inspect "$CONTAINER_NAME" --format='{{.State.Health.Status}}' 2>/dev/null || echo "starting")
    if [ "$health_status" == "healthy" ]; then
        break
    fi
    sleep 2
    attempt=$((attempt + 1))
done

if [ "$health_status" != "healthy" ]; then
    echo "⚠️ MongoDB chưa đạt trạng thái healthy sau $((max_attempts * 2))s. Vẫn thử kết nối cấu hình..."
fi

echo "⚙️ Đang kiểm tra & cấu hình Replica Set member host thành: $TARGET_HOST..."

RECONFIG_JS="
try {
    var cfg = rs.conf();
    if (!cfg || !cfg.members || cfg.members.length === 0) {
        rs.initiate({
            _id: '$CONTAINER_NAME',
            members: [{ _id: 0, host: '$TARGET_HOST' }]
        });
        print('✅ Initialized new Replica Set with host: $TARGET_HOST');
    } else if (cfg.members[0].host !== '$TARGET_HOST') {
        cfg.members[0].host = '$TARGET_HOST';
        var res = rs.reconfig(cfg, { force: true });
        print('✅ Reconfigured Replica Set member to: $TARGET_HOST (ok: ' + res.ok + ')');
    } else {
        print('ℹ️ Replica Set member host is already: $TARGET_HOST');
    }
} catch (e) {
    print('⚠️ Reconfig warning/error: ' + e);
}
"

echo "$RECONFIG_JS" | docker exec -i "$CONTAINER_NAME" mongosh --quiet 2>/dev/null || true

echo "✅ Hoàn tất cấu hình MongoDB Replica Set ($TARGET_HOST)!"
