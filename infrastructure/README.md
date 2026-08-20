# Sowfkun Verse Infrastructure (Ultra-Lean & Dedicated 1GB RAM)

Bộ kịch bản và cấu hình khởi tạo hạ tầng tự động **"1 Lệnh Duy Nhất"** cho các dịch vụ độc lập trên **Ubuntu 24.04 LTS (2 Core / 1GB RAM)**:
- **Redpanda (Kafka API)**: Port `9092` (Internal) / `9094` (External), Web Console `8080`.
- **Redis 7 / 8**: Port `6379`.
- **MongoDB 8 / Atlas Local**: Port `27017` (hỗ trợ full `$search` Lucene Engine).
- **OpenSearch 2 / 3**: Port `9200`.
- **Go Backend (API)**: Port `8080`.

---

## 🚀 Hướng Dẫn Khởi Tạo Nhanh (1 Lệnh)

### 1. Trên Server Trống (Fresh Server - Cài từ đầu)

Chạy lệnh tương ứng với loại dịch vụ của con server đó:

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

*(Hoặc nếu chạy thử nghiệm tất cả trên 1 server: `sudo bash bootstrap.sh --service=all --mode=fresh`)*

---

### 2. Trên Server Khôi Phục từ Snapshot Alibaba Cloud (Rollback)

Sau khi revert Snapshot đĩa, chỉ cần vào thư mục và chạy:
```bash
sudo bash bootstrap.sh --service=<tên_service> --mode=rollback
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
sudo nano /etc/sowfkun/alert.conf
```
Điền Token Telegram / Discord:
```ini
SERVER_NAME="Redis-Server-01"
TELEGRAM_BOT_TOKEN="123456789:AAXXXXXXXXXXXXXX"
TELEGRAM_CHAT_ID="123456789"
```

---

## 🛡️ Kiến Trúc Bảo Mật Đa Tầng (Multi-Layer Security)

### Lớp 1: Alibaba Cloud Security Group (Tường lửa Phần cứng Cloud)
- **SSH (Port 22):** Đóng hoàn toàn với `0.0.0.0/0`. Quản trị 100% qua **Alibaba Cloud Workbench / VNC Web Console**.
- **Database & Queue Ports (`27017`, `6379`, `9092`, `9200`):** CHỈ mở cho dải IP Private VPC của cụm Web/API Server.

### Lớp 2: OS Hardening & Network Kernel (`bootstrap.sh`)
- **Đồng bộ thời gian UTC:** Chuẩn hóa NTP với `ntp.aliyun.com` và `time.google.com` (chống lỗi JWT / E2EE Clock Drift).
- **Vô hiệu hóa Password SSH:** Tắt xác thực mật khẩu, chống Brute-force 100%.
- **Fail2ban & UFW:** Tự động phát hiện và ban IP quét cổng.
- **Kernel Spoofing Guard & Outbound TCP Tuning:** Bật `tcp_tw_reuse`, mở rộng 64k ephemeral ports, chống nghẽn HTTP request ra ngoài.

### Lớp 3: Docker & Application Security
- **Log Rotation Protection:** Giới hạn log tối đa 50MB x 3 file trong `daemon.json`, chống tràn ổ đĩa.
- **Tự động dọn rác Docker (Cron):** Dọn images và cache thừa lúc 3h sáng Chủ Nhật hàng tuần.
- **Resource Guard (Swap 2GB):** Ngăn ngừa Linux OOM Killer bắn chết tiến trình DB.
