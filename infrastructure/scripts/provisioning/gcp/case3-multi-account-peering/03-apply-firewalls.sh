#!/usr/bin/env bash
# ==============================================================================
# BƯỚC 3: WIZARD ÁP DỤNG TƯỜNG LỬA ZERO-TRUST TỪNG BƯỚC (HỖ TRỢ ĐA TÀI KHOẢN)
# ==============================================================================
set -eo pipefail

echo "================================================================="
echo "🧙‍♂️ ENTERPRISE FIREWALL SECURITY WIZARD (GCP ZERO-TRUST)"
echo "================================================================="

# 0. Chọn Google Account
echo ""
echo "📌 [BƯỚC 0/4] XÁC ĐỊNH TÀI KHOẢN GOOGLE CLOUD:"
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

# 1. Chọn Role
echo ""
echo "📌 [BƯỚC 1/4] CHỌN LOẠI MÁY CHỦ CẦN THIẾT LẬP TƯỜNG LỬA:"
echo "  [1] Data Server     (Khóa Egress 0.0.0.0/0, mở IAP, mở DB cho App Subnet)"
echo "  [2] App Server      (Mở Public 80/443/8080/8085, Khóa Egress, mở IAP)"
echo "  [3] Egress Gateway  (Mở Egress Webhook/Email 80/443, Mở Ingress từ App Subnet, mở IAP)"
read -rp "👉 Chọn vai trò [1-3, Mặc định: 1]: " role_choice
role_choice="${role_choice:-1}"

ROLE="data"
if [[ "$role_choice" == "2" ]]; then ROLE="app"; fi
if [[ "$role_choice" == "3" ]]; then ROLE="egress"; fi

# 2. Xác định Project & VPC Name
echo ""
echo "📌 [BƯỚC 2/4] XÁC ĐỊNH PROJECT & TÊN VPC:"
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

DEFAULT_VPC="data-server-vpc"
if [[ "$ROLE" == "app" ]]; then DEFAULT_VPC="app-server-vpc"; fi
if [[ "$ROLE" == "egress" ]]; then DEFAULT_VPC="egress-gateway-vpc"; fi

read -rp "👉 VPC Name [Mặc định: ${DEFAULT_VPC}]: " VPC_NAME
VPC_NAME="${VPC_NAME:-$DEFAULT_VPC}"

# 3. Dải CIDR được phép
echo ""
echo "📌 [BƯỚC 3/4] CẤU HÌNH DẢI MẠNG ĐƯỢC PHÉP TRUY CẬP:"
if [[ "$ROLE" == "data" || "$ROLE" == "egress" ]]; then
  read -rp "👉 Dải IP của App Subnet được gọi vào (${ROLE^^}) [Mặc định: 10.20.0.0/24]: " ALLOWED_CIDR
  ALLOWED_CIDR="${ALLOWED_CIDR:-10.20.0.0/24}"
fi

# 4. Bảng tổng kết & Xác nhận
echo ""
echo "================================================================="
echo "📋 BẢNG TỔNG KẾT CẤU HÌNH TƯỜNG LỬA ZERO-TRUST"
echo "================================================================="
echo "  • Google Account: ${ACTIVE_ACCOUNT}"
echo "  • Project ID:     ${PROJECT_ID}"
echo "  • VPC Name:       ${VPC_NAME}"
echo "  • Role:           ${ROLE^^} SERVER"
if [[ "$ROLE" == "data" ]]; then
  echo "  • Ingress DB:     ${ALLOWED_CIDR} (Mongo:27017, Redis:6379, Kafka:9092, OpenSearch:9200)"
  echo "  • Egress Deny:    0.0.0.0/0 (Khóa 100% Internet)"
  echo "  • Egress Allow:   ${ALLOWED_CIDR}, Google IAP, DNS/NTP"
  echo "  • Ingress IAP:    Google IAP (SSH:22, Grafana:3000)"
elif [[ "$ROLE" == "app" ]]; then
  echo "  • Ingress Web:    0.0.0.0/0 (Port 80, 443, 8080, 8085)"
  echo "  • Ingress SSH:    Google IAP (35.235.240.0/20 - An toàn tuyệt đối)"
  echo "  • Ingress ICMP:   0.0.0.0/0 (Ping)"
  echo "  • Egress Deny:    0.0.0.0/0 (Khóa Internet)"
  echo "  • Egress Allow:   Data Subnet (10.10.0.0/24), Google IAP, DNS/NTP"
elif [[ "$ROLE" == "egress" ]]; then
  echo "  • Ingress App:    ${ALLOWED_CIDR} (Port 8090 Dispatcher, Kafka:9092, 9094)"
  echo "  • Ingress SSH:    Google IAP (35.235.240.0/20)"
  echo "  • Ingress Public: KHÓA 100% (Không mở bất kỳ cổng nào vào từ Internet)"
  echo "  • Egress Allow:   0.0.0.0/0 (Port 80/443 Webhook & Email, DNS:53, NTP:123) & App Subnet"
fi
echo "================================================================="
read -rp "❓ Bạn có xác nhận áp dụng bộ quy tắc tường lửa này không? [Y/n, Mặc định: Y]: " confirm
confirm="${confirm:-Y}"

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "🚫 Đã hủy bỏ thao tác."
  exit 0
fi

echo ""
echo "🛡️ Đang áp dụng các quy tắc Tường lửa trên [${PROJECT_ID} / ${VPC_NAME}]..."

if [[ "$ROLE" == "data" ]]; then
  # 1. Mở Ingress DB từ App Subnet
  gcloud compute firewall-rules create data-vpc-allow-ingress-peer-app \
    --project="${PROJECT_ID}" \
    --network="${VPC_NAME}" \
    --direction=INGRESS \
    --action=ALLOW \
    --source-ranges="${ALLOWED_CIDR}" \
    --rules="tcp:27017,tcp:6379,tcp:9092,tcp:9200" \
    --priority=1000 \
    --description="Allow App Server (${ALLOWED_CIDR}) to access Mongo, Redis, Kafka, OpenSearch" \
    || echo "⚠️ Rule data-vpc-allow-ingress-peer-app đã tồn tại."

  # 2. Mở Egress phản hồi cho App Subnet & IAP (Priority 900 - cao hơn Deny All)
  gcloud compute firewall-rules create data-vpc-allow-egress-peer-app \
    --project="${PROJECT_ID}" \
    --network="${VPC_NAME}" \
    --direction=EGRESS \
    --action=ALLOW \
    --destination-ranges="${ALLOWED_CIDR}" \
    --rules="all" \
    --priority=900 \
    --description="Allow outbound reply traffic to App Subnet" \
    || echo "⚠️ Rule data-vpc-allow-egress-peer-app đã tồn tại."

  gcloud compute firewall-rules create data-vpc-allow-egress-iap \
    --project="${PROJECT_ID}" \
    --network="${VPC_NAME}" \
    --direction=EGRESS \
    --action=ALLOW \
    --destination-ranges="35.235.240.0/20" \
    --rules="all" \
    --priority=900 \
    --description="Allow outbound reply traffic to Google IAP" \
    || echo "⚠️ Rule data-vpc-allow-egress-iap đã tồn tại."

  gcloud compute firewall-rules create data-vpc-allow-egress-ntp-dns \
    --project="${PROJECT_ID}" \
    --network="${VPC_NAME}" \
    --direction=EGRESS \
    --action=ALLOW \
    --destination-ranges="169.254.169.254/32,216.239.35.0/24" \
    --rules="udp:53,tcp:53,udp:123" \
    --priority=900 \
    --description="Allow egress to Google Internal DNS and NTP Time Servers for UTC sync" \
    || echo "⚠️ Rule data-vpc-allow-egress-ntp-dns đã tồn tại."

  # 3. Khóa Egress Internet chống Reverse Shell (Priority 1000)
  gcloud compute firewall-rules create data-vpc-deny-egress-internet \
    --project="${PROJECT_ID}" \
    --network="${VPC_NAME}" \
    --direction=EGRESS \
    --action=DENY \
    --destination-ranges="0.0.0.0/0" \
    --rules="all" \
    --priority=1000 \
    --description="Block all outbound internet traffic from Data Server" \
    || echo "⚠️ Rule data-vpc-deny-egress-internet đã tồn tại."

  # 4. Mở Google IAP Ingress cho SSH & Toàn Bộ Cổng Infra Tunnel (Mongo, Redis, OpenSearch, Grafana)
  gcloud compute firewall-rules create data-vpc-allow-ingress-iap \
    --project="${PROJECT_ID}" \
    --network="${VPC_NAME}" \
    --direction=INGRESS \
    --action=ALLOW \
    --source-ranges="35.235.240.0/20" \
    --rules="tcp:22,tcp:27017,tcp:6379,tcp:9200,tcp:3000" \
    --priority=1000 \
    --description="Allow Google IAP for SSH and all Local Infra Tunnels (Mongo, Redis, OpenSearch, Grafana)" \
    || echo "⚠️ Rule data-vpc-allow-ingress-iap đã tồn tại."

elif [[ "$ROLE" == "app" ]]; then
  # 1. Mở Google IAP Ingress cho SSH & Toàn Bộ Cổng App Tunnel (API, Kafka, Redpanda Console)
  gcloud compute firewall-rules create app-vpc-allow-ingress-iap \
    --project="${PROJECT_ID}" \
    --network="${VPC_NAME}" \
    --direction=INGRESS \
    --action=ALLOW \
    --source-ranges="35.235.240.0/20" \
    --rules="tcp:22,tcp:8080,tcp:8085,tcp:9092,tcp:9094" \
    --priority=1000 \
    --description="Allow Google IAP for SSH and Local App Tunnels (API, Kafka, Console)" \
    || echo "⚠️ Rule app-vpc-allow-ingress-iap đã tồn tại."

  # 2. Mở Egress sang Data Server & Egress Gateway qua Peering, Google IAP & NTP/DNS (Priority 900)
  gcloud compute firewall-rules create app-vpc-allow-egress-peer-data \
    --project="${PROJECT_ID}" \
    --network="${VPC_NAME}" \
    --direction=EGRESS \
    --action=ALLOW \
    --destination-ranges="10.10.0.0/24,10.30.0.0/24" \
    --rules="all" \
    --priority=900 \
    --description="Allow outbound to Data Server and Egress Gateway over Peering" \
    || echo "⚠️ Rule app-vpc-allow-egress-peer-data đã tồn tại."

  gcloud compute firewall-rules create app-vpc-allow-egress-iap \
    --project="${PROJECT_ID}" \
    --network="${VPC_NAME}" \
    --direction=EGRESS \
    --action=ALLOW \
    --destination-ranges="35.235.240.0/20" \
    --rules="all" \
    --priority=900 \
    --description="Allow egress to Google IAP" \
    || echo "⚠️ Rule app-vpc-allow-egress-iap đã tồn tại."

  gcloud compute firewall-rules create app-vpc-allow-egress-ntp-dns \
    --project="${PROJECT_ID}" \
    --network="${VPC_NAME}" \
    --direction=EGRESS \
    --action=ALLOW \
    --destination-ranges="169.254.169.254/32,216.239.35.0/24" \
    --rules="udp:53,tcp:53,udp:123" \
    --priority=900 \
    --description="Allow egress to Google Internal DNS and NTP Time Servers for UTC sync" \
    || echo "⚠️ Rule app-vpc-allow-egress-ntp-dns đã tồn tại."

  # 3. Khóa Egress Internet chống Reverse Shell / Data Leak (Priority 1000)
  gcloud compute firewall-rules create app-vpc-deny-egress-internet \
    --project="${PROJECT_ID}" \
    --network="${VPC_NAME}" \
    --direction=EGRESS \
    --action=DENY \
    --destination-ranges="0.0.0.0/0" \
    --rules="all" \
    --priority=1000 \
    --description="Block all outbound internet from App Server" \
    || echo "⚠️ Rule app-vpc-deny-egress-internet đã tồn tại."

  # 4. Mở cổng Public Ingress
  gcloud compute firewall-rules create app-vpc-allow-ingress-public \
    --project="${PROJECT_ID}" \
    --network="${VPC_NAME}" \
    --direction=INGRESS \
    --action=ALLOW \
    --source-ranges="0.0.0.0/0" \
    --rules="tcp:80,tcp:443,tcp:8080,tcp:8085" \
    --priority=1000 \
    --description="Allow public traffic to API and Redpanda Console" \
    || echo "⚠️ Rule app-vpc-allow-ingress-public đã tồn tại."

  # 5. Mở Ping nội bộ
  gcloud compute firewall-rules create app-vpc-allow-ingress-icmp \
    --project="${PROJECT_ID}" \
    --network="${VPC_NAME}" \
    --direction=INGRESS \
    --action=ALLOW \
    --source-ranges="0.0.0.0/0" \
    --rules="icmp" \
    --priority=1000 \
    --description="Allow ICMP ping" \
    || echo "⚠️ Rule app-vpc-allow-ingress-icmp đã tồn tại."

  # 6. Khóa 100% Ingress từ Gateway Subnet (Chặn Gateway gọi ngược về Core - Zero-Trust 1 chiều)
  gcloud compute firewall-rules create app-vpc-deny-ingress-gateway \
    --project="${PROJECT_ID}" \
    --network="${VPC_NAME}" \
    --direction=INGRESS \
    --action=DENY \
    --source-ranges="10.30.0.0/24" \
    --rules="all" \
    --priority=700 \
    --description="Deny all inbound connections initiated from Gateway VPC (Zero-Trust one-way)" \
    || echo "⚠️ Rule app-vpc-deny-ingress-gateway đã tồn tại."

elif [[ "$ROLE" == "egress" ]]; then
  # 1. Mở Google IAP Ingress cho SSH
  gcloud compute firewall-rules create egress-vpc-allow-ingress-iap \
    --project="${PROJECT_ID}" \
    --network="${VPC_NAME}" \
    --direction=INGRESS \
    --action=ALLOW \
    --source-ranges="35.235.240.0/20" \
    --rules="tcp:22" \
    --priority=1000 \
    --description="Allow Google IAP for SSH to Egress Gateway" \
    || echo "⚠️ Rule egress-vpc-allow-ingress-iap đã tồn tại."

  # 2. Mở Ingress nhận dispatch từ App Subnet
  gcloud compute firewall-rules create egress-vpc-allow-ingress-peer-app \
    --project="${PROJECT_ID}" \
    --network="${VPC_NAME}" \
    --direction=INGRESS \
    --action=ALLOW \
    --source-ranges="${ALLOWED_CIDR}" \
    --rules="tcp:8090,tcp:9092,tcp:9094,icmp" \
    --priority=1000 \
    --description="Allow App Server (${ALLOWED_CIDR}) to call internal Egress Dispatcher on port 8090" \
    || echo "⚠️ Rule egress-vpc-allow-ingress-peer-app đã tồn tại."

  # 3. Mở Egress phản hồi cho IAP (Priority 900)
  gcloud compute firewall-rules create egress-vpc-allow-egress-iap \
    --project="${PROJECT_ID}" \
    --network="${VPC_NAME}" \
    --direction=EGRESS \
    --action=ALLOW \
    --destination-ranges="35.235.240.0/20" \
    --rules="all" \
    --priority=900 \
    --description="Allow outbound reply traffic to Google IAP" \
    || echo "⚠️ Rule egress-vpc-allow-egress-iap đã tồn tại."

  # 4. Mở Egress Outbound Internet cho Webhook & Email & DNS/NTP (Priority 900)
  gcloud compute firewall-rules create egress-vpc-allow-egress-internet \
    --project="${PROJECT_ID}" \
    --network="${VPC_NAME}" \
    --direction=EGRESS \
    --action=ALLOW \
    --destination-ranges="0.0.0.0/0" \
    --rules="tcp:80,tcp:443,udp:53,tcp:53,udp:123" \
    --priority=900 \
    --description="Allow outbound Webhook, Resend Email HTTP/HTTPS, DNS and NTP" \
    || echo "⚠️ Rule egress-vpc-allow-egress-internet đã tồn tại."
fi

echo ""
echo "================================================================="
echo "🎉 HOÀN TẤT THIẾT LẬP TƯỜNG LỬA ZERO-TRUST TRÊN [${PROJECT_ID} / ${VPC_NAME}]!"
echo "================================================================="
