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
echo "  [2] App Server      (Khóa Ingress Public 100%, Cloudflare Tunnel / JIT Tunnel, Khóa Egress)"
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
  echo "  • Egress Allow:   ${ALLOWED_CIDR}, DNS/NTP"
  echo "  • Remote Access:  JIT SSH Tunnel (Qua công cụ 'sowfkun infra open/close')"
elif [[ "$ROLE" == "app" ]]; then
  echo "  • Ingress API:    Khóa mặc định (Zero-Trust) hoặc Mở Public qua JIT Tunnel"
  echo "  • Remote Access:  JIT SSH Tunnel (Qua công cụ 'sowfkun infra open/close')"
  echo "  • Egress Deny:    0.0.0.0/0 (Khóa Internet)"
  echo "  • Egress Allow:   Data Subnet (10.10.0.0/24), Gateway Subnet (10.30.0.0/24), DNS/NTP"
elif [[ "$ROLE" == "egress" ]]; then
  echo "  • Ingress App:    ${ALLOWED_CIDR} (Port 8090 Dispatcher, Kafka:9092, 9094)"
  echo "  • Ingress Public: KHÓA 100% (Không mở bất kỳ cổng nào vào từ Internet)"
  echo "  • Remote Access:  JIT SSH Tunnel (Qua công cụ 'sowfkun infra open/close')"
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

  # 2. Mở Egress phản hồi cho Mạng nội bộ & Peering (Priority 700)
  gcloud compute firewall-rules create data-vpc-allow-egress-internal \
    --project="${PROJECT_ID}" \
    --network="${VPC_NAME}" \
    --direction=EGRESS \
    --action=ALLOW \
    --destination-ranges="10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,100.64.0.0/10,${ALLOWED_CIDR}" \
    --rules="all" \
    --priority=700 \
    --description="Allow outbound reply traffic to App Subnet and internal mesh" \
    || echo "⚠️ Rule data-vpc-allow-egress-internal đã tồn tại."

  # 3. Mở Egress DNS & NTP Time Sync (Priority 810)
  gcloud compute firewall-rules create data-vpc-allow-egress-ntp-dns \
    --project="${PROJECT_ID}" \
    --network="${VPC_NAME}" \
    --direction=EGRESS \
    --action=ALLOW \
    --destination-ranges="169.254.169.254/32,216.239.35.0/24,0.0.0.0/0" \
    --rules="udp:53,tcp:53,udp:123" \
    --priority=810 \
    --description="Allow egress to Google Internal DNS and NTP Time Servers for UTC sync" \
    || echo "⚠️ Rule data-vpc-allow-egress-ntp-dns đã tồn tại."

  # 4. Khóa toàn bộ Egress Internet chống Reverse Shell / Data Leak (Priority 65000)
  gcloud compute firewall-rules create data-vpc-deny-egress-internet \
    --project="${PROJECT_ID}" \
    --network="${VPC_NAME}" \
    --direction=EGRESS \
    --action=DENY \
    --destination-ranges="0.0.0.0/0" \
    --rules="all" \
    --priority=65000 \
    --description="Zero-Trust: Block all arbitrary outbound internet traffic from Data Server" \
    || echo "⚠️ Rule data-vpc-deny-egress-internet đã tồn tại."

elif [[ "$ROLE" == "app" ]]; then
  # 1. Mở Egress sang Data Server & Egress Gateway qua Peering & Mạng nội bộ (Priority 700)
  gcloud compute firewall-rules create app-vpc-allow-egress-peer-internal \
    --project="${PROJECT_ID}" \
    --network="${VPC_NAME}" \
    --direction=EGRESS \
    --action=ALLOW \
    --destination-ranges="10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,100.64.0.0/10" \
    --rules="all" \
    --priority=700 \
    --description="Allow outbound to Data Server, Egress Gateway and internal subnets over Peering" \
    || echo "⚠️ Rule app-vpc-allow-egress-peer-internal đã tồn tại."

  # 2. Mở Egress DNS & NTP Time Sync (Priority 810)
  gcloud compute firewall-rules create app-vpc-allow-egress-ntp-dns \
    --project="${PROJECT_ID}" \
    --network="${VPC_NAME}" \
    --direction=EGRESS \
    --action=ALLOW \
    --destination-ranges="169.254.169.254/32,216.239.35.0/24,0.0.0.0/0" \
    --rules="udp:53,tcp:53,udp:123" \
    --priority=810 \
    --description="Allow egress to Google Internal DNS and NTP Time Servers for UTC sync" \
    || echo "⚠️ Rule app-vpc-allow-egress-ntp-dns đã tồn tại."

  # 3. Cho phép kết nối trực tiếp tới Aiven OpenSearch (Priority 820)
  gcloud compute firewall-rules create app-vpc-allow-egress-opensearch \
    --project="${PROJECT_ID}" \
    --network="${VPC_NAME}" \
    --direction=EGRESS \
    --action=ALLOW \
    --destination-ranges="0.0.0.0/0" \
    --rules="tcp:13059,tcp:22178,tcp:9200,tcp:443" \
    --priority=820 \
    --description="Allow Core App to connect directly to Aiven OpenSearch clusters" \
    || echo "⚠️ Rule app-vpc-allow-egress-opensearch đã tồn tại."

  # 4. Cho phép Cloudflare Tunnel kết nối tới Cloudflare Edge (Priority 830)
  gcloud compute firewall-rules create app-vpc-allow-egress-cloudflared \
    --project="${PROJECT_ID}" \
    --network="${VPC_NAME}" \
    --direction=EGRESS \
    --action=ALLOW \
    --destination-ranges="0.0.0.0/0" \
    --rules="tcp:7844,udp:7844" \
    --priority=830 \
    --description="Allow Cloudflare Tunnel outbound QUIC/HTTP2 to Cloudflare edge" \
    || echo "⚠️ Rule app-vpc-allow-egress-cloudflared đã tồn tại."

  # 5. Khóa Egress Internet chống Reverse Shell / Data Leak (Priority 65000)
  gcloud compute firewall-rules create app-vpc-deny-egress-internet \
    --project="${PROJECT_ID}" \
    --network="${VPC_NAME}" \
    --direction=EGRESS \
    --action=DENY \
    --destination-ranges="0.0.0.0/0" \
    --rules="all" \
    --priority=65000 \
    --description="Zero-Trust: Block all direct outbound internet from App Server" \
    || echo "⚠️ Rule app-vpc-deny-egress-internet đã tồn tại."

  # 6. Khóa 100% Ingress từ Gateway Subnet & Data Subnet (Chặn gọi ngược về Core - Zero-Trust 1 chiều)
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

  gcloud compute firewall-rules create app-vpc-deny-ingress-data \
    --project="${PROJECT_ID}" \
    --network="${VPC_NAME}" \
    --direction=INGRESS \
    --action=DENY \
    --source-ranges="10.10.0.0/24" \
    --rules="all" \
    --priority=700 \
    --description="Deny all inbound connections initiated from Data VPC (Zero-Trust one-way)" \
    || echo "⚠️ Rule app-vpc-deny-ingress-data đã tồn tại."

elif [[ "$ROLE" == "egress" ]]; then
  # 1. Mở Ingress nhận dispatch từ App & Data Subnets
  gcloud compute firewall-rules create egress-vpc-allow-ingress-peers \
    --project="${PROJECT_ID}" \
    --network="${VPC_NAME}" \
    --direction=INGRESS \
    --action=ALLOW \
    --source-ranges="10.10.0.0/24,10.20.0.0/24" \
    --rules="tcp:8090,icmp" \
    --priority=1000 \
    --description="Allow App & Data Servers to call internal Egress Dispatcher on port 8090" \
    || echo "⚠️ Rule egress-vpc-allow-ingress-peers đã tồn tại."

  # 2. Khóa Egress tới App & Data VPCs (Chặn Gateway chủ động chọc ngược nội bộ)
  gcloud compute firewall-rules create egress-vpc-deny-egress-internal \
    --project="${PROJECT_ID}" \
    --network="${VPC_NAME}" \
    --direction=EGRESS \
    --action=DENY \
    --destination-ranges="10.10.0.0/24,10.20.0.0/24" \
    --rules="all" \
    --priority=800 \
    --description="Block all outbound connections from Gateway to App and Data VPCs" \
    || echo "⚠️ Rule egress-vpc-deny-egress-internal đã tồn tại."

  # 3. Mở Egress Outbound Internet cho Webhook & Email & DNS/NTP (Priority 820)
  gcloud compute firewall-rules create egress-vpc-allow-egress-internet \
    --project="${PROJECT_ID}" \
    --network="${VPC_NAME}" \
    --direction=EGRESS \
    --action=ALLOW \
    --destination-ranges="0.0.0.0/0" \
    --rules="tcp:80,tcp:443,udp:53,tcp:53,udp:123" \
    --priority=820 \
    --description="Allow outbound Webhook, Resend Email HTTP/HTTPS, DNS and NTP" \
    || echo "⚠️ Rule egress-vpc-allow-egress-internet đã tồn tại."

  # 4. Khóa các protocol/port lạ khác (Priority 65000)
  gcloud compute firewall-rules create egress-vpc-deny-all-egress \
    --project="${PROJECT_ID}" \
    --network="${VPC_NAME}" \
    --direction=EGRESS \
    --action=DENY \
    --destination-ranges="0.0.0.0/0" \
    --rules="all" \
    --priority=65000 \
    --description="Zero-Trust: Deny all non-HTTP/HTTPS outbound traffic from Gateway" \
    || echo "⚠️ Rule egress-vpc-deny-all-egress đã tồn tại."
fi

echo ""
echo "================================================================="
echo "🎉 HOÀN TẤT THIẾT LẬP TƯỜNG LỬA ZERO-TRUST TRÊN [${PROJECT_ID} / ${VPC_NAME}]!"
echo "================================================================="
