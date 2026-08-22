#!/usr/bin/env bash
# ==============================================================================
# ENTERPRISE SERVER HEALTH & ALERT MONITOR (Ultra-Lightweight & Zero-Waste)
# Supports: Telegram Bot & Discord Webhook Alerts
# Checks: RAM (Threshold 85%), SWAP (Threshold 70%), Disk (Threshold 85%), 
#         Docker Container Health / Crashes.
# ==============================================================================

# Load Alert Configurations from /etc/infra/alert.conf if exists
ALERT_CONF="/etc/infra/alert.conf"
if [ ! -f "$ALERT_CONF" ] && [ -f "/etc/app/alert.conf" ]; then
    ALERT_CONF="/etc/app/alert.conf"
fi
if [ -f "$ALERT_CONF" ]; then
    # shellcheck source=/dev/null
    source "$ALERT_CONF"
fi

# Config Defaults (Override via /etc/infra/alert.conf)
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"
DISCORD_WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-}"
SERVER_NAME="${SERVER_NAME:-$(hostname)}"
RAM_THRESHOLD="${RAM_THRESHOLD:-85}"
SWAP_THRESHOLD="${SWAP_THRESHOLD:-70}"
DISK_THRESHOLD="${DISK_THRESHOLD:-85}"

STATE_DIR="/var/run/app-monitor"
mkdir -p "$STATE_DIR"
ALERT_FLAG="$STATE_DIR/last_alert_time"
COOLDOWN_SECONDS=1800 # 30 mins cooldown between repeated warnings

send_alert() {
    local level="$1"
    local title="$2"
    local message="$3"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

    # 1. Telegram Notification
    if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
        local tg_icon="🚨"
        if [ "$level" == "RECOVERED" ]; then tg_icon="✅"; fi
        if [ "$level" == "WARNING" ]; then tg_icon="⚠️"; fi

        local tg_text="${tg_icon} <b>[System Alert - ${level}]</b>%0A"
        tg_text+="<b>Server:</b> <code>${SERVER_NAME}</code>%0A"
        tg_text+="<b>Time:</b> <code>${timestamp}</code>%0A%0A"
        tg_text+="<b>${title}</b>%0A"
        tg_text+="${message}"

        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d "chat_id=${TELEGRAM_CHAT_ID}" \
            -d "text=${tg_text}" \
            -d "parse_mode=HTML" > /dev/null 2>&1 || true
    fi

    # 2. Discord Notification
    if [[ -n "$DISCORD_WEBHOOK_URL" ]]; then
        local color=16711680 # Red
        if [ "$level" == "RECOVERED" ]; then color=65280; fi # Green
        if [ "$level" == "WARNING" ]; then color=16776960; fi # Yellow

        local discord_json
        discord_json=$(cat <<EOF
{
  "embeds": [
    {
      "title": "${level}: ${title}",
      "description": "${message}\n\n**Server:** \`${SERVER_NAME}\`\n**Time:** \`${timestamp}\`",
      "color": ${color}
    }
  ]
}
EOF
)
        curl -s -H "Content-Type: application/json" -X POST \
            -d "$discord_json" "$DISCORD_WEBHOOK_URL" > /dev/null 2>&1 || true
    fi
}

check_system() {
    local has_issue=0
    local alert_msgs=""

    # 1. Check RAM
    local ram_used_pct
    ram_used_pct=$(free | awk '/Mem:/ {printf "%.0f", ($3/$2)*100}')
    if [ "$ram_used_pct" -ge "$RAM_THRESHOLD" ]; then
        has_issue=1
        alert_msgs+="• <b>RAM Usage:</b> ${ram_used_pct}% (Ngưỡng: ${RAM_THRESHOLD}%)%0A"
    fi

    # 2. Check SWAP
    local swap_total
    swap_total=$(free | awk '/Swap:/ {print $2}')
    if [ "$swap_total" -gt 0 ]; then
        local swap_used_pct
        swap_used_pct=$(free | awk '/Swap:/ {printf "%.0f", ($3/$2)*100}')
        if [ "$swap_used_pct" -ge "$SWAP_THRESHOLD" ]; then
            has_issue=1
            alert_msgs+="• <b>Swap Usage:</b> ${swap_used_pct}% (Ngưỡng: ${SWAP_THRESHOLD}%)%0A"
        fi
    fi

    # 3. Check Disk (Root filesystem)
    local disk_used_pct
    disk_used_pct=$(df -h / | awk 'NR==2 {gsub("%",""); print $5}')
    if [ "$disk_used_pct" -ge "$DISK_THRESHOLD" ]; then
        has_issue=1
        alert_msgs+="• <b>Disk Usage (/):</b> ${disk_used_pct}% (Ngưỡng: ${DISK_THRESHOLD}%)%0A"
    fi

    # 4. Check Docker Containers (Unhealthy / Dead)
    if command -v docker &> /dev/null; then
        local unhealthy_containers
        unhealthy_containers=$(docker ps -a --format '{{.Names}}: {{.Status}}' | grep -v 'Up ' || true)
        if [ -n "$unhealthy_containers" ]; then
            has_issue=1
            alert_msgs+="• <b>Docker Issues:</b> Container stopped/unhealthy:%0A<code>${unhealthy_containers}</code>%0A"
        fi
    fi

    # Cooldown check
    local current_time
    current_time=$(date +%s)
    local last_alert=0
    if [ -f "$ALERT_FLAG" ]; then
        last_alert=$(cat "$ALERT_FLAG")
    fi

    if [ "$has_issue" -eq 1 ]; then
        if [ $((current_time - last_alert)) -ge "$COOLDOWN_SECONDS" ]; then
            send_alert "DANGER" "Phát hiện sự cố tài nguyên Server!" "$alert_msgs"
            echo "$current_time" > "$ALERT_FLAG"
        fi
    else
        # If was alerting, send recovery message
        if [ -f "$ALERT_FLAG" ]; then
            send_alert "RECOVERED" "Tài nguyên server đã trở lại bình thường!" "Tất cả chỉ số RAM, Swap, Disk và Docker containers đã ổn định."
            rm -f "$ALERT_FLAG"
        fi
    fi
}

check_system
