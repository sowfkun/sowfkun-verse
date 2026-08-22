#!/usr/bin/env bash
set -eo pipefail

# ==============================================================================
# ENTERPRISE INFRASTRUCTURE BOOTSTRAP SCRIPT (Ubuntu 24.04 LTS)
# Supports: Redpanda (Kafka), Redis, MongoDB (Atlas Local), OpenSearch, Go API
# Usage:
#   sudo bash bootstrap.sh --service=redis --mode=fresh
#   sudo bash bootstrap.sh --service=redis,api --mode=fresh
#   sudo bash bootstrap.sh --services=mongo,redis,kafka --mode=fresh
#   sudo bash bootstrap.sh --service=all --mode=fresh
#   sudo bash bootstrap.sh (Interactive Multi-Select Menu)
# ==============================================================================

SERVICE_INPUT=""
MODE="fresh"
SWAP_SIZE_GB=2
APP_NETWORK="app_net"
SELECTED_SERVICES=()

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --service=*|--services=*) SERVICE_INPUT="${1#*=}" ;;
        --mode=*) MODE="${1#*=}" ;;
        -s|--service|--services) SERVICE_INPUT="$2"; shift ;;
        -m|--mode) MODE="$2"; shift ;;
        -i|--interactive) SERVICE_INPUT="interactive" ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
   echo "❌ Script này bắt buộc phải chạy dưới quyền root (sudo)!" 
   exit 1
fi

# Hàm hiển thị Interactive Menu khi không truyền tham số
interactive_menu() {
    echo "================================================================="
    echo "📋 CHỌN CÁC DỊCH VỤ CẦN CHẠY TRÊN VPS NÀY"
    echo "================================================================="
    echo "  1) Redis Cache (Port 6379)"
    echo "  2) MongoDB Atlas Local (Port 27017)"
    echo "  3) Redpanda / Kafka (Port 9092 / Console 8085)"
    echo "  4) OpenSearch (Port 9200)"
    echo "  5) Go API Backend (Port 8080)"
    echo "  6) Tất cả (All-in-One: Cài & chạy toàn bộ 5 dịch vụ)"
    echo "================================================================="
    echo "💡 Gợi ý: Nhập các số phân cách bằng dấu phẩy hoặc khoảng trắng (Ví dụ: 1,5 hoặc 1 2 5)"
    read -r -p "👉 Nhập lựa chọn của bạn [1-6]: " user_choices

    if [[ -z "$user_choices" ]]; then
        echo "❌ Lỗi: Bạn chưa chọn dịch vụ nào!"
        exit 1
    fi

    # Chuyển đổi số thành tên service
    for choice in $(echo "$user_choices" | tr ',' ' '); do
        case $choice in
            1) SELECTED_SERVICES+=("redis") ;;
            2) SELECTED_SERVICES+=("mongo") ;;
            3) SELECTED_SERVICES+=("kafka") ;;
            4) SELECTED_SERVICES+=("opensearch") ;;
            5) SELECTED_SERVICES+=("api") ;;
            6) SELECTED_SERVICES=("redis" "mongo" "kafka" "opensearch" "api"); break ;;
            *) echo "⚠️ Bỏ qua lựa chọn không hợp lệ: $choice" ;;
        esac
    done
}

# Parse danh sách service từ CLI input
if [[ -z "$SERVICE_INPUT" || "$SERVICE_INPUT" == "interactive" ]]; then
    interactive_menu
else
    # Chuẩn hóa chuỗi (thay dấu phẩy thành dấu cách)
    IFS=',' read -r -a raw_services <<< "$SERVICE_INPUT"
    for s in "${raw_services[@]}"; do
        trimmed_s=$(echo "$s" | tr -d '[:space:]')
        if [[ "$trimmed_s" == "all" ]]; then
            SELECTED_SERVICES=("redis" "mongo" "kafka" "opensearch" "api")
            break
        elif [[ "$trimmed_s" =~ ^(kafka|redis|mongo|opensearch|api)$ ]]; then
            SELECTED_SERVICES+=("$trimmed_s")
        else
            echo "❌ Lỗi: Service '$trimmed_s' không hợp lệ!"
            echo "Danh sách hợp lệ: redis, mongo, kafka, opensearch, api, all"
            exit 1
        fi
    done
fi

# Loại bỏ trùng lặp trong mảng SELECTED_SERVICES
SELECTED_SERVICES=($(echo "${SELECTED_SERVICES[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

if [[ ${#SELECTED_SERVICES[@]} -eq 0 ]]; then
    echo "❌ Lỗi: Không có service hợp lệ nào được chọn để khởi chạy!"
    exit 1
fi

# Tự động tăng Swap nếu chạy từ 3 service trở lên trên cùng 1 VPS
if [[ ${#SELECTED_SERVICES[@]} -ge 3 ]]; then
    SWAP_SIZE_GB=4
fi

SERVICES_DISPLAY=$(IFS=', '; echo "${SELECTED_SERVICES[*]}")

echo "================================================================="
echo "🚀 ENTERPRISE INFRA PROVISIONING & PRODUCTION HARDENING"
echo "👉 Target Services : [ $SERVICES_DISPLAY ]"
echo "👉 Mode            : $MODE"
echo "👉 Swap Size Guard : ${SWAP_SIZE_GB} GB"
echo "👉 Docker Network  : $APP_NETWORK"
echo "================================================================="

# 1. TIME SYNC & UTC TIMEZONE (Quan trọng cho JWT, E2EE, Kafka)
setup_time_sync() {
    echo "⏰ [1/9] Thiết lập đồng bộ thời gian chuẩn UTC và NTP..."
    timedatectl set-timezone UTC
    timedatectl set-ntp true
    echo "✅ Đã đồng bộ múi giờ UTC ($(date -u))"
}

# 2. SETUP SWAP FILE (Bảo vệ chống OOM Killer cho Server)
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
        echo "✅ Đã kích hoạt Swap File ${SWAP_SIZE_GB}GB thành công!"
    else
        echo "ℹ️ Swap file đã tồn tại, bỏ qua bước tạo Swap."
    fi
}

# 3. DEBLOAT & REMOVE UNNECESSARY SERVICES (Tối ưu RAM tối đa)
debloat_os() {
    echo "🧹 [3/9] Đang gỡ bỏ các service telemetry/bloatware ngầm (ModemManager, Multipath, Snapd, Udisks2)..."
    systemctl stop apport whoopsie ModemManager multipathd udisks2 2>/dev/null || true
    systemctl disable apport whoopsie ModemManager multipathd udisks2 2>/dev/null || true
    apt-get purge -y apport whoopsie modemmanager multipath-tools 2>/dev/null || true
    apt-get autoremove -y 2>/dev/null || true
    echo "✅ Đã debloat và dọn dẹp các tiến trình ngầm thừa thãi!"
}

# 4. KERNEL & LIMITS TUNING (Kafka, Redis, Mongo, OpenSearch, Outbound Network)
tune_kernel() {
    echo "⚡ [4/9] Đang cấu hình Kernel Sysctl, Limits & DNS Resolver..."
    
    cat << 'EOF' > /etc/sysctl.d/99-app-infra.conf
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

    cat << 'EOF' > /etc/security/limits.d/99-app-limits.conf
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
        usermod -aG docker ubuntu 2>/dev/null || true
        echo "✅ Đã cài đặt Docker và cấu hình Log Rotation thành công!"
    else
        echo "ℹ️ Docker đã được cài đặt sẵn."
        usermod -aG docker ubuntu 2>/dev/null || true
    fi

    # Tạo Shared Docker Network cho các container trên cùng VPS
    if ! docker network ls --format '{{.Name}}' | grep -wq "$APP_NETWORK"; then
        echo "🌐 Đang tạo Docker Network chung: $APP_NETWORK..."
        docker network create "$APP_NETWORK" > /dev/null
        echo "✅ Đã tạo network $APP_NETWORK thành công!"
    fi
}

# 6. CONFIGURE FIREWALL (UFW), FAIL2BAN & DOCKER SECURITY
setup_security() {
    echo "🛡️ [6/9] Đang thiết lập UFW Firewall, Fail2ban & Cấu hình Port Dịch Vụ..."
    systemctl enable fail2ban 2>/dev/null || true
    systemctl start fail2ban 2>/dev/null || true

    ufw default deny incoming
    ufw default allow outgoing
    
    # Cho phép SSH nội bộ hoặc quản lý qua Cloud Workbench
    ufw allow 22/tcp comment 'SSH Port'
    
    # Quét danh sách service để mở port tường lửa tương ứng
    for s in "${SELECTED_SERVICES[@]}"; do
        case "$s" in
            "api")
                ufw allow 8080/tcp comment 'Go API Port'
                ;;
            "mongo")
                ufw allow 27017/tcp comment 'MongoDB Atlas Local Port'
                ;;
            "redis")
                ufw allow 6379/tcp comment 'Redis Port'
                ;;
            "kafka")
                ufw allow 9092/tcp comment 'Kafka Internal Broker'
                ufw allow 9094/tcp comment 'Kafka External Broker'
                ufw allow 8085/tcp comment 'Redpanda Web Console'
                ;;
            "opensearch")
                ufw allow 9200/tcp comment 'OpenSearch HTTP API'
                ;;
        esac
    done

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
        cp "$SCRIPT_DIR/scripts/monitor.sh" /usr/local/bin/app-monitor.sh
        chmod +x /usr/local/bin/app-monitor.sh
    fi

    # Tạo thư mục config cảnh báo nếu chưa có
    mkdir -p /etc/infra
    if [ ! -f /etc/infra/alert.conf ] && [ -f "$SCRIPT_DIR/scripts/alert.conf.example" ]; then
        cp "$SCRIPT_DIR/scripts/alert.conf.example" /etc/infra/alert.conf
        echo "ℹ️ Đã tạo file cấu hình cảnh báo tại /etc/infra/alert.conf (Điền Telegram Token vào đây)"
    fi

    # Đăng ký Cron Job kiểm tra sức khỏe mỗi 5 phút + Dọn dẹp Docker rác 3h sáng Chủ Nhật
    cat << 'EOF' > /etc/cron.d/app-maintenance
# Kiểm tra RAM, Swap, Disk, Docker Crash mỗi 5 phút
*/5 * * * * root /usr/local/bin/app-monitor.sh > /dev/null 2>&1

# Dọn dẹp images/cache Docker thừa lúc 3h sáng Chủ Nhật hàng tuần
0 3 * * 0 root /usr/bin/docker system prune -af --volumes=false > /dev/null 2>&1
EOF
    chmod 644 /etc/cron.d/app-maintenance
    systemctl restart cron 2>/dev/null || true

    echo "✅ Đã đăng ký Cron Job giám sát sức khỏe & dọn dẹp Docker tự động!"
}

# 9. START DOCKER COMPOSE STACK
start_services() {
    echo "🚀 [9/9] Khởi chạy danh sách dịch vụ: [ $SERVICES_DISPLAY ] (Mode: $MODE)..."
    
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    BASE_DIR="$SCRIPT_DIR"

    # Đảm bảo Docker Network tồn tại trước khi compose up
    docker network create "$APP_NETWORK" 2>/dev/null || true

    start_target() {
        local target=$1
        local target_dir="$BASE_DIR/$target"
        
        if [ ! -d "$target_dir" ]; then
            echo "❌ Không tìm thấy thư mục: $target_dir"
            return 1
        fi

        cd "$target_dir"
        
        # Thiết lập quyền ghi volume cho MongoDB nếu cần
        if [ "$target" == "mongo" ]; then
            mkdir -p data/db data/configdb
            chmod -R 777 data 2>/dev/null || true
        fi

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

    for s in "${SELECTED_SERVICES[@]}"; do
        echo "-----------------------------------------------------------------"
        echo "▶️ Đang khởi chạy: $s"
        echo "-----------------------------------------------------------------"
        start_target "$s"
    done
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
else
    # Rollback mode: vẫn đảm bảo docker network tồn tại
    docker network create "$APP_NETWORK" 2>/dev/null || true
fi
start_services

echo "================================================================="
echo "🎉 HOÀN TẤT CÀI ĐẶT & GIA CỐ BẢO MẬT CÁC DỊCH VỤ: [ $SERVICES_DISPLAY ]!"
echo "👉 Cấu hình cảnh báo Telegram/Discord: /etc/infra/alert.conf"
echo "👉 Kiểm tra tất cả container: docker ps"
echo "👉 Mạng Docker nội bộ: $APP_NETWORK"
echo "================================================================="
