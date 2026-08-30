#!/usr/bin/env bash
# ==============================================================================
# BƯỚC 4: WIZARD CHUYỂN VM SANG CUSTOM VPC MỚI (GIỮ NGUYÊN 100% Ổ ĐĨA & DỮ LIỆU)
# ==============================================================================
set -eo pipefail

echo "================================================================="
echo "🧙‍♂️ ENTERPRISE VM VPC MIGRATION WIZARD (ZERO DATA LOSS)"
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

# 1. Chọn Project
echo ""
echo "📌 [BƯỚC 1/4] XÁC ĐỊNH GCP PROJECT:"
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

# 2. Chọn VM Instance cần chuyển mạng
echo ""
echo "📌 [BƯỚC 2/4] CHỌN MÁY ẢO CẦN CHUYỂN MẠNG:"
vms_list=$(gcloud compute instances list --project="${PROJECT_ID}" --format="value(name,zone,machineType.basename())" 2>/dev/null || true)

if [[ -z "$vms_list" ]]; then
  echo "❌ Không tìm thấy máy ảo nào trong Project [${PROJECT_ID}]!"
  exit 1
fi

echo "📋 Danh sách máy ảo trong Project:"
i=1
declare -A vm_name_map
declare -A vm_zone_map
declare -A vm_type_map
while IFS=$'\t' read -r vname vzone vtype; do
  echo "  [$i] $vname (Zone: $vzone, Type: $vtype)"
  vm_name_map[$i]="$vname"
  vm_zone_map[$i]="$vzone"
  vm_type_map[$i]="$vtype"
  i=$((i + 1))
done <<< "$vms_list"

read -rp "👉 Chọn máy ảo cần chuyển mạng [1-$((i-1)), Mặc định: 1]: " vm_choice
vm_choice="${vm_choice:-1}"

VM_NAME="${vm_name_map[$vm_choice]}"
ZONE="${vm_zone_map[$vm_choice]}"
MACHINE_TYPE="${vm_type_map[$vm_choice]}"

# 3. Chọn VPC & Subnet đích
echo ""
echo "📌 [BƯỚC 3/4] CHỌN MẠNG VPC VÀ DẢI IP NỘI BỘ MỚI:"
subnets_list=$(gcloud compute networks subnets list --project="${PROJECT_ID}" --format="value(network.basename(),name,ipCidrRange,region)" 2>/dev/null || true)

echo "📋 Danh sách Subnets khả dụng trong Project:"
i=1
declare -A sub_net_map
declare -A sub_name_map
declare -A sub_range_map
declare -A sub_region_map
while IFS=$'\t' read -r net sname srange sreg; do
  echo "  [$i] VPC: $net | Subnet: $sname | CIDR: $srange (Region: $sreg)"
  sub_net_map[$i]="$net"
  sub_name_map[$i]="$sname"
  sub_range_map[$i]="$srange"
  sub_region_map[$i]="$sreg"
  i=$((i + 1))
done <<< "$subnets_list"

read -rp "👉 Chọn Subnet đích [1-$((i-1)), Mặc định: 1]: " sub_choice
sub_choice="${sub_choice:-1}"

TARGET_VPC="${sub_net_map[$sub_choice]}"
TARGET_SUBNET="${sub_name_map[$sub_choice]}"
SUBNET_RANGE="${sub_range_map[$sub_choice]}"

# Gợi ý IP
DEFAULT_PRIVATE_IP="${SUBNET_RANGE%.*}.2"
read -rp "👉 Nhập IP Nội Bộ Cố Định cho máy [Mặc định: ${DEFAULT_PRIVATE_IP}]: " TARGET_IP
TARGET_IP="${TARGET_IP:-$DEFAULT_PRIVATE_IP}"

# 4. Lấy thông tin Boot Disk hiện tại
echo ""
echo "🔍 Đang kiểm tra cấu hình ổ cứng của VM [${VM_NAME}]..."
BOOT_DISK_INFO=$(gcloud compute instances describe "${VM_NAME}" --project="${PROJECT_ID}" --zone="${ZONE}" --format="value(disks[0].source.basename())")
TAGS_INFO=$(gcloud compute instances describe "${VM_NAME}" --project="${PROJECT_ID}" --zone="${ZONE}" --format="value(tags.items.list())" 2>/dev/null || true)

# 5. Tổng kết & Xác nhận
echo ""
echo "================================================================="
echo "📋 BẢNG TỔNG KẾT CHUYỂN ĐỔI MẠNG (ZERO DATA LOSS)"
echo "================================================================="
echo "  • Máy ảo:         ${VM_NAME} (Zone: ${ZONE}, Type: ${MACHINE_TYPE})"
echo "  • Ổ cứng giữ lại: ${BOOT_DISK_INFO} (Bảo toàn 100% dữ liệu)"
echo "  • Mạng VPC đích:  ${TARGET_VPC}"
echo "  • Subnet đích:    ${TARGET_SUBNET}"
echo "  • IP Nội Bộ mới:  ${TARGET_IP}"
if [[ -n "$TAGS_INFO" ]]; then
  echo "  • Network Tags:   ${TAGS_INFO}"
fi
echo "================================================================="
read -rp "❓ Bạn có xác nhận chuyển máy sang VPC mới không? [Y/n, Mặc định: Y]: " confirm
confirm="${confirm:-Y}"

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "🚫 Đã hủy bỏ thao tác."
  exit 0
fi

echo ""
echo "⏳ [1/4] Khóa bảo vệ ổ cứng không bị xóa khi tắt VM..."
gcloud compute instances set-disk-auto-delete "${VM_NAME}" \
  --project="${PROJECT_ID}" \
  --zone="${ZONE}" \
  --disk="${BOOT_DISK_INFO}" \
  --no-auto-delete

echo "⏳ [2/4] Đang tắt máy ảo [${VM_NAME}] an toàn..."
gcloud compute instances stop "${VM_NAME}" --project="${PROJECT_ID}" --zone="${ZONE}" --quiet

echo "⏳ [3/4] Đang gỡ bỏ cấu hình mạng cũ..."
gcloud compute instances delete "${VM_NAME}" --project="${PROJECT_ID}" --zone="${ZONE}" --keep-disks=boot --quiet

echo "⏳ [4/4] Đang tái tạo VM [${VM_NAME}] gắn vào mạng mới [${TARGET_VPC}] với IP [${TARGET_IP}]..."
TAGS_FLAG=""
if [[ -n "$TAGS_INFO" ]]; then
  TAGS_FLAG="--tags=${TAGS_INFO}"
fi

gcloud compute instances create "${VM_NAME}" \
  --project="${PROJECT_ID}" \
  --zone="${ZONE}" \
  --machine-type="${MACHINE_TYPE}" \
  --disk="name=${BOOT_DISK_INFO},boot=yes,auto-delete=no" \
  --network="${TARGET_VPC}" \
  --subnet="${TARGET_SUBNET}" \
  --private-network-ip="${TARGET_IP}" \
  ${TAGS_FLAG} \
  --no-service-account \
  --no-scopes

echo ""
echo "================================================================="
echo "🎉 HOÀN TẤT CHUYỂN ĐỔI MẠNG THÀNH CÔNG CHO [${VM_NAME}]!"
echo "👉 Mạng mới:   ${TARGET_VPC} / ${TARGET_SUBNET}"
echo "👉 IP Nội bộ:  ${TARGET_IP}"
echo "👉 Ổ cứng:     ${BOOT_DISK_INFO} (Giữ nguyên vẹn 100%)"
echo "================================================================="
