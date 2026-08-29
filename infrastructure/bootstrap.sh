#!/usr/bin/env bash
set -eo pipefail

# ==============================================================================
# ENTERPRISE INFRASTRUCTURE BOOTSTRAP SCRIPT (Ubuntu 24.04 LTS)
# Supports: Redpanda (Kafka), Redis, MongoDB (Atlas Local), OpenSearch, Go API
# Resource Profiles: mini (1-2GB RAM), standard (2-4GB RAM), huge (4-8GB+ RAM)
# Usage:
#   sudo bash bootstrap.sh --service=redis --profile=mini --mode=fresh
#   sudo bash bootstrap.sh --service=redis,api --profile=mini --mode=fresh
#   sudo bash bootstrap.sh --services=mongo,redis,kafka --profile=huge --mode=fresh
#   sudo bash bootstrap.sh --service=all --profile=mini --mode=fresh
#   sudo bash bootstrap.sh (Interactive Multi-Select Menu)
# ==============================================================================

SERVICE_INPUT=""
PROFILE_INPUT=""
API_MODE_INPUT=""
API_MODE="binary"
GITHUB_RUNNER_TOKEN=""
GITHUB_REPO="https://github.com/sowfkun/sowfkun-verse"
MODE="fresh"
PROFILE="standard"
SWAP_SIZE_GB=2
APP_NETWORK="app_net"
SELECTED_SERVICES=()

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --service=*|--services=*) SERVICE_INPUT="${1#*=}" ;;
        --profile=*|--prof=*) PROFILE_INPUT="${1#*=}" ;;
        --api-mode=*|--api-type=*) API_MODE_INPUT="${1#*=}" ;;
        --github-token=*|--gh-token=*|--github-runner-token=*) GITHUB_RUNNER_TOKEN="${1#*=}" ;;
        --github-repo=*|--gh-repo=*) GITHUB_REPO="${1#*=}" ;;
        --mode=*) MODE="${1#*=}" ;;
        -s|--service|--services) SERVICE_INPUT="$2"; shift ;;
        -p|--profile|--prof) PROFILE_INPUT="$2"; shift ;;
        --api-mode|--api-type) API_MODE_INPUT="$2"; shift ;;
        --gh-token|--github-token) GITHUB_RUNNER_TOKEN="$2"; shift ;;
        --gh-repo|--github-repo) GITHUB_REPO="$2"; shift ;;
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

    # Chọn Resource Profile
    if [[ -z "$PROFILE_INPUT" ]]; then
        echo "================================================================="
        echo "⚙️ CHỌN HỒ SƠ TẢI TRỌNG (RESOURCE PROFILE)"
        echo "================================================================="
        echo "  1) Mini     (VPS 1-2GB RAM / Test GCP Free / Swap 4GB / Tiết kiệm RAM tối đa)"
        echo "  2) Standard (VPS 2-4GB RAM / Cân đối tài nguyên & hiệu năng)"
        echo "  3) Huge     (Server 4-8 Cores, 4-8GB+ RAM / Tối đa hiệu năng cho Production)"
        echo "================================================================="
        read -r -p "👉 Nhập lựa chọn Profile [1-3] (Mặc định: 1 - Mini): " profile_choice
        case "$profile_choice" in
            2|standard|Standard) PROFILE="standard" ;;
            3|huge|Huge) PROFILE="huge" ;;
            *) PROFILE="mini" ;;
        esac
    fi

    # Kiểm tra nếu có service api được chọn thì hỏi API Mode
    local has_api=false
    for s in "${SELECTED_SERVICES[@]}"; do
        if [ "$s" == "api" ]; then has_api=true; break; fi
    done

    if [ "$has_api" = true ] && [ -z "$API_MODE_INPUT" ]; then
        echo "================================================================="
        echo "📦 CHỌN PHƯƠNG THỨC TRIỂN KHAI GO API BACKEND"
        echo "================================================================="
        echo "  1) Binary (On-Premise: Chạy từ file thực thi app-api có sẵn)"
        echo "  2) Source (Build từ mã nguồn Go sowfkun-verse-api)"
        echo "================================================================="
        read -r -p "👉 Nhập lựa chọn [1-2] (Mặc định: 1 - Binary): " api_choice
        case "$api_choice" in
            2|source|Source) API_MODE="source" ;;
            *) API_MODE="binary" ;;
        esac
    fi

    # Cấu hình GitHub Actions Runner nếu có
    if [[ -z "$GITHUB_RUNNER_TOKEN" ]]; then
        echo "================================================================="
        echo "🤖 TỰ ĐỘNG HÓA CI/CD VỚI GITHUB ACTIONS RUNNER"
        echo "================================================================="
        read -r -p "👉 Nhập GitHub Runner Registration Token (Nhấn Enter để bỏ qua): " gh_token_input
        if [[ -n "$gh_token_input" ]]; then
            GITHUB_RUNNER_TOKEN="$gh_token_input"
        fi
    fi
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

# Xử lý Profile nếu được truyền qua CLI
if [[ -n "$PROFILE_INPUT" ]]; then
    case "$PROFILE_INPUT" in
        mini|Mini|MINI) PROFILE="mini" ;;
        huge|Huge|HUGE) PROFILE="huge" ;;
        standard|Standard|STANDARD) PROFILE="standard" ;;
        *)
            echo "⚠️ Profile '$PROFILE_INPUT' không hợp lệ (hợp lệ: mini, standard, huge). Sử dụng mặc định: standard."
            PROFILE="standard"
            ;;
    esac
fi

# Xử lý API Mode nếu được truyền qua CLI
if [[ -n "$API_MODE_INPUT" ]]; then
    case "$API_MODE_INPUT" in
        source|Source|src) API_MODE="source" ;;
        binary|Binary|bin) API_MODE="binary" ;;
        *)
            echo "⚠️ API Mode '$API_MODE_INPUT' không hợp lệ (hợp lệ: binary, source). Mặc định sử dụng: binary."
            API_MODE="binary"
            ;;
    esac
fi

# Loại bỏ trùng lặp trong mảng SELECTED_SERVICES
SELECTED_SERVICES=($(echo "${SELECTED_SERVICES[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

if [[ ${#SELECTED_SERVICES[@]} -eq 0 ]]; then
    echo "❌ Lỗi: Không có service hợp lệ nào được chọn để khởi chạy!"
    exit 1
fi

# Cấu hình Swap và tài nguyên theo Profile
case "$PROFILE" in
    mini)
        SWAP_SIZE_GB=4
        ;;
    huge)
        SWAP_SIZE_GB=2
        if [[ ${#SELECTED_SERVICES[@]} -ge 3 ]]; then
            SWAP_SIZE_GB=4
        fi
        ;;
    standard)
        SWAP_SIZE_GB=2
        if [[ ${#SELECTED_SERVICES[@]} -ge 3 ]]; then
            SWAP_SIZE_GB=4
        fi
        ;;
esac

SERVICES_DISPLAY=$(IFS=', '; echo "${SELECTED_SERVICES[*]}")

echo "================================================================="
echo "🚀 ENTERPRISE INFRA PROVISIONING & PRODUCTION HARDENING"
echo "👉 Target Services : [ $SERVICES_DISPLAY ]"
echo "👉 Resource Profile: [ $PROFILE ]"
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
        # Phân quyền cho tất cả regular users trên hệ điều hành vào nhóm docker
        if [ -n "$SUDO_USER" ]; then
            usermod -aG docker "$SUDO_USER" 2>/dev/null || true
        fi
        for u in $(awk -F: '$3 >= 1000 && $3 < 60000 {print $1}' /etc/passwd); do
            usermod -aG docker "$u" 2>/dev/null || true
        done
        echo "✅ Đã cài đặt Docker và cấu hình Log Rotation thành công!"
    else
        echo "ℹ️ Docker đã được cài đặt sẵn."
        if [ -n "$SUDO_USER" ]; then
            usermod -aG docker "$SUDO_USER" 2>/dev/null || true
        fi
        for u in $(awk -F: '$3 >= 1000 && $3 < 60000 {print $1}' /etc/passwd); do
            usermod -aG docker "$u" 2>/dev/null || true
        done
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
    echo "🚀 [9/9] Khởi chạy danh sách dịch vụ: [ $SERVICES_DISPLAY ] (Profile: $PROFILE, Mode: $MODE)..."
    
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    BASE_DIR="$SCRIPT_DIR"

    # Đảm bảo Docker Network tồn tại trước khi compose up
    docker network create "$APP_NETWORK" 2>/dev/null || true

    set_env_kv() {
        local env_file="$1"
        local key="$2"
        local val="$3"
        if grep -q "^${key}=" "$env_file" 2>/dev/null; then
            sed -i "s|^${key}=.*|${key}=${val}|" "$env_file"
        else
            echo "${key}=${val}" >> "$env_file"
        fi
    }

    apply_profile_to_target() {
        local target=$1
        local env_file="$BASE_DIR/$target/.env"
        
        if [ ! -f "$env_file" ]; then
            return 0
        fi

        echo "⚙️ Tinh chỉnh thông số [$PROFILE] cho $target..."
        case "$target" in
            mongo)
                case "$PROFILE" in
                    mini)     set_env_kv "$env_file" "MONGO_CONTAINER_MEMORY_LIMIT" "400M" ;;
                    huge)     set_env_kv "$env_file" "MONGO_CONTAINER_MEMORY_LIMIT" "2560M" ;;
                    standard) set_env_kv "$env_file" "MONGO_CONTAINER_MEMORY_LIMIT" "750M" ;;
                esac
                ;;
            redis)
                case "$PROFILE" in
                    mini)
                        set_env_kv "$env_file" "REDIS_MAX_MEMORY" "128mb"
                        set_env_kv "$env_file" "REDIS_CONTAINER_MEMORY_LIMIT" "200M"
                        ;;
                    huge)
                        set_env_kv "$env_file" "REDIS_MAX_MEMORY" "1536mb"
                        set_env_kv "$env_file" "REDIS_CONTAINER_MEMORY_LIMIT" "2048M"
                        ;;
                    standard)
                        set_env_kv "$env_file" "REDIS_MAX_MEMORY" "512mb"
                        set_env_kv "$env_file" "REDIS_CONTAINER_MEMORY_LIMIT" "600M"
                        ;;
                esac
                ;;
            kafka)
                case "$PROFILE" in
                    mini)
                        set_env_kv "$env_file" "REDPANDA_SMP" "1"
                        set_env_kv "$env_file" "REDPANDA_MEMORY" "256M"
                        set_env_kv "$env_file" "REDPANDA_CONTAINER_MEMORY_LIMIT" "380M"
                        set_env_kv "$env_file" "CONSOLE_CONTAINER_MEMORY_LIMIT" "100M"
                        ;;
                    huge)
                        set_env_kv "$env_file" "REDPANDA_SMP" "2"
                        set_env_kv "$env_file" "REDPANDA_MEMORY" "1536M"
                        set_env_kv "$env_file" "REDPANDA_CONTAINER_MEMORY_LIMIT" "2048M"
                        set_env_kv "$env_file" "CONSOLE_CONTAINER_MEMORY_LIMIT" "256M"
                        ;;
                    standard)
                        set_env_kv "$env_file" "REDPANDA_SMP" "1"
                        set_env_kv "$env_file" "REDPANDA_MEMORY" "512M"
                        set_env_kv "$env_file" "REDPANDA_CONTAINER_MEMORY_LIMIT" "600M"
                        set_env_kv "$env_file" "CONSOLE_CONTAINER_MEMORY_LIMIT" "150M"
                        ;;
                esac
                ;;
            opensearch)
                case "$PROFILE" in
                    mini)
                        set_env_kv "$env_file" "OPENSEARCH_JVM_HEAP" "\"-Xms256m -Xmx256m\""
                        set_env_kv "$env_file" "OPENSEARCH_CONTAINER_MEMORY_LIMIT" "450M"
                        ;;
                    huge)
                        set_env_kv "$env_file" "OPENSEARCH_JVM_HEAP" "\"-Xms1536m -Xmx1536m\""
                        set_env_kv "$env_file" "OPENSEARCH_CONTAINER_MEMORY_LIMIT" "2048M"
                        ;;
                    standard)
                        set_env_kv "$env_file" "OPENSEARCH_JVM_HEAP" "\"-Xms384m -Xmx384m\""
                        set_env_kv "$env_file" "OPENSEARCH_CONTAINER_MEMORY_LIMIT" "650M"
                        ;;
                esac
                ;;
            api)
                case "$PROFILE" in
                    mini)
                        set_env_kv "$env_file" "API_CONTAINER_MEMORY_LIMIT" "200M"
                        set_env_kv "$env_file" "MONGO_MAX_POOL_SIZE" "15"
                        set_env_kv "$env_file" "MONGO_MIN_POOL_SIZE" "2"
                        set_env_kv "$env_file" "REDIS_GENERAL_POOL_SIZE" "15"
                        set_env_kv "$env_file" "REDIS_GENERAL_MIN_IDLE_CONNS" "2"
                        set_env_kv "$env_file" "OPENSEARCH_MAX_IDLE_CONNS" "20"
                        set_env_kv "$env_file" "OPENSEARCH_MAX_IDLE_CONNS_PER_HOST" "5"
                        set_env_kv "$env_file" "ASYNQ_WORKER_CONCURRENCY" "3"
                        set_env_kv "$env_file" "KAFKA_PRODUCER_BATCH_BYTES" "65536"
                        set_env_kv "$env_file" "KAFKA_PRODUCER_BATCH_SIZE" "200"
                        set_env_kv "$env_file" "KAFKA_PRODUCER_BATCH_TIMEOUT_MS" "20"
                        ;;
                    huge)
                        set_env_kv "$env_file" "API_CONTAINER_MEMORY_LIMIT" "1024M"
                        set_env_kv "$env_file" "MONGO_MAX_POOL_SIZE" "150"
                        set_env_kv "$env_file" "MONGO_MIN_POOL_SIZE" "15"
                        set_env_kv "$env_file" "REDIS_GENERAL_POOL_SIZE" "150"
                        set_env_kv "$env_file" "REDIS_GENERAL_MIN_IDLE_CONNS" "15"
                        set_env_kv "$env_file" "OPENSEARCH_MAX_IDLE_CONNS" "200"
                        set_env_kv "$env_file" "OPENSEARCH_MAX_IDLE_CONNS_PER_HOST" "50"
                        set_env_kv "$env_file" "ASYNQ_WORKER_CONCURRENCY" "20"
                        set_env_kv "$env_file" "KAFKA_PRODUCER_BATCH_BYTES" "1048576"
                        set_env_kv "$env_file" "KAFKA_PRODUCER_BATCH_SIZE" "1000"
                        set_env_kv "$env_file" "KAFKA_PRODUCER_BATCH_TIMEOUT_MS" "5"
                        ;;
                    standard)
                        set_env_kv "$env_file" "API_CONTAINER_MEMORY_LIMIT" "400M"
                        set_env_kv "$env_file" "MONGO_MAX_POOL_SIZE" "50"
                        set_env_kv "$env_file" "MONGO_MIN_POOL_SIZE" "5"
                        set_env_kv "$env_file" "REDIS_GENERAL_POOL_SIZE" "50"
                        set_env_kv "$env_file" "REDIS_GENERAL_MIN_IDLE_CONNS" "5"
                        set_env_kv "$env_file" "OPENSEARCH_MAX_IDLE_CONNS" "50"
                        set_env_kv "$env_file" "OPENSEARCH_MAX_IDLE_CONNS_PER_HOST" "10"
                        set_env_kv "$env_file" "ASYNQ_WORKER_CONCURRENCY" "10"
                        set_env_kv "$env_file" "KAFKA_PRODUCER_BATCH_BYTES" "524288"
                        set_env_kv "$env_file" "KAFKA_PRODUCER_BATCH_SIZE" "500"
                        set_env_kv "$env_file" "KAFKA_PRODUCER_BATCH_TIMEOUT_MS" "10"
                        ;;
                esac
                ;;
        esac
    }

    start_target() {
        local target=$1
        local target_dir="$BASE_DIR/$target"
        
        if [ ! -d "$target_dir" ]; then
            echo "❌ Không tìm thấy thư mục: $target_dir"
            return 1
        fi

        cd "$target_dir"
        
        # Thiết lập quyền ghi volume cho các services nếu cần
        mkdir -p data
        if [ "$target" == "mongo" ]; then
            mkdir -p data/db data/configdb
            chmod -R 777 data/db 2>/dev/null || true
            chmod 755 data/configdb 2>/dev/null || true
            chown -R 1000:1000 data/configdb 2>/dev/null || true
            chmod 400 data/configdb/* 2>/dev/null || true
        else
            chmod -R 777 data 2>/dev/null || true
        fi

        # Tự động tạo .env từ .env.$PROFILE hoặc .env.example nếu chưa có
        if [ ! -f .env ]; then
            if [ -f ".env.$PROFILE" ]; then
                echo "📄 Tạo file .env từ .env.$PROFILE (Profile: $PROFILE) cho $target..."
                cp ".env.$PROFILE" .env
            elif [ -f .env.example ]; then
                echo "📄 Tạo file .env từ .env.example cho $target..."
                cp .env.example .env
            fi
        fi

        # Áp dụng cấu hình Profile
        apply_profile_to_target "$target"

        if [ "$MODE" == "rollback" ]; then
            echo "🔄 Rollback mode: Resetting and restarting containers for $target..."
            docker compose down --remove-orphans 2>/dev/null || true
        fi

        if [ "$target" == "api" ]; then
            if [ "$API_MODE" == "binary" ]; then
                if [ ! -f "$target_dir/app-api" ]; then
                    echo "❌ Lỗi: Bạn đã chọn --api-mode=binary nhưng không tìm thấy file: $target_dir/app-api!"
                    echo "👉 Vui lòng biên dịch trước bằng './build_onpremise.sh' (hoặc '.\\build_onpremise.ps1')."
                    return 1
                fi
                chmod +x "$target_dir/app-api" 2>/dev/null || true
                echo "📦 Khởi chạy Go API ở chế độ [On-Premise Binary] (Dockerfile.binary)..."
                export API_BUILD_CONTEXT="."
                export API_DOCKERFILE="Dockerfile.binary"
            elif [ "$API_MODE" == "source" ]; then
                if [ ! -d "$BASE_DIR/../sowfkun-verse-api" ] && [ ! -d "$target_dir/../../sowfkun-verse-api" ]; then
                    echo "❌ Lỗi: Bạn đã chọn --api-mode=source nhưng không tìm thấy thư mục mã nguồn sowfkun-verse-api!"
                    return 1
                fi
                echo "🚀 Khởi chạy Go API ở chế độ [Build từ Source Code] (Dockerfile)..."
                export API_BUILD_CONTEXT="../../sowfkun-verse-api"
                export API_DOCKERFILE="Dockerfile"
            fi
            docker compose up -d --build
            
            # Tự động chuyển ENABLE_AUTO_INDEX_SYNC về false trong .env sau khi xác nhận API đã đồng bộ xong
            echo "⏳ Đang chờ API khởi tạo và hoàn tất đồng bộ index / topics..."
            local max_attempts=25
            local attempt=0
            local synced=false
            while [ $attempt -lt $max_attempts ]; do
                if docker logs "${API_CONTAINER_NAME:-app_api}" 2>&1 | grep -q "Kafka Topic Indexing completed successfully"; then
                    synced=true
                    break
                fi
                sleep 1
                attempt=$((attempt + 1))
            done

            if [ "$synced" == "true" ] && [ -f "$target_dir/.env" ]; then
                set_env_kv "$target_dir/.env" "ENABLE_AUTO_INDEX_SYNC" "false"
                echo "✅ Đã xác nhận hoàn tất đồng bộ! Tự động chuyển ENABLE_AUTO_INDEX_SYNC=false trong .env."
            elif [ -f "$target_dir/.env" ]; then
                echo "⚠️ Cảnh báo: Chưa nhận được xác nhận đồng bộ sau ${max_attempts}s. Giữ nguyên ENABLE_AUTO_INDEX_SYNC=true để thử lại ở lần khởi động sau."
            fi
        else
            echo "🚀 Đang kéo images và chạy $target container..."
            docker compose up -d
        fi
        docker compose ps
    }

    for s in "${SELECTED_SERVICES[@]}"; do
        echo "-----------------------------------------------------------------"
        echo "▶️ Đang khởi chạy: $s"
        echo "-----------------------------------------------------------------"
        start_target "$s"
    done
}

# 10. SETUP GITHUB ACTIONS SELF-HOSTED RUNNER (Optional)
setup_github_runner() {
    if [[ -z "$GITHUB_RUNNER_TOKEN" ]]; then
        echo "ℹ️ Bỏ qua cài đặt GitHub Actions Self-Hosted Runner (không cung cấp token)."
        return 0
    fi

    echo "================================================================="
    echo "🤖 [10/10] Đang cài đặt & cấu hình GitHub Actions Self-Hosted Runner..."
    echo "================================================================="

    local runner_user="${SUDO_USER:-$USER}"
    if [ "$runner_user" == "root" ]; then
        local found_user=$(awk -F: '$3 >= 1000 && $3 < 60000 {print $1; exit}' /etc/passwd)
        if [ -n "$found_user" ]; then
            runner_user="$found_user"
        fi
    fi

    local user_home=$(eval echo "~$runner_user")
    local runner_dir="$user_home/actions-runner"

    mkdir -p "$runner_dir"
    cd "$runner_dir"

    # Tải runner nếu chưa có
    if [ ! -f ./config.sh ]; then
        echo "📥 Đang tải GitHub Actions Runner package..."
        curl -o actions-runner-linux-x64-2.322.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.322.0/actions-runner-linux-x64-2.322.0.tar.gz
        tar xzf ./actions-runner-linux-x64-2.322.0.tar.gz
        rm -f actions-runner-linux-x64-2.322.0.tar.gz
    fi

    chown -R "$runner_user:$runner_user" "$runner_dir"

    echo "⚙️ Đang cấu hình GitHub Runner cho repository: $GITHUB_REPO..."
    sudo -u "$runner_user" ./config.sh --url "$GITHUB_REPO" --token "$GITHUB_RUNNER_TOKEN" --name "$(hostname)-runner" --labels self-hosted,linux,x64 --unattended --replace

    # Cài đặt service systemd chạy nền
    echo "🚀 Đang cài đặt Runner dưới dạng Systemd Daemon Service..."
    ./svc.sh install "$runner_user" 2>/dev/null || true
    ./svc.sh start 2>/dev/null || true

    echo "✅ GitHub Actions Self-Hosted Runner đã được cài đặt và đang chạy ngầm thành công!"
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
setup_github_runner

echo "================================================================="
echo "🎉 HOÀN TẤT CÀI ĐẶT & GIA CỐ BẢO MẬT CÁC DỊCH VỤ: [ $SERVICES_DISPLAY ]!"
echo "👉 Cấu hình cảnh báo Telegram/Discord: /etc/infra/alert.conf"
echo "👉 Kiểm tra tất cả container: docker ps"
echo "👉 Mạng Docker nội bộ: $APP_NETWORK"
echo "================================================================="
