#!/usr/bin/env bash
# ==============================================================================
# CASE 4 - BƯỚC 3: KIỂM TOÁN AN NINH & KẾT NỐI MẠNG TAILSCALE MESH
# ==============================================================================
set -eo pipefail

echo "================================================================="
echo "🔍 CASE 4: TAILSCALE MESH SECURITY AUDIT & LATENCY CHECK"
echo "================================================================="

# 1. Trạng thái Tailscale Local
echo ""
echo "📌 [1/4] KIỂM TRA TRẠNG THÁI TAILSCALE LOCAL:"
if ! command -v tailscale &>/dev/null; then
  echo "❌ Tailscale chưa được cài đặt trên máy này!"
  exit 1
fi

LOCAL_TS_IP=$(tailscale ip -4 2>/dev/null || true)
echo "  • Local Tailscale IPv4: ${LOCAL_TS_IP:-'Chưa có IP'}"
tailscale status --peers=false || true

# 2. Kiểm tra kết nối tới Mongo Node
echo ""
MONGO_NODE_IP="${1:-$(tailscale status 2>/dev/null | grep -i 'mongo' | awk '{print $1}' | head -n 1)}"
if [[ -z "$MONGO_NODE_IP" ]]; then
  MONGO_NODE_IP="100.64.0.1"
fi

echo "📌 [2/4] KIỂM TRA KẾT NỐI TỚI MONGO NODE (${MONGO_NODE_IP}):"

if ping -c 3 -W 3 "$MONGO_NODE_IP" &>/dev/null; then
  echo "  ✅ Ping tới Mongo Node (${MONGO_NODE_IP}): THÀNH CÔNG!"
  tailscale ping -c 2 "$MONGO_NODE_IP" 2>/dev/null || true
else
  echo "  ⚠️ Chưa thể ping tới Mongo Node (${MONGO_NODE_IP}). Vui lòng kiểm tra Mongo Node đã online chưa."
fi

# 3. Kiểm tra cổng dịch vụ MongoDB (27017) qua Mesh
echo ""
echo "📌 [3/4] KIỂM TRA TRUY CẬP CỔNG DỊCH VỤ MONGODB NỘI BỘ (27017):"
if command -v nc &>/dev/null; then
  if nc -z -v -w 3 "$MONGO_NODE_IP" 27017 2>/dev/null; then
    echo "  ✅ Cổng MongoDB 27017 qua Tailscale Mesh: KẾT NỐI THÔNG SUỐT!"
  else
    echo "  ⚠️ Cổng 27017 chưa phản hồi qua nc."
  fi
elif command -v timeout &>/dev/null; then
  if timeout 3 bash -c "cat < /dev/null > /dev/tcp/${MONGO_NODE_IP}/27017" 2>/dev/null; then
    echo "  ✅ Cổng MongoDB 27017 qua Tailscale Mesh: KẾT NỐI THÔNG SUỐT!"
  else
    echo "  ⚠️ Cổng 27017 chưa phản hồi."
  fi
else
  echo "  ℹ️ Bỏ qua kiểm tra TCP port do thiếu công cụ (nc/bash socket)."
fi

# 4. Kiểm tra cô lập cổng Public (Zero-Trust Ingress Check)
echo ""
echo "📌 [4/4] KIỂM TRA CÔ LẬP AN NINH CỔNG PUBLIC TRÊN MÁY NÀY:"
echo "💡 Các cổng nội bộ (6379, 9092, 8090) BẮT BUỘC chỉ bind trên tailscale0/localhost..."

PUBLIC_IP=$(curl -s -m 3 https://icanhazip.com || curl -s -m 3 https://ifconfig.me || true)
echo "  • Public IP máy này: ${PUBLIC_IP:-'Không xác định'}"
echo "  • Đang kiểm tra listening sockets trên máy..."

if command -v ss &>/dev/null; then
  ss -tulpn | grep -E ':(6379|9092|27017|8085|8090)' || echo "  ✅ Không có cổng nguy hiểm nào mở tự do ngoài ý muốn!"
elif command -v netstat &>/dev/null; then
  netstat -tulpn | grep -E ':(6379|9092|27017|8085|8090)' || echo "  ✅ Cổng dịch vụ an toàn!"
fi

echo ""
echo "================================================================="
echo "🎉 HOÀN TẤT KIỂM TOÁN AN NINH MẠNG TAILSCALE MESH!"
echo "================================================================="
