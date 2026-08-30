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

        local payload
        payload=$(cat <<EOF
{
  "embeds": [
    {
      "title": "${title}",
      "description": "${message}",
      "color": ${color},
      "fields": [
        {"name": "Server", "value": "${SERVER_NAME}", "inline": true},
        {"name": "Level", "value": "${level}", "inline": true},
        {"name": "Timestamp", "value": "${timestamp}", "inline": false}
      ]
    }
  ]
}
EOF
)
        curl -s -H "Content-Type: application/json" -X POST -d "$payload" "$DISCORD_WEBHOOK_URL" > /dev/null 2>&1 || true
    fi
}

# --- Health Check Checks ---
HAS_WARNING=0
WARNING_MSGS=""

# 1. Check RAM
RAM_TOTAL=$(free -m | awk '/^Mem:/{print $2}')
RAM_USED=$(free -m | awk '/^Mem:/{print $3}')
if [ "$RAM_TOTAL" -gt 0 ]; then
    RAM_PERCENT=$((RAM_USED * 100 / RAM_TOTAL))
    if [ "$RAM_PERCENT" -ge "$RAM_THRESHOLD" ]; then
        HAS_WARNING=1
        WARNING_MSGS+="⚠️ <b>High RAM Usage:</b> ${RAM_PERCENT}% (${RAM_USED}MB / ${RAM_TOTAL}MB)%0A"
    fi
fi

# 2. Check SWAP
SWAP_TOTAL=$(free -m | awk '/^Swap:/{print $2}')
SWAP_USED=$(free -m | awk '/^Swap:/{print $3}')
if [ "$SWAP_TOTAL" -gt 0 ]; then
    SWAP_PERCENT=$((SWAP_USED * 100 / SWAP_TOTAL))
    if [ "$SWAP_PERCENT" -ge "$SWAP_THRESHOLD" ]; then
        HAS_WARNING=1
        WARNING_MSGS+="⚠️ <b>High SWAP Usage:</b> ${SWAP_PERCENT}% (${SWAP_USED}MB / ${SWAP_TOTAL}MB)%0A"
    fi
fi

# 3. Check Disk (Root filesystem)
DISK_PERCENT=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
if [ "$DISK_PERCENT" -ge "$DISK_THRESHOLD" ]; then
    HAS_WARNING=1
    WARNING_MSGS+="⚠️ <b>High Disk Usage:</b> ${DISK_PERCENT}%%0A"
fi

# 4. Check Unhealthy / Restarting Docker Containers
if command -v docker > /dev/null 2>&1; then
    FAILED_CONTAINERS=$(docker ps -a --filter "status=restarting" --filter "status=dead" --format "{{.Names}} ({{.Status}})")
    if [ -n "$FAILED_CONTAINERS" ]; then
        HAS_WARNING=1
        WARNING_MSGS+="🚨 <b>Container Issues:</b>%0A<code>${FAILED_CONTAINERS}</code>%0A"
    fi
fi

# Alert Logic with Cooldown
NOW=$(date +%s)
LAST_ALERT=0
if [ -f "$ALERT_FLAG" ]; then
    LAST_ALERT=$(cat "$ALERT_FLAG")
fi

if [ "$HAS_WARNING" -eq 1 ]; then
    if [ $((NOW - LAST_ALERT)) -ge "$COOLDOWN_SECONDS" ]; then
        send_alert "CRITICAL" "Server Health Alert" "$WARNING_MSGS"
        echo "$NOW" > "$ALERT_FLAG"
        echo "🚨 Alert sent to monitoring channels."
    else
        echo "⚠️ Warning detected but skipped due to cooldown ($(( (COOLDOWN_SECONDS - (NOW - LAST_ALERT)) / 60 )) mins remaining)."
    fi
else
    if [ -f "$ALERT_FLAG" ]; then
        send_alert "RECOVERED" "Server Health Restored" "All system metrics (RAM, SWAP, Disk, Docker) are within healthy limits."
        rm -f "$ALERT_FLAG"
        echo "✅ System recovered. Recovery alert sent."
    else
        echo "✅ All system metrics healthy."
    fi
fi
