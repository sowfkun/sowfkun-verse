#!/usr/bin/env bash
set -eo pipefail

# ==============================================================================
# SOWFKUN VERSE - TAILSCALE NODE PROVISIONING & ZERO-TRUST HARDENING
# Supports: Ubuntu 22.04 / 24.04 (IPv4 / IPv6-Only / Dual-Stack / Netcup / GCP)
# Usage:
#   sudo bash 01-setup-tailscale.sh
#   sudo bash 01-setup-tailscale.sh --authkey=tskey-auth-xxxxx --hostname=s1-netcup-mongo
# ==============================================================================

AUTH_KEY=""
HOSTNAME_INPUT=""
ENABLE_SSH=true

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --authkey=*) AUTH_KEY="${1#*=}" ;;
        --auth-key=*) AUTH_KEY="${1#*=}" ;;
        --hostname=*) HOSTNAME_INPUT="${1#*=}" ;;
        --no-ssh) ENABLE_SSH=false ;;
        -k|--authkey) AUTH_KEY="$2"; shift ;;
        -h|--hostname) HOSTNAME_INPUT="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

if [[ $EUID -ne 0 ]]; then
   echo "❌ Script này bắt buộc phải chạy dưới quyền root (sudo)!"
   exit 1
fi

echo "================================================================="
echo ">>> SOWFKUN VERSE - TAILSCALE PROVISIONING & ZERO-TRUST MESH"
echo "================================================================="

# ------------------------------------------------------------------------------
# 1. IPv6-Only Environment Optimization (DNS64 Setup)
# ------------------------------------------------------------------------------
has_ipv4=$(ip -4 route show default 2>/dev/null || true)
has_ipv6=$(ip -6 route show default 2>/dev/null || true)

if [[ -z "$has_ipv4" && -n "$has_ipv6" ]]; then
    echo "🌐 Phát hiện môi trường IPv6-only (Netcup VPS không có IPv4 Public)."
    echo "⚙️ Đang cấu hình DNS64 (Trex / Cloudflare) để phân giải & kết nối IPv4 repositories..."
    
    # Backup resolv.conf
    cp /etc/resolv.conf /etc/resolv.conf.bak 2>/dev/null || true
    
    cat << 'EOF' > /etc/resolv.conf
# DNS64 Servers for IPv6-Only Environments
nameserver 2a00:1098:2b::1
nameserver 2a01:4f8:c2c:123f::1
nameserver 2606:4700:4700::1111
nameserver 2001:4860:4860::8888
EOF
    echo "✅ Đã cấu hình DNS64 thành công."
fi

# ------------------------------------------------------------------------------
# 2. Kernel Optimization & IP Forwarding
# ------------------------------------------------------------------------------
echo "⚙️ Đang tối ưu Kernel Sysctl cho Tailscale & WireGuard..."
cat << 'EOF' > /etc/sysctl.d/99-tailscale.conf
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.core.rmem_max = 26214400
net.core.wmem_max = 26214400
EOF
sysctl -p /etc/sysctl.d/99-tailscale.conf >/dev/null 2>&1 || true

# ------------------------------------------------------------------------------
# 3. Install Tailscale
# ------------------------------------------------------------------------------
if ! command -v tailscale >/dev/null 2>&1; then
    echo "📦 Đang cài đặt Tailscale từ official repository..."
    apt-get update -y
    apt-get install -y curl ufw iptables
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/$(. /etc/os-release && echo "$VERSION_CODENAME").noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/$(. /etc/os-release && echo "$VERSION_CODENAME").tailscale-list | tee /etc/apt/sources.list.d/tailscale.list
    apt-get update -y
    apt-get install -y tailscale
    systemctl enable --now tailscaled
    echo "✅ Đã cài đặt Tailscale thành công!"
else
    echo "✅ Tailscale đã được cài đặt sẵn."
    systemctl restart tailscaled 2>/dev/null || true
fi

# ------------------------------------------------------------------------------
# 4. Join Tailnet
# ------------------------------------------------------------------------------
TS_ARGS=()
if [[ "$ENABLE_SSH" == true ]]; then
    TS_ARGS+=(--ssh)
fi
if [[ -n "$HOSTNAME_INPUT" ]]; then
    TS_ARGS+=(--hostname="$HOSTNAME_INPUT")
fi
if [[ -n "$AUTH_KEY" ]]; then
    TS_ARGS+=(--authkey="$AUTH_KEY")
    echo "🔑 Đang kết nối vào Tailnet qua Auth Key..."
    tailscale up "${TS_ARGS[@]}" --accept-routes --reset
else
    echo ""
    echo "👉 Chưa truyền --authkey. Chạy lệnh sau để xác thực Tailscale:"
    echo "   tailscale up ${TS_ARGS[*]} --accept-routes"
    echo ""
    tailscale up "${TS_ARGS[@]}" --accept-routes --reset || true
fi

# ------------------------------------------------------------------------------
# 5. Zero-Trust UFW Firewall Hardening
# ------------------------------------------------------------------------------
echo ""
echo "🛡️ Đang thiết lập UFW Zero-Trust Firewall (Chặn Public, chỉ mở qua Tailscale)..."
ufw --force reset >/dev/null 2>&1 || true
ufw default deny incoming
ufw default allow outgoing

# Cho phép toàn bộ traffic an toàn từ card mạng ảo tailscale0
ufw allow in on tailscale0 comment 'Allow All Tailscale Mesh Ingress'

# Cho phép dải IP Carrier-Grade NAT của Tailscale
ufw allow from 100.64.0.0/10 comment 'Allow Tailscale IP Range'

# Cho phép SSH khẩn cấp qua IPv6 nếu cần cứu hộ (tùy chọn)
# ufw allow proto tcp to any port 22

ufw --force enable
echo "✅ UFW Firewall đã kích hoạt ở chế độ Zero-Trust!"

echo ""
echo "================================================================="
echo "🎉 HOÀN TẤT THIẾT LẬP TAILSCALE NODE!"
echo "================================================================="
tailscale_ipv4=$(tailscale ip -4 2>/dev/null || echo "N/A")
tailscale_ipv6=$(tailscale ip -6 2>/dev/null || echo "N/A")
echo "  📌 Tailscale IPv4: $tailscale_ipv4"
echo "  📌 Tailscale IPv6: $tailscale_ipv6"
echo "  📌 Trạng thái UFW: Chặn 100% Public Ingress, chỉ mở cổng cho Tailscale."
echo "================================================================="
