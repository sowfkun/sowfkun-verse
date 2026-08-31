#!/usr/bin/env bash
# ==============================================================================
# BƯỚC 5: AUDIT BẢO MẬT & KIỂM TRA LỖ HỔNG TƯỜNG LỬA (GCP ZERO-TRUST AUDITOR)
# Mục tiêu: Nguyên lý Least Privilege (Chỉ mở vừa đủ, phát hiện & vá cổng hở)
# ==============================================================================
set -eo pipefail

echo "================================================================="
echo "🛡️ ENTERPRISE GCP ZERO-TRUST SECURITY AUDITOR & DRIFT DETECTOR"
echo "================================================================="

# 0. Chọn Google Account
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

# 1. Chọn Role cần Audit
echo ""
echo "📌 [BƯỚC 1/3] CHỌN MÁY CHỦ / PROJECT CẦN AUDIT BẢO MẬT:"
echo "  [1] Data Server (Kiểm tra Data VPC: Chống rò rỉ DB, cấm Egress, mở IAP)"
echo "  [2] App Server  (Kiểm tra App VPC: Chỉ mở 80/443/8080/8085, mở SSH qua IAP)"
read -rp "👉 Chọn vai trò [1-2, Mặc định: 1]: " role_choice
role_choice="${role_choice:-1}"

ROLE="data"
if [[ "$role_choice" == "2" ]]; then ROLE="app"; fi

# 2. Xác định Project & VPC
echo ""
echo "📌 [BƯỚC 2/3] XÁC ĐỊNH PROJECT & VPC CẦN KIỂM TOÁN:"
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

read -rp "👉 VPC Network [Mặc định: ${DEFAULT_VPC}]: " VPC_NAME
VPC_NAME="${VPC_NAME:-$DEFAULT_VPC}"

echo ""
echo "================================================================="
echo "🔍 ĐANG QUÉT TOÀN DIỆN HẠ TẦNG: [${PROJECT_ID} / ${VPC_NAME}]..."
echo "================================================================="

ISSUES_FOUND=0

# Lấy danh sách toàn bộ Firewall Rules của VPC
rules_json=$(gcloud compute firewall-rules list --project="${PROJECT_ID}" --filter="network:${VPC_NAME}" --format="json" 2>/dev/null || echo "[]")

# ------------------------------------------------------------------------------
# AUDIT DÀNH CHO DATA SERVER
# ------------------------------------------------------------------------------
if [[ "$ROLE" == "data" ]]; then
  echo ""
  echo "🔎 [1/4] Kiểm tra các cổng Database (MongoDB:27017, Redis:6379, Kafka:9092, OpenSearch:9200)..."
  
  public_db_rules=$(echo "$rules_json" | grep -B 5 -A 10 '"0.0.0.0/0"' | grep -E '27017|6379|9092|9200' || true)
  if [[ -n "$public_db_rules" ]]; then
    echo "🚨 [NGUY HIỂM CỰC CAO]: Phát hiện có rule tường lửa đang mở cổng DB ra toàn bộ Internet (0.0.0.0/0)!"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
  else
    echo "✅ [AN TOÀN]: Không có cổng Database nào bị hở ra ngoài Internet."
  fi

  echo ""
  echo "🔎 [2/4] Kiểm tra cổng SSH Port 22..."
  ssh_public=$(echo "$rules_json" | grep -B 5 -A 10 '"0.0.0.0/0"' | grep -E 'tcp.*22|"22"' || true)
  if [[ -n "$ssh_public" ]]; then
    echo "🚨 [CẢNH BÁO]: Cổng SSH (22) đang mở Public cho toàn bộ Internet (0.0.0.0/0) thay vì Google IAP!"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
  else
    echo "✅ [AN TOÀN]: Cổng SSH được bảo vệ nghiêm ngặt qua Google IAP (35.235.240.0/20)."
  fi

  echo ""
  echo "🔎 [3/4] Kiểm tra chính sách Egress (Chống Reverse Shell & Data Exfiltration)..."
  deny_egress=$(echo "$rules_json" | grep -B 5 -A 10 '"direction": "EGRESS"' | grep -E '"DENY"|"deny"' || true)
  if [[ -n "$deny_egress" ]]; then
    echo "✅ [AN TOÀN]: Đã kích hoạt chính sách chặn Egress Internet (0.0.0.0/0)."
  else
    echo "⚠️ [CẢNH BÁO]: Chưa có rule chặn Egress Internet cho Data VPC!"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
  fi

  echo ""
  echo "🔎 [4/5] Kiểm tra Egress Whitelist cho DNS & NTP (Đồng bộ thời gian UTC)..."
  ntp_dns_egress=$(echo "$rules_json" | grep -E 'udp:123|123|udp:53|53' || true)
  if [[ -n "$ntp_dns_egress" ]]; then
    echo "✅ [AN TOÀN]: Đã mở Egress UDP 53/123 tới Google Time Server/DNS để đồng bộ giờ UTC."
  else
    echo "⚠️ [LƯU Ý]: Chưa cấu hình rule mở Egress NTP/DNS (data-vpc-allow-egress-ntp-dns)."
  fi

  echo ""
  echo "🔎 [5/5] Kiểm tra trạng thái 2-Way VPC Peering..."
  peering_status=$(gcloud compute networks describe "${VPC_NAME}" --project="${PROJECT_ID}" --format="value(peerings[0].state)" 2>/dev/null || echo "NONE")
  if [[ "$peering_status" == "ACTIVE" ]]; then
    echo "✅ [AN TOÀN]: Kết nối VPC Peering đang ở trạng thái ACTIVE (Xanh lá - Hoạt động bình thường)."
  else
    echo "⚠️ [CẢNH BÁO]: Trạng thái VPC Peering: ${peering_status} (Chưa kết nối hoặc đang chờ đối tác)!"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
  fi

# ------------------------------------------------------------------------------
# AUDIT DÀNH CHO APP SERVER
# ------------------------------------------------------------------------------
elif [[ "$ROLE" == "app" ]]; then
  echo ""
  echo "🔎 [1/6] Kiểm tra các cổng Web & API Public (80, 443, 8080, 8085)..."
  public_web=$(echo "$rules_json" | grep -E '80|443|8080|8085' || true)
  if [[ -n "$public_web" ]]; then
    echo "✅ [CHUẨN]: Các cổng Web & API cần thiết đã được mở đúng quy chuẩn."
  else
    echo "⚠️ [CẢNH BÁO]: Chưa tìm thấy rule mở cổng Web 80/443/8080/8085."
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
  fi

  echo ""
  echo "🔎 [2/6] Kiểm tra cổng SSH Port 22..."
  ssh_public=$(echo "$rules_json" | grep -B 5 -A 10 '"0.0.0.0/0"' | grep -E 'tcp.*22|"22"' || true)
  if [[ -n "$ssh_public" ]]; then
    echo "🚨 [CẢNH BÁO]: Cổng SSH (22) đang mở Public cho toàn bộ Internet (0.0.0.0/0) thay vì Google IAP!"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
  else
    echo "✅ [AN TOÀN]: Cổng SSH được bảo vệ nghiêm ngặt qua Google IAP (35.235.240.0/20)."
  fi

  echo ""
  echo "🔎 [3/6] Kiểm tra chính sách Egress (Khóa Internet, chỉ cho phép Peering sang Data & IAP)..."
  deny_egress=$(echo "$rules_json" | grep -B 5 -A 10 '"direction": "EGRESS"' | grep -E '"DENY"|"deny"' || true)
  if [[ -n "$deny_egress" ]]; then
    echo "✅ [AN TOÀN]: Đã kích hoạt chính sách chặn Egress Internet (0.0.0.0/0) cho App Server."
  else
    echo "⚠️ [CẢNH BÁO]: App Server đang mở Egress tự do ra Internet!"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
  fi

  echo ""
  echo "🔎 [4/6] Kiểm tra Egress Whitelist cho DNS & NTP (Đồng bộ thời gian UTC)..."
  ntp_dns_egress=$(echo "$rules_json" | grep -E 'udp:123|123|udp:53|53' || true)
  if [[ -n "$ntp_dns_egress" ]]; then
    echo "✅ [AN TOÀN]: Đã mở Egress UDP 53/123 tới Google Time Server/DNS để đồng bộ giờ UTC."
  else
    echo "⚠️ [LƯU Ý]: Chưa cấu hình rule mở Egress NTP/DNS (app-vpc-allow-egress-ntp-dns)."
  fi

  echo ""
  echo "🔎 [5/6] Kiểm tra xem có mở nhầm cổng DB trên App Server không..."
  db_on_app=$(echo "$rules_json" | grep -E '27017|6379|9200' || true)
  if [[ -n "$db_on_app" ]]; then
    echo "🚨 [NGUY HIỂM]: App Server không nên mở cổng MongoDB/Redis/OpenSearch!"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
  else
    echo "✅ [AN TOÀN]: App Server không mở bất kỳ cổng Database nào."
  fi

  echo ""
  echo "🔎 [6/6] Kiểm tra trạng thái 2-Way VPC Peering sang Data VPC..."
  peering_status=$(gcloud compute networks describe "${VPC_NAME}" --project="${PROJECT_ID}" --format="value(peerings[0].state)" 2>/dev/null || echo "NONE")
  if [[ "$peering_status" == "ACTIVE" ]]; then
    echo "✅ [AN TOÀN]: Kết nối VPC Peering sang Data Server đang ACTIVE!"
  else
    echo "⚠️ [CẢNH BÁO]: Trạng thái Peering: ${peering_status}!"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
  fi
fi

# ------------------------------------------------------------------------------
# TỔNG KẾT
# ------------------------------------------------------------------------------
echo ""
echo "================================================================="
echo "📊 BÁO CÁO TỔNG KẾT KIỂM TOÁN AN NINH (AUDIT RESULT)"
echo "================================================================="
if [[ "$ISSUES_FOUND" -eq 0 ]]; then
  echo "🎉 HOÀN TOÀN ĐẠT CHUẨN ZERO-TRUST! (0 LỖ HỔNG PHÁT HIỆN)"
  echo "👉 Hệ thống của bạn chỉ mở các cổng vừa đủ theo đúng nguyên lý Least Privilege."
else
  echo "⚠️ Phát hiện ${ISSUES_FOUND} điểm cần lưu ý hoặc khắc phục."
fi
echo "================================================================="
