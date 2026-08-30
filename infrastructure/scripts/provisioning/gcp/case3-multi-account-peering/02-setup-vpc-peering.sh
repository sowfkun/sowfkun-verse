#!/usr/bin/env bash
# ==============================================================================
# BƯỚC 2: WIZARD THIẾT LẬP 2-WAY VPC PEERING TỪNG BƯỚC (HỖ TRỢ ĐA TÀI KHOẢN)
# ==============================================================================
set -eo pipefail

echo "================================================================="
echo "🧙‍♂️ ENTERPRISE VPC PEERING WIZARD (GCP 2-WAY CONNECTION)"
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

# 1. Chọn Role (Máy hiện tại đang đứng)
echo ""
echo "📌 [BƯỚC 1/5] XÁC ĐỊNH MÁY CHỦ BẠN ĐANG CẤU HÌNH:"
echo "  [1] Data Server (Data Account - Chứa MongoDB, Redis)"
echo "  [2] App Server  (App Account - Chứa Go API, Web)"
read -rp "👉 Chọn vai trò [1-2, Mặc định: 1]: " role_choice
role_choice="${role_choice:-1}"

ROLE="data"
if [[ "$role_choice" == "2" ]]; then ROLE="app"; fi

# 2. Xác định Local Project & Local VPC
echo ""
echo "📌 [BƯỚC 2/5] PROJECT & VPC CỦA MÁY HIỆN TẠI:"
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null || true)
projects_list=$(gcloud projects list --format="value(projectId,name)" 2>/dev/null || true)
LOCAL_PROJECT=""

if [[ -n "$projects_list" ]]; then
  echo "📋 Danh sách Projects trên tài khoản [${ACTIVE_ACCOUNT}]:"
  i=1
  declare -A proj_map
  while IFS=$'\t' read -r pid pname; do
    echo "  [$i] $pname (ID: $pid)"
    proj_map[$i]="$pid"
    i=$((i + 1))
  done <<< "$projects_list"
  
  read -rp "👉 Chọn Local Project [1-$i, Mặc định: 1]: " pchoice
  pchoice="${pchoice:-1}"
  LOCAL_PROJECT="${proj_map[$pchoice]:-$CURRENT_PROJECT}"
else
  read -rp "👉 Nhập Local Project ID [Mặc định: ${CURRENT_PROJECT}]: " LOCAL_PROJECT
  LOCAL_PROJECT="${LOCAL_PROJECT:-$CURRENT_PROJECT}"
fi

DEFAULT_LOCAL_VPC="data-server-vpc"
if [[ "$ROLE" == "app" ]]; then DEFAULT_LOCAL_VPC="app-server-vpc"; fi

read -rp "👉 Local VPC Name [Mặc định: ${DEFAULT_LOCAL_VPC}]: " LOCAL_VPC
LOCAL_VPC="${LOCAL_VPC:-$DEFAULT_LOCAL_VPC}"

# 3. Xác định Peer Project & Peer VPC (Máy đối diện)
echo ""
echo "📌 [BƯỚC 3/5] THÔNG TIN MÁY CHỦ ĐỐI DIỆN CẦN KẾT NỐI (PEER):"
DEFAULT_PEER_VPC="app-server-vpc"
TARGET_LABEL="App Server"
if [[ "$ROLE" == "app" ]]; then
  DEFAULT_PEER_VPC="data-server-vpc"
  TARGET_LABEL="Data Server"
fi

read -rp "👉 Nhập Project ID của máy đối diện (${TARGET_LABEL}): " PEER_PROJECT
if [[ -z "$PEER_PROJECT" ]]; then
  echo "❌ Lỗi: Bắt buộc phải có Project ID của máy đối diện!"
  exit 1
fi

read -rp "👉 Peer VPC Name của máy đối diện [Mặc định: ${DEFAULT_PEER_VPC}]: " PEER_VPC
PEER_VPC="${PEER_VPC:-$DEFAULT_PEER_VPC}"

PEERING_NAME="peer-${LOCAL_VPC}-to-${PEER_VPC}"

# 4. Bảng tổng kết & Xác nhận
echo ""
echo "================================================================="
echo "📋 BẢNG TỔNG KẾT KẾT NỐI PEERING TRƯỚC KHI THỰC THI"
echo "================================================================="
echo "  • Local Account: ${ACTIVE_ACCOUNT}"
echo "  • Local Project: ${LOCAL_PROJECT}"
echo "  • Local VPC:     ${LOCAL_VPC}"
echo "  • Peer Project:  ${PEER_PROJECT}"
echo "  • Peer VPC:      ${PEER_VPC}"
echo "  • Peering Name:  ${PEERING_NAME}"
echo "================================================================="
read -rp "❓ Bạn có xác nhận thiết lập kết nối Peering này không? [Y/n, Mặc định: Y]: " confirm
confirm="${confirm:-Y}"

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "🚫 Đã hủy bỏ thao tác."
  exit 0
fi

echo ""
echo "🚀 Đang thiết lập kết nối Peering [${PEERING_NAME}]..."
gcloud compute networks peerings create "${PEERING_NAME}" \
  --project="${LOCAL_PROJECT}" \
  --network="${LOCAL_VPC}" \
  --peer-project="${PEER_PROJECT}" \
  --peer-network="${PEER_VPC}" \
  --auto-create-routes

echo ""
echo "================================================================="
echo "🎉 HOÀN TẤT THIẾT LẬP PEERING: [${LOCAL_VPC}] ──► [${PEER_VPC}]!"
echo "⚠️ Lưu ý: Để kết nối chuyển sang ACTIVE, bạn cần chạy script này một lần nữa trên tài khoản đối diện."
echo "================================================================="
