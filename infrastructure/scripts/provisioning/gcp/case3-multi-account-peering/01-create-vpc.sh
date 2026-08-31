#!/usr/bin/env bash
# ==============================================================================
# BƯỚC 1: WIZARD TẠO CUSTOM VPC & SUBNET TỪNG BƯỚC (HỖ TRỢ ĐA TÀI KHOẢN)
# ==============================================================================
set -eo pipefail

echo "================================================================="
echo "🧙‍♂️ ENTERPRISE VPC PROVISIONING WIZARD (GCP MULTI-ACCOUNT)"
echo "================================================================="

# 0. Chọn Google Account
echo ""
echo "📌 [BƯỚC 0/5] XÁC ĐỊNH TÀI KHOẢN GOOGLE CLOUD:"
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
  echo "  [$i] Đăng nhập tài khoản Google khác (gcloud auth login)"
  
  read -rp "👉 Chọn tài khoản sử dụng [1-$i, Mặc định: 1]: " acc_choice
  acc_choice="${acc_choice:-1}"
  
  if [[ "$acc_choice" -eq "$i" || -z "${acc_map[$acc_choice]}" ]]; then
    echo "🔑 Đang mở trình duyệt để đăng nhập tài khoản mới..."
    gcloud auth login
  else
    SELECTED_ACCOUNT="${acc_map[$acc_choice]}"
    echo "👉 Đang kích hoạt tài khoản: ${SELECTED_ACCOUNT}"
    gcloud config set account "${SELECTED_ACCOUNT}" >/dev/null 2>&1 || true
  fi
else
  echo "🔑 Chưa có tài khoản đăng nhập. Đang mở trình duyệt..."
  gcloud auth login
fi

ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null || true)
echo "✅ Đang thao tác với tài khoản: [ ${ACTIVE_ACCOUNT} ]"

# 1. Chọn Project ID
echo ""
echo "📌 [BƯỚC 1/5] XÁC ĐỊNH GCP PROJECT:"
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
  echo "  [$i] Giữ nguyên Project hiện tại (${CURRENT_PROJECT}) hoặc nhập ID khác"
  
  read -rp "👉 Chọn Project [1-$i, Mặc định: 1]: " pchoice
  pchoice="${pchoice:-1}"
  
  if [[ "$pchoice" -eq "$i" || -z "${proj_map[$pchoice]}" ]]; then
    read -rp "👉 Nhập Project ID mong muốn: " PROJECT_ID
    PROJECT_ID="${PROJECT_ID:-$CURRENT_PROJECT}"
  else
    PROJECT_ID="${proj_map[$pchoice]}"
  fi
else
  read -rp "👉 Nhập Project ID của bạn [Mặc định: ${CURRENT_PROJECT}]: " PROJECT_ID
  PROJECT_ID="${PROJECT_ID:-$CURRENT_PROJECT}"
fi

# 2. Đặt tên VPC
echo ""
echo "📌 [BƯỚC 2/5] ĐẶT TÊN MẠNG VPC:"
echo "Gợi ý: [data-server-vpc] (Data) | [app-server-vpc] (App) | [egress-gateway-vpc] (Egress)"
read -rp "👉 Nhập tên VPC [Mặc định: egress-gateway-vpc]: " VPC_NAME
VPC_NAME="${VPC_NAME:-egress-gateway-vpc}"

# 3. Chọn Dải IP CIDR
echo ""
echo "📌 [BƯỚC 3/5] CHỌN DẢI IP NỘI BỘ (CIDR):"
DEFAULT_RANGE="10.30.0.0/24"
if [[ "$VPC_NAME" == *"data"* ]]; then
  DEFAULT_RANGE="10.10.0.0/24"
elif [[ "$VPC_NAME" == *"app"* ]]; then
  DEFAULT_RANGE="10.20.0.0/24"
elif [[ "$VPC_NAME" == *"egress"* || "$VPC_NAME" == *"gateway"* ]]; then
  DEFAULT_RANGE="10.30.0.0/24"
fi

echo "Gợi ý: Data: 10.10.0.0/24 | App: 10.20.0.0/24 | Egress Gateway: 10.30.0.0/24"
read -rp "👉 Nhập dải CIDR [Mặc định: ${DEFAULT_RANGE}]: " SUBNET_RANGE
SUBNET_RANGE="${SUBNET_RANGE:-$DEFAULT_RANGE}"

# 4. Chọn Region
echo ""
echo "📌 [BƯỚC 4/5] CHỌN KHU VỰC (REGION):"
echo "Gợi ý: us-central1 (Iowa) | asia-southeast1 (Singapore)"
read -rp "👉 Nhập Region [Mặc định: us-central1]: " REGION
REGION="${REGION:-us-central1}"

SUBNET_NAME="subnet-${VPC_NAME}"

# 5. Bảng tổng kết & Xác nhận thực thi
echo ""
echo "================================================================="
echo "📋 BẢNG TỔNG KẾT THÔNG SỐ TRƯỚC KHI THỰC THI"
echo "================================================================="
echo "  • Google Account: ${ACTIVE_ACCOUNT}"
echo "  • Project ID:     ${PROJECT_ID}"
echo "  • VPC Name:       ${VPC_NAME}"
echo "  • Subnet Name:    ${SUBNET_NAME}"
echo "  • CIDR Range:     ${SUBNET_RANGE}"
echo "  • Region:         ${REGION}"
echo "================================================================="
read -rp "❓ Bạn có đồng ý thực thi tạo mạng VPC này không? [Y/n, Mặc định: Y]: " confirm
confirm="${confirm:-Y}"

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "🚫 Đã hủy bỏ thao tác."
  exit 0
fi

echo ""
echo "🚀 Đang tiến hành tạo VPC [${VPC_NAME}] trên Project [${PROJECT_ID}]..."

# 1. Tạo Custom VPC
if ! gcloud compute networks describe "${VPC_NAME}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  echo "👉 Đang tạo mạng VPC [${VPC_NAME}]..."
  gcloud compute networks create "${VPC_NAME}" --project="${PROJECT_ID}" --subnet-mode=custom
else
  echo "✅ VPC [${VPC_NAME}] đã tồn tại."
fi

# 2. Tạo Subnet
if ! gcloud compute networks subnets describe "${SUBNET_NAME}" --region="${REGION}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  echo "👉 Đang tạo Subnet [${SUBNET_NAME}] (${SUBNET_RANGE})..."
  gcloud compute networks subnets create "${SUBNET_NAME}" \
    --project="${PROJECT_ID}" \
    --network="${VPC_NAME}" \
    --region="${REGION}" \
    --range="${SUBNET_RANGE}"
else
  echo "✅ Subnet [${SUBNET_NAME}] đã tồn tại."
fi

# 3. Tự động dọn dẹp các rule default và mạng default nếu có (Zero-Trust)
echo "🧹 Đang dọn dẹp các firewall rules 'default-*' và mạng default thừa..."
gcloud compute firewall-rules delete default-allow-icmp default-allow-internal default-allow-rdp default-allow-ssh --project="${PROJECT_ID}" --quiet >/dev/null 2>&1 || true
gcloud compute networks delete default --project="${PROJECT_ID}" --quiet >/dev/null 2>&1 || true
echo "✅ Mạng VPC sạch sẽ và bảo mật!"

echo ""
echo "================================================================="
echo "🎉 HOÀN TẤT THÀNH CÔNG: [${VPC_NAME}] (${SUBNET_RANGE}) TRÊN [${PROJECT_ID}]!"
echo "================================================================="
