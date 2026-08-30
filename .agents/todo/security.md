# 🛡️ Kiến Trúc Bảo Mật & Kế Hoạch Triển Khai (Security Checklist)

Tài liệu này theo dõi và phân định rõ ràng giữa **những giải pháp bảo mật đã thực sự triển khai & kiểm chứng** và **những hạng mục còn đang trong lộ trình (TODO)** của hệ thống Sowfkun Verse.

---

## 📊 Bảng Tổng Hợp Tiến Độ Bảo Mật

| Hạng Mục / Lĩnh Vực | Trạng Thái Thực Tế | Ghi Chú / Bằng Chứng Triển Khai |
| :--- | :---: | :--- |
| **Multi-Account 2-Way VPC Peering** | ✅ **DONE** | Đã kết nối `data-server-vpc` (`10.10.0.0/24`) và `app-server-vpc` (`10.20.0.0/24`) qua 2 tài khoản GCP độc lập |
| **Symmetrical Zero-Trust Egress Deny** | ✅ **DONE** | Cả 2 Server bị chặn toàn bộ Internet Outbound (`0.0.0.0/0` Deny Priority 1000), chỉ cho phép Peering nội bộ và IAP Return (Priority 900) |
| **Principle of Least Privilege (PoLP)** | ✅ **DONE** | Cả 2 VM đã tháo gỡ hoàn toàn Service Account (`--no-service-account --no-scopes`) |
| **Zero Public Exposure (IAP Protected)** | ✅ **DONE** | Toàn bộ cổng Database & Quản trị (`22, 27017, 6379, 8085, 9092`) bị khóa 100% khỏi Internet, chỉ truy cập qua Google IAP (`35.235.240.0/20`) |
| **E2EE & Application Crypto** | ✅ **DONE** | Mã hóa lai RSA-2048 + AES-256-GCM, Blind Index Hash Pepper cho tìm kiếm mã hóa |
| **Multi-Tenant Data Isolation** | ✅ **DONE** | Tầng UseCase & Repository ép buộc Tenant ID Check & Projection Safety (`tid`, `is_del`) |
| **Egress Webhook Dispatcher / Cloud NAT** | ⏳ **TODO** | Cần thiết lập Stateless Proxy/Relay để chuyển tiếp Webhook/Email an toàn khi App Server bị khóa Internet |
| **Cloud Metadata Protection (SSRF)** | ⏳ **TODO** | Chặn IP Link-Local `169.254.169.254` qua iptables trên các server |
| **LAN / RFC 1918 SSRF Validator** | ⏳ **TODO** | Validate URL/IP của đối tác gửi lên, chặn gọi ngược vào dải private (`10.0.0.0/8`, `127.0.0.1`, `172.16.0.0/12`, `192.168.0.0/16`) |
| **DNS Rebinding & Response Bomb Guard** | ⏳ **TODO** | Ghim IP khi phân giải tên miền (IP Pinning) và giới hạn kích thước Max Response Payload (tránh OOM) |
| **Prometheus & Grafana Monitoring Stack**| ⏳ **TODO** | Dựng cAdvisor + Prometheus + Grafana giám sát nội bộ qua IAP Tunnel |
| **Kafka Dead Letter Queue (DLQ) & Retry** | ⏳ **TODO** | Cơ chế Exponential Backoff & Topic DLQ lưu vết khi Consumer retry thất bại quá số lần quy định |
| **Proactive Alertmanager (Telegram/Slack)** | ⏳ **TODO** | Tự động bắn thông báo khi container crash, RAM/Disk chạm ngưỡng nguy hiểm |

---

## 1. Chi Tiết Các Hạng Mục ĐÃ TRIỂN KHAI THỰC TẾ (DONE)

### A. Hạ Tầng Mạng & Tường Lửa Đối Xứng (Network & VPC Peering)
- [x] **Tách Biệt Môi Trường Độc Lập**: Server 1 (Data Server: MongoDB, Redis) và Server 2 (App Server: Go API, Redpanda Kafka) nằm trên 2 Project GCP và 2 VPC riêng biệt (`data-server-vpc` và `app-server-vpc`).
- [x] **2-Way VPC Peering Đối Xứng**: Thiết lập peering 2 chiều trạng thái `ACTIVE` giữa `project-cfc4d426-e0f0-47cf-866` và `sowfkun-verse`.
- [x] **Khóa Chặt Egress Internet (Data Server)**: Luật `data-vpc-deny-egress-internet` (Priority 1000, `0.0.0.0/0`) ngăn chặn tuyệt đối Data Server bị khai thác Reverse Shell hoặc thất thoát dữ liệu ra ngoài.
- [x] **Khóa Chặt Egress Internet (App Server)**: Luật `app-vpc-deny-egress-internet` (Priority 1000, `0.0.0.0/0`) cô lập App Server khỏi kết nối Internet tự do.
- [x] **Phân Quyền Luồng Nội Bộ (Data Diode / Segmentation)**:
  - Data Server chỉ mở cổng `27017, 6379, 9092, 9200` cho dải IP của App Server (`10.20.0.0/24`).
  - App Server mở Egress sang Data Server (`10.10.0.0/24`) với Priority 900.
- [x] **Bảo Vệ Truy Cập Bằng Google IAP (Identity-Aware Proxy)**:
  - Cổng SSH (`22`), MongoDB (`27017`), Redis (`6379`), Kafka Broker (`9092`), Console (`8085`) chỉ mở cho dải IP IAP của Google (`35.235.240.0/20`).
  - Lập trình viên kết nối từ máy local qua đường hầm mã hóa bảo mật có chứng thực danh tính (IAP Tunnel), không lộ IP public hay port DB ra thế giới.
- [x] **Gỡ Bỏ Quyền Hạn Dư Thừa (PoLP)**: Cả 2 máy ảo đều khởi tạo với `--no-service-account --no-scopes`, vô hiệu hóa hoàn toàn nguy cơ hacker chiếm quyền GCP Project thông qua VM.

### B. Bảo Mật Tầng Ứng Dụng (Application Layer Security)
- [x] **Mã Hóa Đầu Cuối (E2EE)**: Cơ chế bắt tay Hybrid RSA-2048 + AES-256-GCM mã hóa payload giữa Client và API.
- [x] **Bảo Mật Cơ Sở Dữ Liệu & Mã Hóa Dữ Liệu Nhạy Cảm**:
  - Mã hóa cấp trường (Field-level Encryption) với khóa luân phiên `ACTIVE_ENCRYPTION_KEY_VERSION`.
  - Cơ chế tìm kiếm trên dữ liệu mã hóa thông qua mã băm HMAC-SHA256 kèm Blind Index Pepper bí mật (`BLIND_INDEX_PEPPER`).
- [x] **Cô Lập Dữ Liệu Multi-Tenant (Tenant Isolation)**:
  - Tầng UseCase bắt buộc kiểm tra quyền sở hữu Tenant ID (`entity.TenantID != q.TenantID`).
  - Tầng Repository tự động gán `"tid": 1` và `"is_del": 1` vào Projection map để chống rò rỉ dữ liệu chéo giữa các công ty.
- [x] **Rate Limiting Đa Cấp**: Giới hạn tốc độ theo thuật toán Token Bucket nguyên tử trên Redis (Public, CUD, Auth).
- [x] **Tự Động Quét & Kiểm Toán Định Kỳ**: Bộ script `05-audit-and-verify-security.sh` tự động quét drift detector phát hiện ngay lập tức nếu có ai chỉnh sửa mở port hở trên Console.

---

## 2. Chi Tiết Các Hạng Mục CẦN TRIỂN KHAI TIẾP THEO (TODO)

### A. Hạ Tầng Giao Tiếp Internet Ngoài (Egress Proxy / Webhook Dispatcher)
- [ ] **Xây Dựng Dịch Vụ Webhook Dispatcher / NAT Relay**:
  - Do App Server đã bị chặn Egress Internet 100%, cần triển khai một Proxy Service siêu nhẹ (Golang Stateless Egress Dispatcher) nằm trong vùng DMZ hoặc cấu hình Cloud NAT có kiểm soát để nhận payload từ Kafka/Asynq và bắn HTTP Request ra các dịch vụ bên thứ ba (Resend Email, Đối tác Webhook).
- [ ] **Hardening iptables Drop Cloud Metadata**:
  - Chạy lệnh chặn IP Link-Local metadata `169.254.169.254` qua `iptables` trên toàn bộ các VM để chống kỹ thuật Cloud SSRF.

### B. Phòng Vệ Tấn Công SSRF & Webhook An Toàn
- [ ] **Chống LAN / RFC 1918 SSRF**:
  - Viết validator kiểm tra URL trước khi gửi Webhook, ngăn chặn triệt để trường hợp URL đối tác trỏ về dải IP nội bộ: `127.0.0.1`, `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `169.254.0.0/16`.
- [ ] **Chống DNS Rebinding (IP Pinning)**:
  - Tự phân giải DNS trước và ghim địa chỉ IP (IP Pinning) khi thực hiện HTTP Client request, tránh việc tên miền thay đổi IP giữa thời điểm validate và thời điểm kết nối thực tế.
- [ ] **Chống Tấn Công Tràn Bộ Nhớ (Response Bomb Mitigation)**:
  - Giới hạn kích thước nhận về (`MaxResponseBytes = 1MB`) khi nhận dữ liệu từ các server Webhook đối tác để chống tấn công cạn kiệt RAM (OOM Crash).

### C. Hàng Đợi & Phục Hồi Dữ Liệu (Resilience & DLQ)
- [ ] **Kafka Dead Letter Queue (DLQ)**:
  - Thiết lập Topic DLQ (ví dụ: `*-progress-dlq`) tự động hứng các tin nhắn Consumer xử lý thất bại sau số lần Retry tối đa kèm Exponential Backoff.
- [ ] **Bổ Sung Whitelist Port Nội Bộ Cho DNS & NTP**:
  - Mở cổng UDP `53` (DNS) và UDP `123` (NTP) tới Google Internal Resolver / Time Server để đảm bảo đồng bộ thời gian UTC tuyệt đối giữa các node.

### D. Giám Sát Chủ Động & Cảnh Báo (Monitoring & Alerting)
- [ ] **Cụm Monitoring Nội Bộ (cAdvisor + Prometheus + Grafana)**:
  - Dựng container `cAdvisor` và `Prometheus` thu thập metrics tài nguyên, `Grafana` hiển thị Dashboard và chỉ truy cập qua Google IAP (`localhost:3000`).
- [ ] **Cảnh Báo Chủ Động (Alertmanager)**:
  - Tích hợp gửi thông báo khẩn cấp (Telegram / Webhook) khi máy chủ chạm ngưỡng: RAM > 85%, CPU > 90%, hoặc container bị crash bất thường.
