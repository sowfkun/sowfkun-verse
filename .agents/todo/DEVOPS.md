# DevOps & Infrastructure TODO List

## 🚀 Hạ Tầng & Bảo Mật Mạng (Security & Infrastructure)

- [x] **1. Dời Endpoint Nhận Alert Sang App Egress Gateway (Server 3 `:8090`):**
  - Chuyển route `POST /api/v1/system/alert/telegram` từ Core App (Server 2) sang Egress Gateway (Server 3).
  - Tách biệt hoàn toàn hệ thống cảnh báo khỏi vòng đời của Core App (Core App có chết thì Egress vẫn gửi được alert báo sự cố về Telegram).
  - Giảm latency 1 chặng hop mạng và loại bỏ bypass E2EE trên Core API Server 2.

- [x] **2. Cách Ly Một Chiều Tuyệt Đối (True One-Way Air-Gapped Matrix):**
  - **Khóa Egress ⛔ App/Data:** Chặn 100% kết nối chủ động từ Server 3 (Egress Gateway) ngược vào Server 2 (App), Server 1 (Cache/MQ), và Node Netcup (Mongo).
  - **Khóa Data & MQ ⛔ App (Mongo, Redis, Kafka):** Cả Node Netcup (Mongo) và Server 1 (Redis Cache + Kafka Broker) đều là các dịch vụ hạ tầng thụ động (Passive Services). Chúng chỉ tiếp nhận kết nối đọc/ghi từ App và gửi alert 1 chiều tới Egress Server 3 (`:8090`), tuyệt đối không được phép chủ động kết nối vào Server 2 (Core App).
  - Đảm bảo Zero Blast Radius: Từng node độc lập được đóng khung trong hộp cát 1 chiều, triệt tiêu hoàn toàn nguy cơ quét mạng hoặc nhảy cóc (Lateral Movement) giữa các máy chủ.
