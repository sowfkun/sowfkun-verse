# 🟡 GCP Case 2: Multi-Server Trên 1 Account (Cùng 1 Subnet)

> **Mục đích**: Tách biệt máy chủ Data (MongoDB, Redis, Kafka) và máy chủ App (API, Web) trên **cùng 1 Project GCP / cùng 1 Subnet**, không tốn phí truyền dữ liệu VPC Peering.

---

## 1. Thông Số Đề Xuất
* **Server Data (`data-node`)**: `e2-standard-2`, không có Public IP (`--no-address`).
* **Server App (`app-node`)**: `e2-standard-2`, có Public IP để tiếp nhận traffic người dùng.
* **Firewall Logic**: Áp dụng theo **Network Tags** (`source-tags=app-node` $\rightarrow$ `target-tags=data-node`).
* **IAM**: Cả 2 máy đều `--no-service-account --no-scopes`.

---

## 2. Kế Hoạch Script Triển Khai (Slot Dự Phòng)
* `01-create-vms.sh`: Khởi tạo 2 VM trên cùng 1 VPC.
* `02-firewall-tag-based.sh`: Cấu hình firewall 1 chiều và khóa Egress Data Node dựa trên Network Tags.
