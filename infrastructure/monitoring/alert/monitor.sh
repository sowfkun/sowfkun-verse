#!/usr/bin/env bash
# ==============================================================================
# ENTERPRISE SERVER HEALTH & ALERT MONITOR (Unified Old & New Standard)
# Supports: 
#   - Telegram Bot (Direct & Egress Forwarder via Core)
#   - Discord Webhooks
#   - 3-Hour Periodic Infrastructure Summary Report
#   - Realtime Danger Check (CPU, RAM, Swap, Disk, Docker) with Anti-Spam & Recovery
# ==============================================================================
set -eo pipefail

# Nạp file cấu hình
for conf_path in "/etc/infra/alert.conf" "/etc/app/alert.conf" "/etc/system-alert.env" "./alert.conf"; do
    if [[ -f "$conf_path" ]]; then
        # shellcheck disable=SC1090
        source "$conf_path"
        break
    fi
done

# Cấu hình mặc định
SERVER_NAME="${SERVER_NAME:-$(hostname)}"
SERVER_ROLE="${SERVER_ROLE:-General Server}"
SERVER_IP="${SERVER_IP:-$(hostname -I 2>/dev/null | awk '{print $1}' || echo '127.0.0.1')}"

CPU_THRESHOLD="${CPU_THRESHOLD:-85}"
RAM_THRESHOLD="${RAM_THRESHOLD:-85}"
SWAP_THRESHOLD="${SWAP_THRESHOLD:-70}"
DISK_THRESHOLD="${DISK_THRESHOLD:-85}"

ALERT_FORWARD_URL="${ALERT_FORWARD_URL:-}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"
DISCORD_WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-}"
PERIODIC_DELAY_SECONDS="${PERIODIC_DELAY_SECONDS:-0}"
SEND_DIVIDER="${SEND_DIVIDER:-false}"

STATE_DIR="/var/run/app-monitor"
mkdir -p "$STATE_DIR"
ALERT_FLAG="$STATE_DIR/last_alert_time"
COOLDOWN_SECONDS="${COOLDOWN_SECONDS:-1800}" # 30 phút chống spam

MODE="${1:-check}" # "check" (Danger check 1m) hoặc "periodic" (Báo cáo 3h)

# 1. Thu thập CPU Usage %
get_cpu_usage() {
    if command -v mpstat >/dev/null 2>&1; then
        mpstat 1 1 | awk '/Average:/ {printf "%.1f", 100 - $NF}'
    else
        top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{printf "%.1f", 100 - $1}'
    fi
}

# 2. Thu thập RAM Usage (MB và %)
get_ram_usage() {
    free -m | awk '/Mem:/ {printf "%d %d %.1f", $3, $2, ($3/$2)*100}'
}

# 3. Thu thập SWAP Usage (MB và %)
get_swap_usage() {
    free -m | awk '/Swap:/ {if ($2 > 0) printf "%d %d %.1f", $3, $2, ($3/$2)*100; else print "0 0 0.0"}'
}

# 4. Thu thập Disk Usage của Root Partition (GB và %)
get_disk_usage() {
    df -h / | awk 'NR==2 {gsub("%","",$5); printf "%s %s %d", $3, $2, $5}'
}

# 5. Thu thập Docker Containers Status
get_docker_status() {
    if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
        local running_cnt
        local total_cnt
        local unhealthy
        running_cnt=$(docker ps -q 2>/dev/null | wc -l || echo 0)
        total_cnt=$(docker ps -aq 2>/dev/null | wc -l || echo 0)
        unhealthy=$(docker ps -a --filter "status=exited" --filter "status=dead" --filter "status=restarting" --format "• {{.Names}} ({{.Status}})" 2>/dev/null || true)
        
        echo "${running_cnt}|${total_cnt}|${unhealthy}"
    else
        echo "N/A|N/A|"
    fi
}

# Hàm dispatch alert đa kênh (Telegram qua Core Forwarder / Direct Telegram / Discord)
dispatch_alert() {
    local alert_level="$1"
    local alert_title="$2"
    local alert_html="$3"
    local timestamp_tz
    timestamp_tz=$(TZ='Asia/Ho_Chi_Minh' date "+%d/%m/%Y %H:%M:%S (GMT+7)")

    # 1. Kênh Telegram qua Core API Forwarder (cho các Node nội bộ như Server 1)
    if [[ -n "$ALERT_FORWARD_URL" ]]; then
        local json_html
        json_html=$(python3 -c "import json, sys; print(json.dumps(sys.argv[1]))" "$alert_html" 2>/dev/null || echo "\"$alert_html\"")
        local payload="{\"server_name\": \"${SERVER_NAME}\", \"role\": \"${SERVER_ROLE}\", \"type\": \"${alert_level}\", \"title\": \"${alert_title}\", \"raw_html\": ${json_html}}"
        curl -s --connect-timeout 5 --max-time 15 -X POST "${ALERT_FORWARD_URL}" \
            -H "Content-Type: application/json" \
            -d "${payload}" >/dev/null 2>&1 || true

    # 2. Kênh Telegram trực tiếp (cho Server 2 / Server 3 / Gateway)
    elif [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
        local json_html
        json_html=$(python3 -c "import json, sys; print(json.dumps(sys.argv[1]))" "$alert_html" 2>/dev/null || echo "\"$alert_html\"")
        local tg_url="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"
        local payload="{\"chat_id\": \"${TELEGRAM_CHAT_ID}\", \"text\": ${json_html}, \"parse_mode\": \"HTML\", \"disable_web_page_preview\": true}"
        curl -s --connect-timeout 5 --max-time 15 -X POST "${tg_url}" \
            -H "Content-Type: application/json" \
            -d "${payload}" >/dev/null 2>&1 || true
    fi

    # 3. Kênh Discord Webhook (Kế thừa từ alert cũ)
    if [[ -n "$DISCORD_WEBHOOK_URL" ]]; then
        local color=16711680 # Red
        if [[ "$alert_level" == "RECOVERED" || "$alert_level" == "PERIODIC" ]]; then color=65280; fi # Green
        if [[ "$alert_level" == "WARNING" ]]; then color=16776960; fi # Yellow

        local plain_msg
        plain_msg=$(echo "$alert_html" | sed -e 's/<[^>]*>//g')
        local discord_json
        discord_json=$(python3 -c "import json, sys; print(json.dumps({'embeds': [{'title': sys.argv[1], 'description': sys.argv[2], 'color': int(sys.argv[3]), 'fields': [{'name': 'Server', 'value': sys.argv[4], 'inline': True}, {'name': 'Role', 'value': sys.argv[5], 'inline': True}, {'name': 'Time', 'value': sys.argv[6], 'inline': False}]}]}))" "$alert_title" "$plain_msg" "$color" "$SERVER_NAME" "$SERVER_ROLE" "$timestamp_tz" 2>/dev/null || true)

        if [[ -n "$discord_json" ]]; then
            curl -s --connect-timeout 5 --max-time 15 -H "Content-Type: application/json" -X POST -d "$discord_json" "$DISCORD_WEBHOOK_URL" >/dev/null 2>&1 || true
        fi
    fi
}

get_status_icon() {
    local val="$1"
    local threshold="$2"
    if (( $(echo "$val >= $threshold" | bc -l 2>/dev/null || echo 0) )); then
        echo "🔴"
    elif (( $(echo "$val >= $threshold - 15" | bc -l 2>/dev/null || echo 0) )); then
        echo "🟡"
    else
        echo "🟢"
    fi
}

# Thu thập dữ liệu
CPU_VAL=$(get_cpu_usage || echo "0.0")
read -r RAM_USED_MB RAM_TOTAL_MB RAM_VAL <<< "$(get_ram_usage || echo '0 0 0.0')"
read -r SWAP_USED_MB SWAP_TOTAL_MB SWAP_VAL <<< "$(get_swap_usage || echo '0 0 0.0')"
read -r DISK_USED_GB DISK_TOTAL_GB DISK_VAL <<< "$(get_disk_usage || echo '0 0 0')"

DOCKER_RAW=$(get_docker_status)
RUNNING_CONTAINERS=$(echo "$DOCKER_RAW" | cut -d'|' -f1)
TOTAL_CONTAINERS=$(echo "$DOCKER_RAW" | cut -d'|' -f2)
UNHEALTHY_CONTAINERS=$(echo "$DOCKER_RAW" | cut -d'|' -f3-)

CURRENT_TIME_TZ=$(TZ='Asia/Ho_Chi_Minh' date "+%d/%m/%Y %H:%M:%S (GMT+7)")

# ==============================================================================
# CHẾ ĐỘ 1: BÁO CÁO ĐỊNH KỲ (PERIODIC SUMMARY - 3 TIẾNG/LẦN)
# ==============================================================================
if [[ "$MODE" == "periodic" ]]; then
    if [[ "$PERIODIC_DELAY_SECONDS" -gt 0 ]]; then
        sleep "$PERIODIC_DELAY_SECONDS"
    fi

    CPU_ICON=$(get_status_icon "$CPU_VAL" "$CPU_THRESHOLD")
    RAM_ICON=$(get_status_icon "$RAM_VAL" "$RAM_THRESHOLD")
    SWAP_ICON=$(get_status_icon "$SWAP_VAL" "$SWAP_THRESHOLD")
    DISK_ICON=$(get_status_icon "$DISK_VAL" "$DISK_THRESHOLD")

    CONTAINER_STATUS_TEXT="• <b>Containers:</b> ${RUNNING_CONTAINERS}/${TOTAL_CONTAINERS} Running 🟢"
    if [[ -n "$UNHEALTHY_CONTAINERS" ]]; then
        CONTAINER_STATUS_TEXT="• <b>Containers:</b> ${RUNNING_CONTAINERS}/${TOTAL_CONTAINERS} Running ⚠️\n<i>Chi tiết lỗi:</i>\n${UNHEALTHY_CONTAINERS}"
    fi

    REPORT_HTML="🔵 <b>[${SERVER_NAME}] BÁO CÁO HẠ TẦNG ĐỊNH KỲ (3H)</b>

🏷️ <b>Node:</b> <code>${SERVER_NAME}</code> (<code>${SERVER_IP}</code>)
🎭 <b>Vai Trò:</b> ${SERVER_ROLE}
⏰ <b>Thời Gian:</b> ${CURRENT_TIME_TZ}

💻 <b>Tài Nguyên Máy Chủ:</b>
• <b>CPU:</b> ${CPU_VAL}% ${CPU_ICON}
• <b>RAM:</b> ${RAM_USED_MB}MB / ${RAM_TOTAL_MB}MB (${RAM_VAL}%) ${RAM_ICON}
• <b>Swap:</b> ${SWAP_USED_MB}MB / ${SWAP_TOTAL_MB}MB (${SWAP_VAL}%) ${SWAP_ICON}
• <b>Disk (/):</b> ${DISK_USED_GB} / ${DISK_TOTAL_GB} (${DISK_VAL}%) ${DISK_ICON}

🐳 <b>Dịch Vụ Docker:</b>
${CONTAINER_STATUS_TEXT}

🟢 <b>Trạng Thái Chung:</b> <code>HOẠT ĐỘNG ỔN ĐỊNH</code>"

    dispatch_alert "PERIODIC" "Báo Cáo Định Kỳ 3H" "$REPORT_HTML"
    echo "🔵 Đã gửi Báo cáo hạ tầng định kỳ 3H."

    if [[ "$SEND_DIVIDER" == "true" ]]; then
        sleep 2
        dispatch_alert "DIVIDER" "Divider" "----------------------------------------"
        echo "➖ Đã gửi tin nhắn ngăn cách divider."
    fi

    exit 0
fi

# ==============================================================================
# CHẾ ĐỘ 2: CẢNH BÁO NGUY HIỂM & CHỐNG SPAM (DANGER CHECK - 1 PHÚT/LẦN)
# ==============================================================================
DANGER_REASONS=()

if (( $(echo "$CPU_VAL >= $CPU_THRESHOLD" | bc -l 2>/dev/null || echo 0) )); then
    DANGER_REASONS+=("• 🔴 <b>CPU quá tải:</b> ${CPU_VAL}% (Ngưỡng: ${CPU_THRESHOLD}%)")
fi

if (( $(echo "$RAM_VAL >= $RAM_THRESHOLD" | bc -l 2>/dev/null || echo 0) )); then
    DANGER_REASONS+=("• 🔴 <b>RAM quá tải:</b> ${RAM_USED_MB}MB / ${RAM_TOTAL_MB}MB (${RAM_VAL}%) (Ngưỡng: ${RAM_THRESHOLD}%)")
fi

if (( $(echo "$SWAP_VAL >= $SWAP_THRESHOLD" | bc -l 2>/dev/null || echo 0) )) && [ "$SWAP_TOTAL_MB" -gt 0 ]; then
    DANGER_REASONS+=("• 🔴 <b>Swap quá tải:</b> ${SWAP_USED_MB}MB / ${SWAP_TOTAL_MB}MB (${SWAP_VAL}%) (Ngưỡng: ${SWAP_THRESHOLD}%)")
fi

if (( $(echo "$DISK_VAL >= $DISK_THRESHOLD" | bc -l 2>/dev/null || echo 0) )); then
    DANGER_REASONS+=("• 🔴 <b>Ổ cứng sắp đầy:</b> ${DISK_USED_GB} / ${DISK_TOTAL_GB} (${DISK_VAL}%) (Ngưỡng: ${DISK_THRESHOLD}%)")
fi

if [[ -n "$UNHEALTHY_CONTAINERS" && "$RUNNING_CONTAINERS" != "N/A" ]]; then
    DANGER_REASONS+=("• ⚠️ <b>Container dừng/lỗi:</b>\n${UNHEALTHY_CONTAINERS}")
fi

NOW_TS=$(date +%s)
LAST_ALERT_TS=0
WAS_IN_DANGER=false

if [[ -f "$ALERT_FLAG" ]]; then
    WAS_IN_DANGER=true
    LAST_ALERT_TS=$(cat "$ALERT_FLAG" 2>/dev/null || echo 0)
fi

# TRƯỜNG HỢP A: CÓ NGUY HIỂM
if [[ ${#DANGER_REASONS[@]} -gt 0 ]]; then
    DIFF_TS=$((NOW_TS - LAST_ALERT_TS))

    if [[ "$WAS_IN_DANGER" != "true" || $DIFF_TS -ge $COOLDOWN_SECONDS ]]; then
        DANGER_LIST_STR=$(printf "%s\n" "${DANGER_REASONS[@]}")

        DANGER_HTML="🚨 <b>[${SERVER_NAME}] CẢNH BÁO NGUY HIỂM HẠ TẦNG!</b>

🏷️ <b>Node:</b> <code>${SERVER_NAME}</code> (<code>${SERVER_IP}</code>)
🎭 <b>Vai Trò:</b> ${SERVER_ROLE}
⏰ <b>Thời Gian:</b> ${CURRENT_TIME_TZ}

⚠️ <b>Chi Tiết Phát Hiện:</b>
${DANGER_LIST_STR}

📊 <b>Thông Số Hiện Tại:</b>
• CPU: ${CPU_VAL}% (Ngưỡng: ${CPU_THRESHOLD}%)
• RAM: ${RAM_USED_MB}MB / ${RAM_TOTAL_MB}MB (${RAM_VAL}%) (Ngưỡng: ${RAM_THRESHOLD}%)
• Swap: ${SWAP_USED_MB}MB / ${SWAP_TOTAL_MB}MB (${SWAP_VAL}%) (Ngưỡng: ${SWAP_THRESHOLD}%)
• Disk: ${DISK_USED_GB} / ${DISK_TOTAL_GB} (${DISK_VAL}%) (Ngưỡng: ${DISK_THRESHOLD}%)
• Containers: ${RUNNING_CONTAINERS}/${TOTAL_CONTAINERS} Running

🛑 <i>Vui lòng kiểm tra và xử lý ngay!</i>"

        dispatch_alert "DANGER" "Cảnh Báo Nguy Hiểm" "$DANGER_HTML"
        echo "$NOW_TS" > "$ALERT_FLAG"
        echo "🚨 Đã gửi cảnh báo nguy hiểm."
    else
        echo "⚠️ Có cảnh báo nhưng đang trong thời gian giãn cách chống spam ($(( (COOLDOWN_SECONDS - DIFF_TS) / 60 )) phút còn lại)."
    fi

# TRƯỜNG HỢP B: ĐÃ HẠ NHIỆT VỀ BÌNH THƯỜNG (RECOVERY)
elif [[ "$WAS_IN_DANGER" == "true" ]]; then
    RECOVERY_HTML="🟢 <b>[${SERVER_NAME}] HỆ THỐNG ĐÃ PHỤC HỒI BÌNH THƯỜNG</b>

🏷️ <b>Node:</b> <code>${SERVER_NAME}</code> (<code>${SERVER_IP}</code>)
🎭 <b>Vai Trò:</b> ${SERVER_ROLE}
⏰ <b>Thời Gian:</b> ${CURRENT_TIME_TZ}

✅ Toàn bộ tài nguyên và container đã trở lại mức an toàn!
• <b>CPU:</b> ${CPU_VAL}% 🟢
• <b>RAM:</b> ${RAM_USED_MB}MB / ${RAM_TOTAL_MB}MB (${RAM_VAL}%) 🟢
• <b>Swap:</b> ${SWAP_USED_MB}MB / ${SWAP_TOTAL_MB}MB (${SWAP_VAL}%) 🟢
• <b>Disk (/):</b> ${DISK_USED_GB} / ${DISK_TOTAL_GB} (${DISK_VAL}%) 🟢
• <b>Containers:</b> ${RUNNING_CONTAINERS}/${TOTAL_CONTAINERS} Running 🟢"

    dispatch_alert "RECOVERY" "Hệ Thống Phục Hồi" "$RECOVERY_HTML"
    rm -f "$ALERT_FLAG"
    echo "✅ Hệ thống phục hồi bình thường. Đã gửi tin nhắn Recovery."
else
    echo "✅ Tất cả thông số hạ tầng đều khỏe mạnh."
fi
