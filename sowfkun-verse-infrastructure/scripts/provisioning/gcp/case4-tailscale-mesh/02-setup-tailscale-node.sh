#!/usr/bin/env bash
# ==============================================================================
# CASE 4 - BƯỚC 2: CÀI ĐẶT & GIA CỐ TAILSCALE MESH NODE TRÊN GCP VM
# ==============================================================================
set -eo pipefail

if [[ $EUID -ne 0 ]]; then
   echo "❌ Script này bắt buộc phải chạy dưới quyền root (sudo)."
   exit 1
fi

echo "================================================================="
echo "🚀 CASE 4: TAILSCALE MESH NODE PROVISIONER & HARDENING"
echo "================================================================="

echo ""
echo "📌 [1/4] CHỌN ĐỊNH DANH MÁY CHỦ (HOSTNAME):"
echo "  [1] s-gcp-cache-mq  (Server 1 - Redis & Kafka Node)"
echo "  [2] s-gcp-app       (Server 2 - Go API Backend Node)"
echo "  [3] s-gcp-gateway   (Server 3 - Egress Gateway Node)"
read -rp "👉 Chọn máy chủ [1-3, Mặc định: 1]: " host_choice
host_choice="${host_choice:-1}"

NODE_HOSTNAME="s-gcp-cache-mq"
if [[ "$host_choice" == "2" ]]; then NODE_HOSTNAME="s-gcp-app"; fi
if [[ "$host_choice" == "3" ]]; then NODE_HOSTNAME="s-gcp-gateway"; fi

# 1. Cài đặt Tailscale chính thức
echo ""
echo "📦 [2/4] Đang cài đặt Tailscale chính thức..."
if ! command -v tailscale &>/dev/null; then
  curl -fsSL https://tailscale.com/install.sh | sh
  systemctl enable --now tailscaled
else
  echo "✅ Tailscale đã được cài đặt sẵn."
fi

# 2. Tối ưu hóa Kernel Sysctl & IP Forwarding
echo ""
echo "⚙️ [3/4] Cấu hình Kernel Sysctl cho Tailscale Mesh..."
mkdir -p /etc/sysctl.d
cat << 'EOF' > /etc/sysctl.d/99-tailscale.conf
# Tailscale WireGuard Optimization
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
EOF
sysctl -p /etc/sysctl.d/99-tailscale.conf >/dev/null 2>&1 || sysctl --system >/dev/null 2>&1

# 3. Khởi động Tailscale và gia nhập Tailnet
echo ""
echo "🔗 [4/4] Đang kết nối node [ ${NODE_HOSTNAME} ] vào Tailnet..."
echo "💡 Bật tính năng Tailscale SSH và chấp nhận Routes..."

tailscale up \
  --hostname="${NODE_HOSTNAME}" \
  --ssh \
  --accept-routes \
  --reset

echo ""
echo "================================================================="
echo "🎉 HOÀN TẤT CÀI ĐẶT TAILSCALE CHO NODE [ ${NODE_HOSTNAME} ]!"
echo "👉 Tailscale IP của máy này: $(tailscale ip -4 2>/dev/null || echo 'Chờ login')"
echo "👉 Kiểm tra trạng thái mạng: tailscale status"
echo "================================================================="
