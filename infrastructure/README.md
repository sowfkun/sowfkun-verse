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

Chạy danh sách service phân tách bằng dấu phẩy:

#### Chạy Redis + Go API trên cùng 1 VPS:
```bash
sudo bash bootstrap.sh --service=redis,api --mode=fresh
```

#### Chạy MongoDB + Redis + Kafka trên cùng 1 VPS:
```bash
sudo bash bootstrap.sh --services=mongo,redis,kafka --mode=fresh
```

#### Chạy All-in-One (Tất cả 5 dịch vụ trên 1 VPS):
```bash
sudo bash bootstrap.sh --service=all --mode=fresh
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

## 🛡️ Kiến Trúc Bảo Mật Đa Tầng (Multi-Layer Security)

### Lớp 1: Cloud Security Group (Tường lửa Phần cứng Cloud)
- **SSH (Port 22):** Đóng hoàn toàn với `0.0.0.0/0`. Quản trị qua Cloud Workbench / Web Console / SSH Key nội bộ.
- **Database & Queue Ports (`27017`, `6379`, `9092`, `9200`):** CHỈ mở cho dải IP Private VPC của cụm API Server.

### Lớp 2: OS Hardening & Network Kernel (`bootstrap.sh`)
- **Đồng bộ thời gian UTC:** Chuẩn hóa NTP (chống lệch giờ JWT / E2EE / Kafka Clock Drift).
- **Vô hiệu hóa Password SSH:** Tắt xác thực mật khẩu, chống Brute-force.
- **Fail2ban & UFW:** Tự động phát hiện và ban IP quét cổng.
- **Kernel Spoofing Guard & Outbound TCP Tuning:** Bật `tcp_tw_reuse`, mở rộng 64k ephemeral ports, chống nghẽn HTTP request ra ngoài.

### Lớp 3: Docker & Application Security
- **Shared Network `app_net`:** Kết nối nội bộ container-to-container an toàn qua DNS Docker.
- **Log Rotation Protection:** Giới hạn log tối đa 50MB x 3 file trong `daemon.json`, chống tràn ổ đĩa.
- **Tự động dọn rác Docker (Cron):** Dọn images và cache thừa lúc 3h sáng Chủ Nhật hàng tuần.
- **Resource Guard (Swap 2GB - 4GB):** Tự động scale swap, ngăn ngừa Linux OOM Killer bắn chết tiến trình DB/API.
