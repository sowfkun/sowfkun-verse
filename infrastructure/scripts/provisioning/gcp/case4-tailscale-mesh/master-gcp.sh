#!/usr/bin/env bash
# ==============================================================================
# CASE 4: GCP TAILSCALE MESH MASTER CONTROLLER (BASH FOR LINUX/MAC)
# ==============================================================================
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "================================================================="
echo "🌐 CASE 4: GCP TAILSCALE MESH PROVISIONER & MASTER CONTROLLER"
echo "    Mô hình 4 Server Zero-Trust: Netcup (Mongo) + 3 GCP Nodes"
echo "================================================================="

echo ""
echo "Chọn tác vụ muốn thực hiện:"
echo "  [1] Áp dụng Firewall Tailscale Zero-Trust trên GCP   (01-apply-tailscale-firewalls.sh)"
echo "  [2] Cài đặt & Khởi chạy Tailscale Node trên GCP VM   (02-setup-tailscale-node.sh)"
echo "  [3] Kiểm toán An ninh & Độ trễ Mesh (Audit)          (03-audit-security.sh)"
echo "  [4] Reset & Dọn dẹp Firewall Rules cũ trên GCP       (reset-firewalls.sh)"
echo "  [5] Thoát"
echo ""
read -rp "👉 Nhập lựa chọn [1-5]: " choice

case "$choice" in
  1)
    bash "${SCRIPT_DIR}/01-apply-tailscale-firewalls.sh"
    ;;
  2)
    bash "${SCRIPT_DIR}/02-setup-tailscale-node.sh"
    ;;
  3)
    bash "${SCRIPT_DIR}/03-audit-security.sh"
    ;;
  4)
    bash "${SCRIPT_DIR}/reset-firewalls.sh"
    ;;
  *)
    echo "Tạm biệt!"
    exit 0
    ;;
esac
