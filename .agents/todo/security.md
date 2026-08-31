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
| **DNS & NTP UTC Time Sync Whitelist** | ✅ **DONE** | Mở cổng UDP 53/123 tới Google Internal Resolver (`169.254.169.254`) & NTP Time Server (`216.239.35.0/24`) đảm bảo đồng bộ giờ UTC tuyệt đối |
| **Egress Webhook Gateway & Dispatcher** | ✅ **DONE** | Đã triển khai Gateway Service (`cmd/gateway`) và Client SDK (`pkg/egress`) theo mô hình Monorepo đa binary trên Server 3 |
| **Cloud Metadata Protection (SSRF)** | ✅ **DONE** | Chặn phân giải và kết nối tới IP Link-Local `169.254.169.254` trên Egress Engine |
| **LAN / RFC 1918 SSRF Validator** | ✅ **DONE** | Chặn toàn bộ dải IP Private (`10.0.0.0/8`, `127.0.0.1`, `172.16.0.0/12`, `192.168.0.0/16`, `100.64.0.0/10`, IPv6 ULA) |
| **DNS Rebinding & Response Bomb Guard** | ✅ **DONE** | Ghim IP trực tiếp qua `net.Dialer.Control` và giới hạn dung lượng đọc qua `io.LimitReader` (mặc định 2MB) |
| **Kafka Dead Letter Queue (DLQ) & Retry** | ⏳ **TODO** | Cơ chế Exponential Backoff & Topic DLQ lưu vết khi Consumer retry thất bại quá số lần quy định |

---

## 1. Chi Tiết Các Hạng Mục ĐÃ TRIỂN KHAI THỰC TẾ (DONE)

### A. Hạ Tầng Mạng & Tường Lửa Đối Xứng (Network & VPC Peering)
- [x] **Tách Biệt Môi Trường Độc Lập**: Server 1 (Data Server: MongoDB, Redis) và Server 2 (App Server: Go API, Redpanda Kafka) nằm trên 2 Project GCP và 2 VPC riêng biệt (`data-server-vpc` và `app-server-vpc`).
- [x] **2-Way VPC Peering Đối Xứng**: Thiết lập peering 2 chiều trạng thái `ACTIVE` giữa `project-cfc4d426-e0f0-47cf-866` và `sowfkun-verse`.
- [x] **Khóa Chặt Egress Internet (Data Server)**: Luật `data-vpc-deny-egress-internet` (Priority 1000, `0.0.0.0/0`) ngăn chặn tuyệt đối Data Server bị khai thác Reverse Shell hoặc thất thoát dữ liệu ra ngoài.
- [x] **Khóa Chặt Egress Internet (App Server)**: Luật `app-vpc-deny-egress-internet` (Priority 1000, `0.0.0.0/0`) cô lập App Server khỏi kết nối Internet tự do.
- [x] **Whitelist Egress Cho DNS & NTP (Đồng Bộ Thời Gian UTC)**:
  - Luật `data-vpc-allow-egress-ntp-dns` và `app-vpc-allow-egress-ntp-dns` (Priority 900) mở UDP `53` (DNS) và UDP `123` (NTP) đến Google Internal Resolver (`169.254.169.254/32`) và Google Time Servers (`216.239.35.0/24`) đảm bảo đồng hồ giữa 2 node luôn chuẩn xác 100% theo UTC.
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

### C. Hạ Tầng Giao Tiếp An Toàn Ra Ngoài Internet (Egress Gateway & SSRF Protection)
- [x] **Monorepo Multi-Binary Egress Gateway (`cmd/gateway`)**:
  - Triển khai Egress Gateway Service độc lập chạy trên Server 3 (`10.30.0.0/24`), nhận HTTP request từ Core API qua cổng nội bộ `:8090` và chuyển tiếp an toàn ra Internet.
- [x] **Chống Tấn Công SSRF & Cloud Metadata**:
  - Tự động chặn các URL phân giải về dải IP Link-Local `169.254.0.0/16` (Cloud Metadata của GCP/AWS `169.254.169.254`), Loopback (`127.0.0.0/8`, `::1`), RFC 1918 Private (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`), Carrier-grade NAT (`100.64.0.0/10`) và IPv6 ULA/Link-local.
- [x] **Chống DNS Rebinding (DNS Pinning & Control Hook)**:
  - Phân giải DNS trước và ép buộc kết nối trực tiếp đến IP đã được kiểm chứng an toàn qua `net.Dialer.Control`, ngăn chặn hacker đổi DNS giữa thời điểm kiểm tra và lúc bắt tay TCP.
- [x] **Chống Tấn Công Tràn Bộ Nhớ (Response Bomb Mitigation)**:
  - Giới hạn dung lượng nhận phản hồi tối đa bằng `io.LimitReader` (mặc định 2MB) chống OOM Crash.
- [x] **Cơ Chế Retry & Timeout Tuỳ Chỉnh**:
  - Hỗ trợ cấu hình `TimeoutMs` riêng cho từng request, tùy chọn `MaxRetries`, `RetryIntervalMs`, `RetryOnTimeout` và `RetryStatusCodes` (429, 502, 503, 504).
- [x] **Core Client SDK Tích Hợp (`pkg/egress.Client`)**:
  - Tự động chuyển tiếp request qua Gateway Server trên Production và Fallback thực thi an toàn cục bộ khi chạy Local Dev.

---

## 2. Chi Tiết Các Hạng Mục CẦN TRIỂN KHAI TIẾP THEO (TODO)

### A. Hàng Đợi & Phục Hồi Dữ Liệu (Resilience & DLQ)
- [ ] **Kafka Dead Letter Queue (DLQ)**:
  - Thiết lập Topic DLQ (ví dụ: `*-progress-dlq`) tự động hứng các tin nhắn Consumer xử lý thất bại sau số lần Retry tối đa kèm Exponential Backoff.

