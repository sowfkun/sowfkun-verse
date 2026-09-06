#!/usr/bin/env bash
# ==============================================================================
# GCP MULTI-ACCOUNT MASTER CONTROL CENTER (GENERIC ON-PREMISE / CLOUD WIZARD)
# ==============================================================================
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "================================================================="
echo "🧙‍♂️ GCP MULTI-ACCOUNT MASTER CONTROL CENTER"
echo "================================================================="

# 0. Quét danh sách tài khoản Google Cloud đã đăng nhập
echo ""
echo "📌 [BƯỚC 0] XÁC ĐỊNH TÀI KHOẢN GOOGLE CLOUD:"
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

echo ""
echo "================================================================="
echo "🎛️ BẢNG ĐIỀU KHIỂN TRUNG TÂM (CHỌN TÁC VỤ CẦN THỰC HIỆN):"
echo "================================================================="
echo "  [1] Tạo Custom VPC & Subnet                (01-create-vpc)"
echo "  [2] Bắt tay 2-Way VPC Peering              (02-setup-vpc-peering)"
echo "  [3] Áp dụng Tường Lửa Zero-Trust & IAP     (03-apply-firewalls)"
echo "  [4] Chuyển VM sang Subnet mới (Giữ Ổ Đĩa)  (04-attach-vm-to-vpc)"
echo "  [5] Kiểm toán & Quét Lỗ Hổng Bảo Mật       (05-audit-and-verify-security)"
echo "  [6] Mở Google IAP SSH Trực Tiếp Vào Máy    (Instant Secure SSH)"
echo "  [7] Mở Đường Hầm IAP Tunnel (Port Forward) (Generic Tunnel)"
echo "  [0] Thoát"
echo "================================================================="
read -rp "👉 Nhập lựa chọn của bạn [0-7, Mặc định: 5]: " main_choice
main_choice="${main_choice:-5}"

case "$main_choice" in
  1)
    bash "${SCRIPT_DIR}/01-create-vpc.sh"
    ;;
  2)
    bash "${SCRIPT_DIR}/02-setup-vpc-peering.sh"
    ;;
  3)
    bash "${SCRIPT_DIR}/03-apply-firewalls.sh"
    ;;
  4)
    bash "${SCRIPT_DIR}/04-attach-vm-to-vpc.sh"
    ;;
  5)
    bash "${SCRIPT_DIR}/05-audit-and-verify-security.sh"
    ;;
  6)
    echo ""
    echo "📌 DANH SÁCH MÁY ẢO TRONG PROJECT HIỆN TẠI:"
    vms_list=$(gcloud compute instances list --format="value(name,zone)" 2>/dev/null || true)
    if [[ -z "$vms_list" ]]; then
      echo "❌ Không tìm thấy máy ảo nào!"
      exit 1
    fi
    i=1
    declare -A vname_map
    declare -A vzone_map
    while IFS=$'\t' read -r vn vz; do
      echo "  [$i] $vn (Zone: $vz)"
      vname_map[$i]="$vn"
      vzone_map[$i]="$vz"
      i=$((i + 1))
    done <<< "$vms_list"
    read -rp "👉 Chọn máy cần SSH [1-$((i-1)), Mặc định: 1]: " vchoice
    vchoice="${vchoice:-1}"
    SELECTED_VM="${vname_map[$vchoice]}"
    SELECTED_ZONE="${vzone_map[$vchoice]}"
    echo "🚀 Đang mở kết nối SSH qua Google IAP vào [${SELECTED_VM}]..."
    gcloud compute ssh "${SELECTED_VM}" --zone="${SELECTED_ZONE}" --tunnel-through-iap
    ;;
  7)
    echo ""
    read -rp "👉 Nhập tên máy ảo: " TUNNEL_VM
    read -rp "👉 Nhập cổng cần mở tunnel (ví dụ: 27017, 6379, 8085): " TUNNEL_PORT
    read -rp "👉 Nhập Zone [Mặc định: us-central1-a]: " TUNNEL_ZONE
    TUNNEL_ZONE="${TUNNEL_ZONE:-us-central1-a}"
    echo "🚀 Đang mở IAP Tunnel tới [${TUNNEL_VM}:${TUNNEL_PORT}] -> localhost:${TUNNEL_PORT}..."
    gcloud compute start-iap-tunnel "${TUNNEL_VM}" "${TUNNEL_PORT}" --local-host-port="localhost:${TUNNEL_PORT}" --zone="${TUNNEL_ZONE}"
    ;;
  0)
    echo "👋 Tạm biệt!"
    exit 0
    ;;
esac
