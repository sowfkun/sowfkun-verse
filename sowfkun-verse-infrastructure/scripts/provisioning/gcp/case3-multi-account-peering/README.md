# GCP Case 3: Kiến Trúc Multi-Server trên Các Account GCP Độc Lập (Custom VPC Peering)

Hướng dẫn triển khai mô hình hạ tầng chuẩn **Universal Custom VPC, Peering, Zero-Trust Firewall & VM Migration**:

---

## 🏗️ Tổng Quan Kiến Trúc Mạng

```
┌──────────────────────────────────────────────┐        ┌──────────────────────────────────────────────┐
│        DATA ACCOUNT (Data Server)            │        │          APP ACCOUNT (App Server)            │
│                                              │        │                                              │
│  VPC: data-server-vpc (10.10.0.0/24)         │ 2-Way  │  VPC: app-server-vpc (10.20.0.0/24)          │
│  Subnet: subnet-data-server (us-central1)    │ Peering│  Subnet: subnet-app-server (us-central1)     │
│  Private IP: 10.10.0.2                       │◄──────►│  Private IP: 10.20.0.2                       │
│                                              │        │                                              │
│  • MongoDB Replica Set (:27017)              │        │  • Go API Backend (:8080)                    │
│  • Redis Cluster (:6379)                     │        │  • Redpanda Kafka Internal (:9092)           │
│  • OpenSearch (:9200)                        │        │  • Redpanda Web Console (:8085 via IAP)      │
│  • Egress Deny All (0.0.0.0/0)               │        │  • Public Ingress: KHÓA 100% (Cloudflare)    │
│  • IAP SSH / Monitoring (:22, :3000)         │        │  • Google IAP SSH & Console (:22, :8085)     │
└──────────────────────────────────────────────┘        └──────────────────────────────────────────────┘
```

---

## 🚀 Quy Trình Triển Khai 5 Bước Chuẩn Doanh Nghiệp (Interactive Wizards)

### 1️⃣ Bước 1: Tạo Custom VPC (`01-create-vpc.sh`)
* Tạo `data-server-vpc` (`10.10.0.0/24`) trên Data Account và `app-server-vpc` (`10.20.0.0/24`) trên App Account.
  ```bash
  bash 01-create-vpc.sh
  ```

---

### 2️⃣ Bước 2: Bắt Tay 2-Way VPC Peering (`02-setup-vpc-peering.sh`)
* Thiết lập đường truyền cáp quang riêng Google giữa 2 VPC (`data-server-vpc` $\leftrightarrow$ `app-server-vpc`).
  ```bash
  bash 02-setup-vpc-peering.sh
  ```

---

### 3️⃣ Bước 3: Áp Dụng Tường Lửa Zero-Trust (`03-apply-firewalls.sh`)
* Thiết lập chính sách khóa cổng, cô lập DB và bảo vệ SSH qua Google IAP cho cả 2 server.
  ```bash
  bash 03-apply-firewalls.sh
  ```

---

### 4️⃣ Bước 4: Chuyển VM Sang Custom VPC Mới (`04-attach-vm-to-vpc.sh`)
* Chuyển VM Data Server sang `data-server-vpc` (`10.10.0.2`) và VM App Server sang `app-server-vpc` (`10.20.0.2`).
* 👉 **Bảo toàn 100% ổ cứng (Boot Disk), không mất bất kỳ dữ liệu hay container nào**, gỡ bỏ Service Account thừa (`--no-service-account --no-scopes`).
  ```bash
  bash 04-attach-vm-to-vpc.sh
  ```

---

### 5️⃣ Bước 5: Kiểm Toán & Quét Lỗ Hổng Bảo Mật (`05-audit-and-verify-security.sh`)
* Quét xem có ai vào console chỉnh sửa làm hở port DB hoặc SSH ra ngoài Internet hay không.
* Xác thực trạng thái 2-Way VPC Peering `ACTIVE`.
  ```bash
  bash 05-audit-and-verify-security.sh
  ```
