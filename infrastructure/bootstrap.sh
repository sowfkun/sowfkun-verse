#!/usr/bin/env bash
set -eo pipefail

# ==============================================================================
# SOWFKUN-VERSE INFRASTRUCTURE BOOTSTRAP SCRIPT (Ubuntu 24.04 LTS / 1GB RAM)
# Supports: Redpanda (Kafka), Redis, MongoDB (Atlas Local), OpenSearch, Go API
# Usage:
#   sudo bash bootstrap.sh --service=redis --mode=fresh
#   sudo bash bootstrap.sh --service=kafka --mode=fresh
#   sudo bash bootstrap.sh --service=mongo --mode=fresh
#   sudo bash bootstrap.sh --service=opensearch --mode=fresh
#   sudo bash bootstrap.sh --service=api --mode=fresh
#   sudo bash bootstrap.sh --service=redis --mode=rollback
# ==============================================================================

SERVICE=""
MODE="fresh"
SWAP_SIZE_GB=2

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --service=*) SERVICE="${1#*=}" ;;
        --mode=*) MODE="${1#*=}" ;;
        -s|--service) SERVICE="$2"; shift ;;
        -m|--mode) MODE="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

if [[ -z "$SERVICE" ]]; then
    echo "================================================================="
    echo "❌ Lỗi: Bạn chưa chọn service!"
    echo "Ví dụ: sudo bash bootstrap.sh --service=redis --mode=fresh"
    echo "Danh sách services hợp lệ: kafka, redis, mongo, opensearch, api, all"
    echo "================================================================="
    exit 1
fi

echo "================================================================="
echo "🚀 SOWFKUN-VERSE INFRA PROVISIONING & PRODUCTION HARDENING"
echo "👉 Target Service : $SERVICE"
echo "👉 Mode           : $MODE"
echo "================================================================="

# Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
   echo "❌ Script này bắt buộc phải chạy dưới quyền root (sudo)!" 
   exit 1
fi

# 1. TIME SYNC & UTC TIMEZONE (Quan trọng cho JWT, E2EE, Kafka)
setup_time_sync() {
    echo "⏰ [1/9] Thiết lập đồng bộ thời gian chuẩn UTC và NTP..."
    timedatectl set-timezone UTC
    timedatectl set-ntp true
    echo "✅ Đã đồng bộ múi giờ UTC ($(date -u))"
}

# 2. SETUP SWAP FILE (Cực kỳ quan trọng cho Server 1GB RAM)
setup_swap() {
    if ! grep -q "swapfile" /proc/swaps; then
        echo "📦 [2/9] Đang tạo ${SWAP_SIZE_GB}GB Swap File để chống OOM Killer..."
        fallocate -l ${SWAP_SIZE_GB}G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=$((SWAP_SIZE_GB * 1024))
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        if ! grep -q "^/swapfile" /etc/fstab; then
            echo '/swapfile none swap sw 0 0' >> /etc/fstab
        fi
        echo "✅ Đã kích hoạt Swap File thành công!"
    else
        echo "ℹ️ Swap file đã tồn tại, bỏ qua bước tạo Swap."
    fi
}

# 3. DEBLOAT & REMOVE UNNECESSARY SERVICES
debloat_os() {
    echo "🧹 [3/9] Đang gỡ bỏ các service telemetry/bloatware ngầm..."
    systemctl stop apport whoopsie 2>/dev/null || true
    systemctl disable apport whoopsie 2>/dev/null || true
    apt-get purge -y apport whoopsie 2>/dev/null || true
    apt-get autoremove -y 2>/dev/null || true
}

# 4. KERNEL & LIMITS TUNING (Kafka, Redis, Mongo, OpenSearch, Outbound Network)
tune_kernel() {
    echo "⚡ [4/9] Đang cấu hình Kernel Sysctl, Limits & DNS Resolver..."
    
    cat << 'EOF' > /etc/sysctl.d/99-sowfkun-infra.conf
# Bảo mật mạng & Chống tấn công mạng
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0

# Tối ưu Outgoing HTTP & Mạng TCP (Chống nghẽn cổng & Timeout ra ngoài)
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_intvl = 15
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_syn_retries = 3
net.ipv4.tcp_synack_retries = 3
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1

# Tối ưu OpenSearch / MongoDB / Redis / Kafka
vm.max_map_count = 262144
vm.overcommit_memory = 1
vm.swappiness = 10
net.core.somaxconn = 65535
fs.file-max = 2097152
EOF

    sysctl --system > /dev/null

    cat << 'EOF' > /etc/security/limits.d/99-sowfkun-limits.conf
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
EOF

    # Tối ưu DNS Resolver (Alibaba Internal DNS + Cloudflare + Google)
    mkdir -p /etc/systemd/resolved.conf.d
    cat << 'EOF' > /etc/systemd/resolved.conf.d/dns.conf
[Resolve]
DNS=100.100.2.136 100.100.2.138 1.1.1.1 8.8.8.8
FallbackDNS=8.8.4.4 1.0.0.1
DNSSEC=no
DNSOverTLS=no
EOF
    systemctl restart systemd-resolved 2>/dev/null || true

    echo "✅ Đã tune Kernel, Limits & DNS Resolver thành công!"
}

# 5. INSTALL DOCKER ENGINE & DOCKER COMPOSE
install_docker() {
    if ! command -v docker &> /dev/null; then
        echo "🐳 [5/9] Đang cài đặt Docker Engine & Docker Compose chính thức..."
        apt-get update -y
        apt-get install -y ca-certificates curl gnupg lsb-release ufw fail2ban unattended-upgrades cron

        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
        chmod a+r /etc/apt/keyrings/docker.gpg

        echo \
          "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
          tee /etc/apt/sources.list.d/docker.list > /dev/null

        apt-get update -y
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
        # Cấu hình log rotation cho Docker daemon (tránh tràn đĩa)
        cat << 'EOF' > /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "3"
  }
}
EOF
        systemctl enable docker
        systemctl restart docker
        echo "✅ Đã cài đặt Docker và cấu hình Log Rotation thành công!"
    else
        echo "ℹ️ Docker đã được cài đặt sẵn."
    fi
}

# 6. CONFIGURE FIREWALL (UFW), FAIL2BAN & DOCKER SECURITY
setup_security() {
    echo "🛡️ [6/9] Đang thiết lập UFW Firewall, Fail2ban & Khóa Port Database..."
    systemctl enable fail2ban 2>/dev/null || true
    systemctl start fail2ban 2>/dev/null || true

    ufw default deny incoming
    ufw default allow outgoing
    
    # Cho phép SSH nội bộ hoặc quản lý qua Alibaba Cloud Workbench
    ufw allow 22/tcp comment 'SSH Port'
    if [[ "$SERVICE" == "api" || "$SERVICE" == "all" ]]; then
        ufw allow 8080/tcp comment 'Go API Port'
    fi

    # Kích hoạt UFW
    ufw --force enable
    
    # Kích hoạt tự động vá lỗi bảo mật định kỳ
    systemctl enable unattended-upgrades 2>/dev/null || true
    systemctl start unattended-upgrades 2>/dev/null || true

    echo "✅ Đã kích hoạt Firewall UFW & Hardening an toàn!"
}

# 7. SECURE SSH CONFIGURATION
harden_ssh() {
    echo "🔑 [7/9] Khóa bảo mật SSH (Chặn password brute-force)..."
    local ssh_d="/etc/ssh/sshd_config.d/99-hardening.conf"
    cat << 'EOF' > "$ssh_d"
# Vô hiệu hóa login bằng password nếu đã có Workbench / SSH Key
PasswordAuthentication no
PermitEmptyPasswords no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
EOF
    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true
    echo "✅ Đã áp dụng SSH Hardening!"
}

# 8. SETUP HEALTH MONITOR & DOCKER CLEANUP CRON JOBS
setup_monitoring_and_maintenance() {
    echo "🚨 [8/9] Đang thiết lập Hệ Thống Cảnh Báo & Tự Động Dọn Dẹp Định Kỳ..."
    
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Cài đặt script monitor vào /usr/local/bin
    if [ -f "$SCRIPT_DIR/scripts/monitor.sh" ]; then
        cp "$SCRIPT_DIR/scripts/monitor.sh" /usr/local/bin/sowfkun-monitor.sh
        chmod +x /usr/local/bin/sowfkun-monitor.sh
    fi

    # Tạo thư mục config cảnh báo nếu chưa có
    mkdir -p /etc/sowfkun
    if [ ! -f /etc/sowfkun/alert.conf ] && [ -f "$SCRIPT_DIR/scripts/alert.conf.example" ]; then
        cp "$SCRIPT_DIR/scripts/alert.conf.example" /etc/sowfkun/alert.conf
        echo "ℹ️ Đã tạo file cấu hình cảnh báo tại /etc/sowfkun/alert.conf (Điền Telegram Token vào đây)"
    fi

    # Đăng ký Cron Job kiểm tra sức khỏe mỗi 5 phút + Dọn dẹp Docker rác 3h sáng Chủ Nhật
    cat << 'EOF' > /etc/cron.d/sowfkun-maintenance
# Kiểm tra RAM, Swap, Disk, Docker Crash mỗi 5 phút
*/5 * * * * root /usr/local/bin/sowfkun-monitor.sh > /dev/null 2>&1

# Dọn dẹp images/cache Docker thừa lúc 3h sáng Chủ Nhật hàng tuần
0 3 * * 0 root /usr/bin/docker system prune -af --volumes=false > /dev/null 2>&1
EOF
    chmod 644 /etc/cron.d/sowfkun-maintenance
    systemctl restart cron 2>/dev/null || true

    echo "✅ Đã đăng ký Cron Job giám sát sức khỏe & dọn dẹp Docker tự động!"
}

# 9. START DOCKER COMPOSE STACK
start_service() {
    echo "🚀 [9/9] Khởi chạy dịch vụ: $SERVICE (Mode: $MODE)..."
    
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    BASE_DIR="$SCRIPT_DIR"

    start_target() {
        local target=$1
        local target_dir="$BASE_DIR/$target"
        
        if [ ! -d "$target_dir" ]; then
            echo "❌ Không tìm thấy thư mục: $target_dir"
            return 1
        fi

        cd "$target_dir"
        
        # Tự động tạo .env từ .env.example nếu chưa có
        if [ ! -f .env ] && [ -f .env.example ]; then
            echo "📄 Tạo file .env từ .env.example cho $target..."
            cp .env.example .env
        fi

        if [ "$MODE" == "rollback" ]; then
            echo "🔄 Rollback mode: Resetting and restarting containers for $target..."
            docker compose down --remove-orphans 2>/dev/null || true
        fi

        echo "🚀 Đang kéo images và chạy $target container..."
        docker compose up -d
        docker compose ps
    }

    if [ "$SERVICE" == "all" ]; then
        for s in redis kafka mongo opensearch api; do
            start_target "$s"
        done
    else
        start_target "$SERVICE"
    fi
}

# Thực thi theo luồng
setup_time_sync
setup_swap
tune_kernel
if [ "$MODE" == "fresh" ]; then
    debloat_os
    install_docker
    setup_security
    harden_ssh
    setup_monitoring_and_maintenance
fi
start_service

echo "================================================================="
echo "🎉 HOÀN TẤT CÀI ĐẶT & GIA CỐ BẢO MẬT DỊCH VỤ $SERVICE!"
echo "👉 Cấu hình cảnh báo Telegram/Discord: /etc/sowfkun/alert.conf"
echo "👉 Kiểm tra trạng thái: docker compose ps"
echo "👉 Xem logs: docker compose logs -f"
echo "================================================================="
