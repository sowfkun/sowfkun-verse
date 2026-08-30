# ☁️ Alibaba Cloud (AliCloud) Multi-Server & CEN Architecture

Thư mục này chuẩn bị sẵn kiến trúc và cấu trúc script triển khai hệ thống trên nền tảng **Alibaba Cloud**.

---

## 1. Mô Hình Tương Đương Giữa GCP và Alibaba Cloud

| Thành Phần | Google Cloud Platform (GCP) | Alibaba Cloud (AliCloud) |
| :--- | :--- | :--- |
| **Máy Ảo (VM)** | Compute Engine (GCE) | Elastic Compute Service (ECS) |
| **Mạng Ảo (VPC)** | Virtual Private Cloud (VPC) | Virtual Private Cloud (VPC) |
| **Ghép Nối Mạng** | VPC Network Peering | Cloud Enterprise Network (CEN) / VPC Peering |
| **Tường Lửa** | GCP VPC Firewall Rules | Security Groups (SG) & Network ACLs |
| **Chặn Metadata** | `169.254.169.254` (gcloud disable legacy) | `100.100.100.200` & `169.254.169.254` |
| **Quản Trị An Toàn** | Google IAP Tunnel | Alibaba Cloud Session Manager / Bastionhost |

---

## 2. Kế Hoạch Script Triển Khai (Upcoming Scripts)

Khi mở rộng sang Alibaba Cloud, các script sẽ bao gồm:
* `01-create-ecs.sh`: Tạo 2 máy ảo ECS (Data Node & App Node) không gán RAM Role (Resource Access Management).
* `02-security-groups.sh`: Cấu hình Security Group 1 chiều (App $\rightarrow$ Data ports 27017, 6379, 9092) và khóa Outbound Internet trên Data Node.
* `03-cen-attach.sh`: Gắn 2 VPC vào Cloud Enterprise Network (CEN) để định tuyến nội bộ an toàn.
