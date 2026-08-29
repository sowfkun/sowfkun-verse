# Enterprise Infrastructure (Ultra-Lean & Flexible Multi-Service Deployment)

Bộ kịch bản và cấu hình khởi tạo hạ tầng tự động **"1 Lệnh Duy Nhất"** cho các dịch vụ trên **Ubuntu 24.04 LTS**:
- **Redpanda (Kafka API)**: Port `9092` (Internal) / `9094` (External), Web Console `8085`.
- **Redis 7 / 8**: Port `6379`.
- **MongoDB 8 / Atlas Local**: Port `27017` (hỗ trợ full `$search` Lucene Engine).
- **OpenSearch 2 / 3**: Port `9200`.
- **Go Backend (API)**: Port `8080`.
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
  6) Tất cả (All-in-One: Cài & chạy toàn bộ 5 dịch vụ)
=================================================================
👉 Nhập lựa chọn của bạn [1-6]: 1,2,5
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

## 🚨 Hệ Thống Giám Sát & Cảnh Báo Telegram / Discord

Mỗi server sau khi chạy `bootstrap.sh` sẽ tự động kích hoạt **Monitor Cron Job** (chạy mỗi 5 phút, ăn 0MB RAM):
- Tự động cảnh báo khi **RAM > 85%**, **Swap > 70%**, **Disk > 85%**.
- Tự động cảnh báo khi có **Docker Container bị sập hoặc Unhealthy**.
- Tự động thông báo khi hệ thống hồi phục về bình thường (**RECOVERED**).

### Cấu hình nhận thông báo:
Mở file cấu hình trên server:
```bash
sudo nano /etc/infra/alert.conf
```
Điền Token Telegram / Discord:
```ini
SERVER_NAME="App-Server-01"
TELEGRAM_BOT_TOKEN="123456789:AAXXXXXXXXXXXXXX"
TELEGRAM_CHAT_ID="123456789"
```

---

---

## 📦 Chế Độ On-Premise Binary (Bảo Vệ Source Code / 1-Click Deploy)

Dành cho trường hợp **bàn giao khách hàng On-Premise** hoặc triển khai không muốn để lộ mã nguồn Go:

1. **Bước 1 — Đóng gói file binary tĩnh trên máy dev**:
   - Trên Windows: Chạy PowerShell `.\build_onpremise.ps1`
   - Trên Linux/macOS: Chạy `bash build_onpremise.sh`
   - File binary `app-api` sẽ tự động được sinh ra trong thư mục `infrastructure/api/app-api`.

2. **Bước 2 — Bàn giao & Triển khai On-Premise**:
   - Bạn chỉ cần copy duy nhất thư mục `infrastructure/` (đã có `app-api` và `.env.example`) sang máy chủ khách hàng.
   - Chạy lệnh:
   ```bash
   cd infrastructure
   sudo bash bootstrap.sh --service=all --profile=mini --mode=fresh
   ```
   👉 `bootstrap.sh` sẽ tự động nhận diện file binary `app-api`, dùng [Dockerfile.binary](api/Dockerfile.binary) siêu nhẹ (~10MB Alpine) và khởi chạy ngay trong 2 giây mà **không cần cài Go, không build lâu, không lộ 1 dòng source code nào**!

---

## 🤖 Tự Động Hóa CI/CD Với GitHub Actions Self-Hosted Runner

Tích hợp Runner trực tiếp trên máy chủ để tự động cập nhật Backend mỗi khi Push code:

```bash
sudo bash bootstrap.sh --service=all --profile=mini --gh-token="YOUR_GITHUB_RUNNER_TOKEN"
```
- Khi truyền `--gh-token`, script sẽ tự động tải runner, đăng ký và cài đặt thành **Systemd Service** chạy ngầm vĩnh viễn trên VPS.
- Từ các lần cập nhật tiếp theo, chỉ cần `git push` là GitHub Actions sẽ tự build và deploy không cần SSH vào server.

