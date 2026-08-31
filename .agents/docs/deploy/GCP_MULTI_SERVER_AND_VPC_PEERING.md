# GCP Multi-Server Deployment, VPC Peering & Zero-Trust Topology

Tài liệu đặc tả toàn diện kiến trúc kết nối mạng, luồng dữ liệu và chính sách bảo mật Zero-Trust giữa các máy chủ trên nền tảng **Google Cloud Platform (GCP)** với mô hình **3-Server Multi-Account / Multi-VPC Peering**.

---

## 1. Sơ Đồ Tổng Thể Kết Nối Giữa Các Server (Network Topology)

```mermaid
graph TB
    subgraph DevMachine["💻 DEV / ADMIN MACHINE (Localhost)"]
        IAP_TUNNEL["🔒 Google IAP Tunnel (35.235.240.0/20)<br/>• :27017 (Mongo) • :6379 (Redis)<br/>• :3000 (Grafana) • :8080 (API)<br/>• :8085 (Console) • :8090 (Gateway)<br/>• :2222,:2223,:2224 (SSH)"]
    end

    subgraph InternetZone["🌐 PUBLIC INTERNET"]
        PUBLIC_USER["👥 Public Users / Frontend Web"]
        EXT_SERVICES["🏢 External APIs<br/>• Resend Email (api.resend.com)<br/>• Telegram Bot (api.telegram.org)<br/>• Webhooks / SMS / Third-party"]
    end

    subgraph VPC1["🏢 GCP ACCOUNT 1 — Data Node (10.10.0.0/24)"]
        S1["💾 SERVER 1 (Data Server)<br/>Internal IP: 10.10.0.2<br/>VPC: data-server-vpc<br/>🛡️ Firewall: DENY Egress 0.0.0.0/0"]
        subgraph S1_Containers["Docker Network: app_net"]
            MONGO["🍃 db_mongo<br/>Port: 27017"]
            REDIS["⚡ app_redis<br/>Port: 6379"]
            NODE_EXP_1["📊 agent_node_exporter<br/>Port: 9100"]
            PROMTAIL_1["📦 agent_promtail<br/>Log Shipper"]
        end
    end

    subgraph VPC2["🏢 GCP ACCOUNT 2 — Core App & Hub (10.20.0.0/24)"]
        S2["🚀 SERVER 2 (Core App & Monitoring Hub)<br/>Internal IP: 10.20.0.2<br/>VPC: app-server-vpc<br/>🛡️ Firewall: DENY Egress 0.0.0.0/0"]
        subgraph S2_Containers["Docker Network: app_net"]
            API["⚙️ app_api (Go Backend)<br/>Port: 8080"]
            KAFKA["📨 app_kafka (Redpanda)<br/>Port: 9092"]
            CONSOLE["📊 app_console<br/>Port: 8085"]
            GRAFANA["🖥️ mon_grafana<br/>Port: 3000"]
            LOKI["📋 mon_loki<br/>Port: 3100"]
            PROMETHEUS["📈 mon_prometheus<br/>Port: 9090"]
            NODE_EXP_2["📊 agent_node_exporter<br/>Port: 9100"]
            PROMTAIL_2["📦 agent_promtail"]
        end
    end

    subgraph VPC3["🏢 GCP ACCOUNT 3 — Egress Gateway (10.30.0.0/24)"]
        S3["🛡️ SERVER 3 (Egress Gateway Server)<br/>Internal IP: 10.30.0.2<br/>VPC: egress-gateway-vpc<br/>🛡️ Firewall: ALLOW Outbound Web"]
        subgraph S3_Containers["Docker Network: app_net"]
            GATEWAY["🚪 app_gateway (Go Egress Engine)<br/>Port: 8090 (SSRF Protection)"]
            NODE_EXP_3["📊 agent_node_exporter<br/>Port: 9100"]
            PROMTAIL_3["📦 agent_promtail"]
        end
    end

    %% Ingress từ Internet
    PUBLIC_USER -->|HTTP 80/443/8080| API

    %% Dev IAP Access
    IAP_TUNNEL -.->|IAP Ingress| S1
    IAP_TUNNEL -.->|IAP Ingress| S2
    IAP_TUNNEL -.->|IAP Ingress| S3

    %% VPC Peering: Server 2 <-> Server 1 (Database)
    API -->|Query MongoDB :27017| MONGO
    API -->|Read/Write Cache :6379| REDIS

    %% VPC Peering: Server 2 <-> Server 3 (Egress Outbound)
    API -->|Dispatch Outbound HTTP :8090| GATEWAY
    GATEWAY -->|HTTPS :443 Outbound| EXT_SERVICES

    %% Observability: Prometheus Scrape (Server 2 -> 1, 2, 3)
    PROMETHEUS -->|Scrape Metrics :9100| NODE_EXP_1
    PROMETHEUS -->|Scrape Metrics :9100| NODE_EXP_2
    PROMETHEUS -->|Scrape Metrics :9100| NODE_EXP_3

    %% Observability: Promtail Push Logs (Server 1, 3 -> Server 2 Loki)
    PROMTAIL_1 -->|Push Logs :3100| LOKI
    PROMTAIL_2 -->|Push Logs :3100| LOKI
    PROMTAIL_3 -->|Push Logs :3100| LOKI

    %% Alert Forwarding (Server 1 -> Server 2 API)
    S1 -.->|Forward Telegram Alert :8080| API
```

---

## 2. Ma Trận Quyền Kết Nối Giữa Các Node (Connectivity Matrix)

Bảng dưới đây quy định chi tiết **Node nào được phép gọi sang Node nào**, qua Cổng (Port), Giao thức và Mục đích nghiệp vụ:

| Từ Node (Source) | Tới Node (Destination) | Cổng (Port) | Giao Thức | Chiều (Flow) | Mục Đích Nghiệp Vụ |
|---|---|---|---|---|---|
| **Server 2 (`10.20.0.2`)** | **Server 1 (`10.10.0.2`)** | `27017` | TCP | Peering Ingress/Egress | Backend API truy vấn MongoDB (Primary Cluster) |
| **Server 2 (`10.20.0.2`)** | **Server 1 (`10.10.0.2`)** | `6379` | TCP | Peering Ingress/Egress | Backend API đọc/ghi Redis Cache (`general1`) |
| **Server 2 (`10.20.0.2`)** | **Server 1 (`10.10.0.2`)** | `9100` | TCP | Peering Ingress/Egress | Prometheus thu thập chỉ số CPU/RAM Node Exporter |
| **Server 2 (`10.20.0.2`)** | **Server 3 (`10.30.0.2`)** | `8090` | TCP | Peering Ingress/Egress | Backend API gửi request qua Egress Gateway (Email, Webhook, SMS, Telegram) |
| **Server 2 (`10.20.0.2`)** | **Server 3 (`10.30.0.2`)** | `9100` | TCP | Peering Ingress/Egress | Prometheus thu thập chỉ số CPU/RAM Node Exporter |
| **Server 1 (`10.10.0.2`)** | **Server 2 (`10.20.0.2`)** | `3100` | TCP | Peering Ingress/Egress | Promtail đẩy toàn bộ Container Logs MongoDB/Redis về Loki Hub |
| **Server 1 (`10.10.0.2`)** | **Server 2 (`10.20.0.2`)** | `8080` | TCP | Peering Ingress/Egress | Script cảnh báo `monitor.sh` chuyển tiếp alert Telegram qua API Gateway |
| **Server 3 (`10.30.0.2`)** | **Server 2 (`10.20.0.2`)** | `3100` | TCP | Peering Ingress/Egress | Promtail đẩy Container Logs Egress Gateway về Loki Hub |
| **Server 3 (`10.30.0.2`)** | **Internet (`0.0.0.0/0`)** | `80, 443` | TCP | Outbound Egress | Gateway thực thi gửi request ra Internet (Resend API, Telegram API, Webhooks) |
| **Google IAP (`35.235.240.0/20`)** | **Server 1 (`10.10.0.2`)** | `22, 27017, 6379, 9100` | TCP | Secure Tunnel | Dev/Admin kết nối SSH, MongoDB Compass, RedisInsight, Metrics |
| **Google IAP (`35.235.240.0/20`)** | **Server 2 (`10.20.0.2`)** | `22, 3000, 3100, 8080, 8085, 9090, 9092, 9100` | TCP | Secure Tunnel | Dev/Admin kết nối SSH, Grafana (:3000), Kafka Console (:8085), API (:8080) |
| **Google IAP (`35.235.240.0/20`)** | **Server 3 (`10.30.0.2`)** | `22, 8090, 9100` | TCP | Secure Tunnel | Dev/Admin kết nối SSH, Egress Gateway (:8090), Metrics (:9100) |
| **Tất cả Servers** | **Google Internal DNS / NTP** | `53, 123` | UDP | Egress System | Đồng bộ giờ UTC qua `time.google.com` (`216.239.35.0/24`) & phân giải tên miền (`169.254.169.254/32`) |

---

## 3. Các Luồng Dữ Liệu Trọng Yếu (Critical Data Flows)

### 3.1. Luồng Gửi Email & Webhook Ra Internet (Zero-Trust Egress Flow)

```mermaid
sequenceDiagram
    autonumber
    participant App as 🚀 Server 2 (App Server)
    participant GW as 🛡️ Server 3 (Egress Gateway :8090)
    participant Ext as 🌐 Internet (Resend / Telegram / Webhook)

    App->>GW: POST /api/v1/egress/http (Gửi kèm URL đích, Headers, Payload)
    Note over GW: 1. Kiểm tra SSRF (Chặn gọi ngược IP nội bộ, AWS/GCP Metadata 169.254.x)<br/>2. Kiểm soát Rate Limit & Hạn mức
    GW->>Ext: HTTPS POST ra ngoài Internet (api.resend.com / api.telegram.org)
    Ext-->>GW: Trả về kết quả (HTTP 200 OK / Response JSON)
    GW-->>App: Trả về HTTPResponse cho Backend API
```

### 3.2. Luồng Thu Thập Log & Metrics Tập Trung (Central Observability Flow)

```mermaid
sequenceDiagram
    autonumber
    participant S1 as 💾 Server 1 (Data)
    participant S3 as 🛡️ Server 3 (Gateway)
    participant Hub as 🖥️ Server 2 (Monitoring Hub)
    participant Admin as 💻 Admin (Localhost :3000)

    par Scrape Metrics định kỳ 15s
        Hub->>S1: GET 10.10.0.2:9100/metrics (Prometheus scrape Node 1)
        Hub->>S3: GET 10.30.0.2:9100/metrics (Prometheus scrape Node 3)
    and Push Realtime Logs
        S1->>Hub: POST 10.20.0.2:3100/loki/api/v1/push (Promtail Node 1)
        S3->>Hub: POST 10.20.0.2:3100/loki/api/v1/push (Promtail Node 3)
    end

    Admin->>Hub: Mở Grafana qua IAP Tunnel (http://localhost:3000)
    Hub-->>Admin: Hiển thị Dashboard Realtime (Slow Query, Error Feed, CPU/RAM)
```

---

## 4. Tường Lửa & Chính Sách Cách Ly (Zero-Trust Firewall Policy)

### 🚫 Quy Tắc Chặn Toàn Bộ Kết Nối Trực Tiếp Ra Internet:
- **Server 1 (Data Server)**: Khóa cứng `DENY Egress 0.0.0.0/0` (`Priority 1000`). Bất kỳ mã độc nào xâm nhập cũng **không thể** gửi dữ liệu ra ngoài Internet (chống Reverse Shell và Data Exfiltration 100%).
- **Server 2 (App Server)**: Khóa cứng `DENY Egress 0.0.0.0/0` (`Priority 1000`). Toàn bộ kết nối ra bên ngoài bắt buộc phải đi qua **Server 3 (Egress Gateway)**.
- **Server 3 (Egress Gateway)**: Máy chủ duy nhất được phép mở Egress HTTP/HTTPS ra ngoài Internet, được bảo vệ nghiêm ngặt bằng bộ lọc SSRF Engine (`pkg/egress/ssrf.go`).

### 🔑 Quản Lý Truy Cập Bảo Mật Không Cần Mở Port Public (Google IAP):
- Tất cả các cổng quản trị (`22`, `3000`, `8085`, `9090`, `27017`, `6379`) đều được đóng kín đối với toàn thế giới (`0.0.0.0/0`).
- Chỉ lập trình viên/quản trị viên sở hữu tài khoản Google được cấp quyền IAM mới có thể mở Tunnel kết nối trực tiếp qua lệnh:
  ```powershell
  .\tools\sowfkun.ps1 verse-tunnel
  ```
