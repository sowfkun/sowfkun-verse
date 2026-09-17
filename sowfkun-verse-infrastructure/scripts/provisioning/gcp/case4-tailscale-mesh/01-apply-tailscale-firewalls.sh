#!/usr/bin/env bash
# ==============================================================================
# CASE 4 - BƯỚC 1: CẤU HÌNH TƯỜNG LỬA ZERO-TRUST CHO TAILSCALE MESH TRÊN GCP
# ==============================================================================
set -eo pipefail

echo "================================================================="
echo "🛡️ CASE 4: GCP TAILSCALE MESH ZERO-TRUST FIREWALL PROVISIONER"
echo "================================================================="

# 0. Xác định tài khoản Google Cloud
echo ""
echo "📌 [BƯỚC 0/3] XÁC ĐỊNH TÀI KHOẢN GOOGLE CLOUD:"
accounts_list=$(gcloud auth list --format="value(account)" 2>/dev/null || true)

if [[ -n "$accounts_list" ]]; then
  echo "📋 Danh sách tài khoản đã đăng nhập trên máy:"
  i=1
  declare -A acc_map
  while IFS= read -r acc; do
    echo "  [$i] $acc"
    acc_map[$i]="$acc"
    i=$((i + 1))
  done <<< "$accounts_list"
  echo "  [$i] Đăng nhập tài khoản Google khác"
  
  read -rp "👉 Chọn tài khoản [1-$i, Mặc định: 1]: " acc_choice
  acc_choice="${acc_choice:-1}"
  
  if [[ "$acc_choice" -eq "$i" || -z "${acc_map[$acc_choice]}" ]]; then
    gcloud auth login
  else
    SELECTED_ACCOUNT="${acc_map[$acc_choice]}"
    gcloud config set account "${SELECTED_ACCOUNT}" >/dev/null 2>&1 || true
  fi
fi

ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null || true)
echo "✅ Đang thao tác với tài khoản: [ ${ACTIVE_ACCOUNT} ]"

# 1. Chọn vai trò máy chủ
echo ""
echo "📌 [BƯỚC 1/3] CHỌN VAI TRÒ MÁY CHỦ GCP CẦN THIẾT LẬP:"
echo "  [1] Server 1 - Data / Cache & MQ Node  (Redis 6379, Kafka 9092, Web Console 8085, Loki 3100)"
echo "  [2] Server 2 - App Node                (Go API Backend 8080)"
echo "  [3] Server 3 - Egress Gateway Node     (Egress Gateway 8090, Outbound Whitelist 80/443)"
read -rp "👉 Chọn vai trò [1-3, Mặc định: 1]: " role_choice
role_choice="${role_choice:-1}"

ROLE="data"
ROLE_NAME="Server 1 - Cache & MQ Node"
VPC_DEFAULT="data-server-vpc"
if [[ "$role_choice" == "2" ]]; then
  ROLE="app"
  ROLE_NAME="Server 2 - App Node"
  VPC_DEFAULT="app-server-vpc"
elif [[ "$role_choice" == "3" ]]; then
  ROLE="egress"
  ROLE_NAME="Server 3 - Egress Gateway Node"
  VPC_DEFAULT="egress-gateway-vpc"
fi

# 2. Xác định Project & VPC Name
echo ""
echo "📌 [BƯỚC 2/3] XÁC ĐỊNH PROJECT & TÊN VPC:"
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null || true)
projects_list=$(gcloud projects list --format="value(projectId,name)" 2>/dev/null || true)
PROJECT_ID=""

if [[ -n "$projects_list" ]]; then
  echo "📋 Danh sách Projects trên tài khoản [${ACTIVE_ACCOUNT}]:"
  i=1
  declare -A proj_map
  while IFS=$'\t' read -r pid pname; do
    echo "  [$i] $pname (ID: $pid)"
    proj_map[$i]="$pid"
    i=$((i + 1))
  done <<< "$projects_list"
  
  read -rp "👉 Chọn Project [1-$i, Mặc định: 1]: " pchoice
  pchoice="${pchoice:-1}"
  PROJECT_ID="${proj_map[$pchoice]:-$CURRENT_PROJECT}"
else
  read -rp "👉 Nhập Project ID [Mặc định: ${CURRENT_PROJECT}]: " PROJECT_ID
  PROJECT_ID="${PROJECT_ID:-$CURRENT_PROJECT}"
fi

read -rp "👉 VPC Network Name [Mặc định: ${VPC_DEFAULT} (hoặc 'default')]: " VPC_NAME
VPC_NAME="${VPC_NAME:-$VPC_DEFAULT}"

# 3. Tổng kết & Xác nhận
echo ""
echo "================================================================="
echo "📋 BẢNG TỔNG KẾT THIẾT LẬP TƯỜNG LỬA TAILSCALE ZERO-TRUST"
echo "================================================================="
echo "  • Google Account: ${ACTIVE_ACCOUNT}"
echo "  • Project ID:     ${PROJECT_ID}"
echo "  • VPC Network:    ${VPC_NAME}"
echo "  • Vai trò Server: ${ROLE_NAME} (${ROLE^^})"
echo "================================================================="
read -rp "👉 Xác nhận áp dụng các quy tắc tường lửa này? (y/N): " confirm
if [[ ! "$confirm" =~ ^[yY]$ ]]; then
  echo "❌ Đã hủy thao tác."
  exit 0
fi

echo ""
echo "⚙️ Đang áp dụng quy tắc tường lửa cho ${ROLE_NAME} trên VPC [${VPC_NAME}]..."

# Rule chung 1: Cho phép Google IAP (SSH khẩn cấp không cần mở IP public)
gcloud compute firewall-rules create "${VPC_NAME}-allow-iap-ssh" \
  --project="${PROJECT_ID}" \
  --network="${VPC_NAME}" \
  --direction=INGRESS \
  --action=ALLOW \
  --source-ranges="35.235.240.0/20" \
  --rules="tcp:22" \
  --priority=900 \
  --description="Allow Google Cloud IAP for emergency secure SSH without public IP" \
  || echo "⚠️ Rule ${VPC_NAME}-allow-iap-ssh đã tồn tại."

# Rule chung 2: Cho phép Tailscale WireGuard Ingress (UDP 41641) và Ping (ICMP)
gcloud compute firewall-rules create "${VPC_NAME}-allow-tailscale-ingress" \
  --project="${PROJECT_ID}" \
  --network="${VPC_NAME}" \
  --direction=INGRESS \
  --action=ALLOW \
  --source-ranges="0.0.0.0/0" \
  --rules="udp:41641,icmp" \
  --priority=850 \
  --description="Allow Tailscale WireGuard peer traffic and ICMP diagnostics" \
  || echo "⚠️ Rule ${VPC_NAME}-allow-tailscale-ingress đã tồn tại."

# Rule chung 3: Cho phép Outbound thiết yếu (Tailscale WireGuard, STUN, HTTPS Control, DNS, NTP)
gcloud compute firewall-rules create "${VPC_NAME}-allow-tailscale-egress" \
  --project="${PROJECT_ID}" \
  --network="${VPC_NAME}" \
  --direction=EGRESS \
  --action=ALLOW \
  --destination-ranges="0.0.0.0/0" \
  --rules="udp:41641,udp:3478,tcp:443" \
  --priority=800 \
  --description="Allow Tailscale WireGuard UDP, STUN, and HTTPS Control Plane Outbound" \
  || echo "⚠️ Rule ${VPC_NAME}-allow-tailscale-egress đã tồn tại."

gcloud compute firewall-rules create "${VPC_NAME}-allow-system-egress" \
  --project="${PROJECT_ID}" \
  --network="${VPC_NAME}" \
  --direction=EGRESS \
  --action=ALLOW \
  --destination-ranges="169.254.169.254/32,216.239.35.0/24,0.0.0.0/0" \
  --rules="udp:53,tcp:53,udp:123" \
  --priority=810 \
  --description="Allow DNS and NTP Time Synchronization" \
  || echo "⚠️ Rule ${VPC_NAME}-allow-system-egress đã tồn tại."

# Cấu hình chuyên biệt theo từng Role:
case "$ROLE" in
  "data")
    echo "🔒 Áp dụng Zero-Trust cho Data Node: Khóa toàn bộ Ingress & Egress Internet lạ..."
    # Khóa toàn bộ Egress không mong muốn (Priority 1000)
    gcloud compute firewall-rules create "${VPC_NAME}-deny-all-egress" \
      --project="${PROJECT_ID}" \
      --network="${VPC_NAME}" \
      --direction=EGRESS \
      --action=DENY \
      --destination-ranges="0.0.0.0/0" \
      --rules="all" \
      --priority=1000 \
      --description="Zero-Trust: Deny all arbitrary outbound internet from Data Server" \
      || echo "⚠️ Rule ${VPC_NAME}-deny-all-egress đã tồn tại."
    ;;

  "app")
    echo "🌐 Cấu hình App Node: Zero-Trust Ingress (chỉ qua Cloudflare Tunnel / Tailscale Mesh) & Khóa Egress Internet tự do..."
    # Không mở public ingress 8080/80/443 vì toàn bộ traffic đã qua Cloudflare Tunnel và Tailscale Mesh an toàn 100%

    gcloud compute firewall-rules create "${VPC_NAME}-deny-all-egress" \
      --project="${PROJECT_ID}" \
      --network="${VPC_NAME}" \
      --direction=EGRESS \
      --action=DENY \
      --destination-ranges="0.0.0.0/0" \
      --rules="all" \
      --priority=1000 \
      --description="Zero-Trust: Deny direct internet outbound; force routing via Egress Gateway" \
      || echo "⚠️ Rule ${VPC_NAME}-deny-all-egress đã tồn tại."
    ;;

  "egress")
    echo "🛡️ Cấu hình Egress Gateway Node: Cho phép Outbound HTTP/HTTPS có kiểm soát..."
    gcloud compute firewall-rules create "${VPC_NAME}-allow-gateway-egress" \
      --project="${PROJECT_ID}" \
      --network="${VPC_NAME}" \
      --direction=EGRESS \
      --action=ALLOW \
      --destination-ranges="0.0.0.0/0" \
      --rules="tcp:80,tcp:443" \
      --priority=900 \
      --description="Allow Egress Gateway to dispatch outbound webhooks, emails (Resend), and APIs" \
      || echo "⚠️ Rule ${VPC_NAME}-allow-gateway-egress đã tồn tại."
    ;;
esac

echo ""
echo "================================================================="
echo "🎉 HOÀN TẤT THIẾT LẬP TƯỜNG LỬA TAILSCALE ZERO-TRUST CHO [${ROLE_NAME}]!"
echo "================================================================="
