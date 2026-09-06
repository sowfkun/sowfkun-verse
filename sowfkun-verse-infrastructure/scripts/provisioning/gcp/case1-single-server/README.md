# 🟢 GCP Case 1: Single Server (All-in-One)

> **Mục đích**: Chạy toàn bộ MongoDB, Redis, Kafka, OpenSearch và Go API Backend trên **1 máy ảo duy nhất** (tiết kiệm chi phí tối đa, phù hợp cho môi trường Dev / Testing / Demo).

---

## 1. Thông Số Đề Xuất
* **Machine Type**: `e2-standard-2` (2 vCPU, 8GB RAM) hoặc `e2-medium` (1-2 vCPU, 4GB RAM + Swap).
* **Network**: Mạng `default`, mở port `8080` (API) hoặc `80/443` (Web). Các port dữ liệu `27017`, `6379`, `9092` chỉ chạy nội bộ trong Docker network `app_net`.
* **IAM**: `--no-service-account --no-scopes`.

---

## 2. Kế Hoạch Script Triển Khai (Slot Dự Phòng)
* `01-create-single-vm.sh`: Khởi tạo 1 máy ảo duy nhất.
* `02-firewall-single-vm.sh`: Cấu hình mở port Web/API và chặn toàn bộ port nội bộ.
