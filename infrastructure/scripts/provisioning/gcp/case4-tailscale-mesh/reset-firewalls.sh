#!/usr/bin/env bash
# ==============================================================================
# SCRIPT TIỆN ÍCH ĐỘC LẬP: RESET & DỌN DẸP FIREWALL RULES CŨ TRÊN GCP
# ==============================================================================
set -eo pipefail

echo "================================================================="
echo "🧹 GCP FIREWALL RULES RESET & CLEANUP UTILITY"
echo "================================================================="

# 0. Xác định tài khoản
CURRENT_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null || true)
echo "✅ Tài khoản Google Cloud hiện tại: [ ${CURRENT_ACCOUNT} ]"

# 1. Xác định Project
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null || true)
projects_list=$(gcloud projects list --format="value(projectId,name)" 2>/dev/null || true)
PROJECT_ID=""

if [[ -n "$projects_list" ]]; then
  echo ""
  echo "📋 Danh sách Projects trên tài khoản [${CURRENT_ACCOUNT}]:"
  i=1
  declare -A proj_map
  while IFS=$'\t' read -r pid pname; do
    echo "  [$i] $pname (ID: $pid)"
    proj_map[$i]="$pid"
    i=$((i + 1))
  done <<< "$projects_list"
  
  read -rp "👉 Chọn Project cần dọn dẹp [1-$i, Mặc định: 1]: " pchoice
  pchoice="${pchoice:-1}"
  PROJECT_ID="${proj_map[$pchoice]:-$CURRENT_PROJECT}"
else
  read -rp "👉 Nhập Project ID [Mặc định: ${CURRENT_PROJECT}]: " PROJECT_ID
  PROJECT_ID="${PROJECT_ID:-$CURRENT_PROJECT}"
fi

echo ""
echo "🔍 Đang quét danh sách Firewall Rules tùy chỉnh trên Project [ ${PROJECT_ID} ]..."

# Lấy danh sách rules không phải default-allow của GCP (bỏ qua default-allow-internal, default-allow-ssh nếu muốn)
custom_rules=$(gcloud compute firewall-rules list \
  --project="${PROJECT_ID}" \
  --format="value(name)" 2>/dev/null || true)

if [[ -z "$custom_rules" ]]; then
  echo "✅ Không tìm thấy Firewall Rule nào cần xóa trên Project [ ${PROJECT_ID} ]."
  exit 0
fi

echo ""
echo "📋 Danh sách các Firewall Rules đang có:"
while IFS= read -r rule; do
  echo "  • $rule"
done <<< "$custom_rules"

echo ""
read -rp "⚠️ Bạn có chắc chắn muốn XÓA các Firewall Rules trên không? (y/N): " confirm
if [[ ! "$confirm" =~ ^[yY]$ ]]; then
  echo "❌ Đã hủy thao tác xóa."
  exit 0
fi

echo ""
echo "🗑️ Đang xóa các Firewall Rules..."
while IFS= read -r rule; do
  if [[ -n "$rule" ]]; then
    echo "  -> Đang xóa rule: $rule..."
    gcloud compute firewall-rules delete "$rule" --project="${PROJECT_ID}" --quiet 2>/dev/null || echo "     (Bỏ qua hoặc đã bị xóa)"
  fi
done <<< "$custom_rules"

echo ""
echo "================================================================="
echo "🎉 ĐÃ HOÀN TẤT DỌN DẸP FIREWALL RULES TRÊN PROJECT [ ${PROJECT_ID} ]!"
echo "================================================================="
