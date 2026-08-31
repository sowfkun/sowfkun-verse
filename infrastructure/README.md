# Enterprise Infrastructure (Ultra-Lean & Flexible Multi-Service Deployment)

Bộ kịch bản và cấu hình khởi tạo hạ tầng tự động **"1 Lệnh Duy Nhất"** cho các dịch vụ trên **Ubuntu 24.04 LTS**:
- **Redpanda (Kafka API)**: Port `9092` (Internal) / `9094` (External), Web Console `8085`.
- **Redis 7 / 8**: Port `6379`.
- **MongoDB 8 / Atlas Local**: Port `27017` (hỗ trợ full `$search` Lucene Engine).
- **OpenSearch 2 / 3**: Port `9200`.
- **Go Backend (API)**: Port `8080`.
- **Egress Gateway / Webhook Dispatcher**: Port `8090` (SSRF Defense & Outbound proxy).
- **Central Monitoring Hub**: Grafana `3000`, Loki `3100`, Prometheus `9090`.
- **Promtail & Node Exporter Agent**: Port `9100` (Gom log container & metrics gửi về Hub).
- **Docker Network**: `app_net` (tất cả containers cùng VPS tự động kết nối nội bộ).

---

## 🚀 Hướng Dẫn Khởi Tạo

### Cách 1: Menu Tương Tác Trực Quan (Interactive Multi-Select)

Chỉ cần chạy lệnh mà không cần truyền tham số:
```bash
sudo bash bootstrap.sh
```
Hệ thống sẽ hiển thị menu chọn các dịch vụ cần chạy:
```text
=================================================================
📋 CHỌN CÁC DỊCH VỤ CẦN CHẠY TRÊN VPS NÀY
=================================================================
  1) Redis Cache (Port 6379)
  2) MongoDB Atlas Local (Port 27017)
  3) Redpanda / Kafka (Port 9092 / Console 8085)
  4) OpenSearch (Port 9200)
  5) Go API Backend (Port 8080)
  6) Egress Gateway / Webhook Dispatcher (Port 8090)
  7) Central Monitoring Hub (Grafana 3000, Loki 3100, Prometheus 9090)
  8) Promtail & Node Exporter Agent (Gom log & metrics gửi về Hub)
  9) Tất cả (All-in-One: Cài & chạy toàn bộ dịch vụ)
=================================================================
👉 Nhập lựa chọn của bạn [1-9]: 1,2,5,8
```

---

### Cách 2: Chọn Tổ Hợp Nhiều Dịch Vụ Chạy Chung 1 VPS (CLI)

Chạy danh sách service phân tách bằng dấu phẩy, kèm theo `--profile=mini|huge|standard`:

#### Profile `mini` (Dành cho VPS 1-2GB RAM / GCP e2-micro/small test):
```bash
sudo bash bootstrap.sh --service=all --profile=mini --mode=fresh
```

#### Profile `huge` (Dành cho Server 4-8 Cores, 4-8GB+ RAM):
```bash
sudo bash bootstrap.sh --service=all --profile=huge --mode=fresh
```

#### Chạy Redis + Go API trên cùng 1 VPS (Profile mini):
```bash
sudo bash bootstrap.sh --service=redis,api --profile=mini --mode=fresh
```

#### Chạy MongoDB + Redis + Kafka trên cùng 1 VPS:
```bash
sudo bash bootstrap.sh --services=mongo,redis,kafka --profile=mini --mode=fresh
```

---

### Cách 3: Chạy Từng Service Độc Lập (Dedicated 1 VPS per Service)

#### Server Redpanda (Kafka):
```bash
sudo bash bootstrap.sh --service=kafka --mode=fresh
```

#### Server Redis:
```bash
sudo bash bootstrap.sh --service=redis --mode=fresh
```

#### Server MongoDB (Atlas Local):
```bash
sudo bash bootstrap.sh --service=mongo --mode=fresh
```

#### Server OpenSearch:
```bash
sudo bash bootstrap.sh --service=opensearch --mode=fresh
```

#### Server Go Backend (API):
```bash
sudo bash bootstrap.sh --service=api --mode=fresh
```

---

### 4. Trên Server Khôi Phục từ Snapshot Cloud (Rollback)

Sau khi revert Snapshot đĩa, chỉ cần vào thư mục và chạy:
```bash
sudo bash bootstrap.sh --service=redis,api --mode=rollback
```

---

## 🚨 Hệ Thống Giám Sát & Cảnh Báo Telegram / Grafana

Mỗi server sau khi chạy `bootstrap.sh` sẽ tự động kích hoạt **Monitor Cron Job** và tích hợp vào hệ thống quan sát tập trung:
- **Quét tức thời mỗi 1 phút**: Tự động cảnh báo `🚨 DANGER` khi **CPU > 85%**, **RAM > 85%**, **Swap > 70%**, **Disk > 85%** hoặc container bị sập (kèm chống spam cooldown 30p & tự động báo `🟢 PHỤC HỒI`).
- **Báo cáo định kỳ mỗi 3 tiếng**: Gửi bản tin tổng quan `🔵 PERIODIC SUMMARY` với giờ Việt Nam (`+7 GMT`).
- **Quản lý Log Container & Metrics**: Promtail tự động gom log về Loki, Prometheus scrape metrics, và Grafana hiển thị trực quan tại `http://localhost:3000`.

### Cấu hình nhận thông báo:
Mở file cấu hình trên server:
```bash
sudo nano /etc/infra/alert.conf
```
Điền cấu hình:
```ini
SERVER_NAME="SOWFKUN-NODE"
ALERT_FORWARD_URL="http://10.20.0.2:8080/api/v1/system/alert/telegram"
TELEGRAM_BOT_TOKEN="123456789:AAXXXXXXXXXXXXXX"
TELEGRAM_CHAT_ID="123456789"
```

---

---

## 📦 Chế Độ On-Premise Binary (Bảo Vệ Source Code / 1-Click Deploy)

Dành cho trường hợp **bàn giao khách hàng On-Premise** hoặc triển khai không muốn để lộ mã nguồn Go:

1. **Bước 1 — Đóng gói file binary tĩnh trên máy dev**:
   - Trên Windows: Chạy PowerShell `.\scripts\app\build_onpremise.ps1`
   - Trên Linux/macOS: Chạy `bash scripts/app/build_onpremise.sh`
   - File binary `app-api` sẽ tự động được sinh ra trong thư mục `infrastructure/api/app-api`.

2. **Bước 2 — Bàn giao & Triển khai On-Premise**:
   - Bạn chỉ cần copy duy nhất thư mục `infrastructure/` (đã có `app-api` và các template `.env.<profile>`) sang máy chủ khách hàng.
   - Chạy lệnh:
   ```bash
   cd infrastructure
   sudo bash bootstrap.sh --service=all --profile=mini --mode=fresh
   ```
   👉 `bootstrap.sh` sẽ tự động nhận diện file binary `app-api`, dùng [Dockerfile.binary](api/Dockerfile.binary) siêu nhẹ (~10MB Alpine) và khởi chạy ngay trong 2 giây mà **không cần cài Go, không build lâu, không lộ 1 dòng source code nào**!

---

## 🛠️ Cấu Trúc Script Hạ Tầng & Triển Khai (Scripts Hierarchy)

Toàn bộ script được phân tách rõ ràng theo mục đích:
```text
infrastructure/scripts/
├── app/                        # Quản lý vòng đời ứng dụng
│   ├── deploy-staging.sh       # Deploy / Cập nhật API thủ công trên Staging
│   ├── build_onpremise.sh      # Build Linux Static Binary (AMD64)
│   ├── build_onpremise.ps1     # Build Static Binary trên Windows
│   ├── monitor.sh              # Giám sát RAM/Disk + Bắn Alert Telegram/Discord
│   └── alert.conf.example      # File cấu hình mẫu cho hệ thống cảnh báo
│
└── provisioning/               # Khởi tạo & Bảo mật hạ tầng đa nền tảng
    ├── common/
    │   └── os-hardening.sh     # Chặn metadata IP (169.254.169.254), SSH Hardening, Sysctl
    ├── gcp/                    # Google Cloud Platform (Zero-Trust VPC & Firewall 1 chiều)
    │   ├── case1-single-server/            # [Slot] All-in-One trên 1 VM
    │   ├── case2-single-account-multi-server/ # [Slot] 2 VM trên 1 Account cùng Subnet
    │   └── case3-multi-account-peering/    # 2 VM trên 2 Account kết nối 2-Way VPC Peering
    │       ├── master-gcp.sh / .ps1        # [All-in-One] Bảng điều khiển trung tâm
    │       ├── 01-create-vpc.sh            # Tạo Custom VPC & Subnet
    │       ├── 02-setup-vpc-peering.sh     # Thiết lập kết nối 2-way VPC Peering
    │       ├── 03-apply-firewalls.sh       # Áp dụng Tường lửa Zero-Trust đối xứng & IAP
    │       ├── 04-attach-vm-to-vpc.sh      # Chuyển VM sang Subnet (Zero Data Loss)
    │       └── 05-audit-and-verify-security.sh # Kiểm toán an ninh & quét lệch cấu hình
    ├── alibaba/                # Alibaba Cloud (Sẵn sàng mở rộng ECS, CEN, Security Group)
    └── onpremise/              # On-Premise / Bare-Metal (VLAN, Subnet Isolation, UFW)
```

---

## 🤖 Tự Động Hóa CI/CD Với GitHub Actions (Cloud Build & SSH Deploy)

Dự án áp dụng mô hình CI/CD tiêu chuẩn công nghiệp: Biên dịch trên GitHub Cloud và tự động triển khai qua SSH để **máy chủ luôn nhẹ 100% không tốn CPU/RAM để compile**:

1. **Thêm 3 Secret trong GitHub Repo Settings** (`Settings -> Secrets and variables -> Actions`):
   - `SERVER_HOST`: IP máy chủ triển khai (ví dụ `35.209.234.134`).
   - `SERVER_USER`: Username SSH của máy chủ (ví dụ `ubuntu`).
   - `SSH_PRIVATE_KEY`: Toàn bộ nội dung OpenSSH Private Key để đăng nhập vào máy chủ.

2. **Luồng Triển Khai Tự Động**:
   - Khi `git push origin dev`: GitHub Cloud Runner (`ubuntu-latest`) tự động biên dịch Go binary siêu tốc (5s), nạp sang máy chủ qua SCP và kích hoạt `docker compose up -d api` an toàn trong 2 giây.
   - Khi phát hành Production trên `master`: Vào tab Actions, chọn **Manual Deploy Production API**, gõ chữ `DEPLOY` để xác nhận release an toàn.

