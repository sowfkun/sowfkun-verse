#!/usr/bin/env bash
# ==============================================================================
# ENTERPRISE OS HARDENING & CLOUD METADATA PROTECTION
# Platform: Ubuntu 22.04 / 24.04 LTS (Debian-based)
# Features:
#   1. Chặn IP Metadata Cloud (169.254.169.254) chống SSRF
#   2. Khóa SSH Daemon (Tắt password login, tắt root login, chỉ cho phép SSH key)
#   3. Cài đặt fail2ban & iptables-persistent lưu cấu hình vĩnh viễn
#   4. Tinh chỉnh Kernel Sysctl an toàn
# Usage:
#   sudo bash os-hardening.sh
# ==============================================================================
set -eo pipefail

if [[ $EUID -ne 0 ]]; then
   echo "❌ Script này bắt buộc phải chạy dưới quyền root (sudo)!" 
   exit 1
fi

echo "================================================================="
echo "🛡️ BẮT ĐẦU QUY TRÌNH OS HARDENING & BẢO MẬT HỆ THỐNG"
echo "================================================================="

# 1. Cập nhật gói và cài đặt công cụ bảo vệ
echo "📦 1. Cập nhật hệ thống và cài đặt iptables-persistent, fail2ban..."
export DEBIAN_FRONTEND=noninteractive
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
apt-get update -qq
apt-get install -y -qq iptables-persistent netfilter-persistent fail2ban curl ufw

# 2. Chặn Cloud Metadata (169.254.169.254) chống Cloud SSRF
echo "🚫 2. Cấu hình IPTables chặn Link-Local Metadata (169.254.169.254)..."
if ! iptables -C OUTPUT -d 169.254.169.254 -j DROP 2>/dev/null; then
    iptables -A OUTPUT -d 169.254.169.254 -j DROP
fi
netfilter-persistent save

# 3. Hardening SSH Daemon
echo "🔑 3. Cấu hình bảo mật SSH Daemon (/etc/ssh/sshd_config)..."
SSHD_CONFIG="/etc/ssh/sshd_config"
if [ -f "$SSHD_CONFIG" ]; then
    # Backup config gốc
    cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak.$(date +%s)"

    # Tắt Password Auth, tắt Root Login
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
    sed -i 's/^#*PermitEmptyPasswords.*/PermitEmptyPasswords no/' "$SSHD_CONFIG"
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"
    sed -i 's/^#*MaxAuthTries.*/MaxAuthTries 3/' "$SSHD_CONFIG"

    # Áp dụng cho sshd drop-in nếu có (Ubuntu 22.04+ sshd_config.d)
    if [ -d "/etc/ssh/sshd_config.d" ]; then
        cat <<EOF > /etc/ssh/sshd_config.d/99-hardened.conf
PasswordAuthentication no
PermitEmptyPasswords no
PermitRootLogin no
MaxAuthTries 3
EOF
    fi

    # Khởi động lại dịch vụ SSH
    systemctl restart ssh || systemctl restart sshd || true
    echo "✅ Đã khóa SSH Daemon an toàn."
fi

# 4. Tinh chỉnh Kernel Sysctl (TCP Syn Cookies, Disable IP Forwarding nếu không phải Router)
echo "⚙️ 4. Tối ưu tham số bảo vệ Kernel Network (/etc/sysctl.d/99-security.conf)..."
cat <<EOF > /etc/sysctl.d/99-security.conf
# Chống SYN Flood Attack
net.ipv4.tcp_syncookies = 1
# Không chấp nhận ICMP Redirect
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
# Bật Reverse Path Filtering chống IP Spoofing
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
# Tăng giới hạn mmap cho OpenSearch / MongoDB
vm.max_map_count = 262144
EOF
sysctl -p /etc/sysctl.d/99-security.conf > /dev/null 2>&1 || sysctl --system > /dev/null 2>&1

echo "================================================================="
echo "🎉 HOÀN TẤT OS HARDENING! MÁY CHỦ ĐÃ ĐƯỢC BẢO VỆ AN TOÀN."
echo "================================================================="
