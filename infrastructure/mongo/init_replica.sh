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
TARGET_HOST="${MONGO_ADVERTISED_HOST:-127.0.0.1}:${MONGO_PORT:-27017}"

echo "⏳ Đang chờ MongoDB container [$CONTAINER_NAME] khởi động và đạt trạng thái healthy..."

max_attempts=40
attempt=0
health_status="starting"

while [ $attempt -lt $max_attempts ]; do
    if docker exec "$CONTAINER_NAME" mongosh --host 127.0.0.1 --quiet --eval "db.adminCommand({ ping: 1 }).ok" 2>/dev/null | grep -q "1"; then
        echo "✅ MongoDB is healthy and accepting connections!"
        break
    fi
    sleep 2
    attempt=$((attempt + 1))
done

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
    // Thiết lập Profiling Level 1 (>=300ms) cho MongoDB
    db.runCommand({ profile: 1, slowms: 300 });
    print('✅ Global Slow Query Profiling (profile: 1, slowms: 300ms) configured successfully!');
} catch (e) {
    print('⚠️ Reconfig warning/error: ' + e);
}
"

docker exec "$CONTAINER_NAME" mongosh --host 127.0.0.1 --quiet --eval "$RECONFIG_JS" || true

echo "✅ Hoàn tất cấu hình MongoDB Replica Set ($TARGET_HOST)!"
