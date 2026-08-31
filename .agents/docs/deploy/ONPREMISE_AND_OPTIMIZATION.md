# ON-PREMISE DEPLOYMENT & INFRASTRUCTURE OPTIMIZATION

Tài liệu này tổng hợp toàn diện các cấu hình tối ưu hóa khi triển khai hệ thống **Sowfkun-Verse** trên môi trường **On-Premise** (Private Cloud / Bare-Metal Server của Doanh nghiệp) so với môi trường **Cloud / SaaS (Free/Shared Tier)**.

---

## 1. Triết lý Thiết kế On-Premise First

Toàn bộ kiến trúc Backend và Frontend của Sowfkun-Verse được thiết kế theo nguyên tắc **On-Premise First**:
- **Không Hardcode:** Toàn bộ thông số hạ tầng (Cluster URLs, Credentials, Retention, Sharding, Concurrency, Rate Limit) được cấu hình 100% qua Biến môi trường (`.env`) và Dynamic Registry.
- **Tùy biến Quy mô linh hoạt (Scalability by Configuration):** Cùng một source code, hệ thống có thể chạy siêu tiết kiệm trên các cụm Cloud Free Tier (giới hạn dung lượng/shard), đồng thời có thể bung toàn bộ sức mạnh phần cứng (RAM, CPU, NVMe SSD) khi đưa vào Server On-Premise doanh nghiệp.

---

## 2. Bảng Ma Trận So Sánh Theo Profile Hạ Tầng (`mini`, `standard`, `huge`)

| Thành phần Hạ tầng | Profile `mini` (VPS 1-2GB RAM) | Profile `standard` (Server 4-8GB RAM) | Profile `huge` (Server 16GB+ RAM) |
|---|---|---|---|
| **API Memory Limit** | `200M` | `400M` | `1024M` (1GB) |
| **Egress Gateway Limit** | `100M` | `200M` | `512M` |
| **MongoDB Pool** | `15 max / 2 min` | `50 max / 5 min` | `150 max / 15 min` |
| **Redis Pool** | `15 max / 2 min` | `50 max / 5 min` | `150 max / 15 min` |
| **OpenSearch Conns** | `20 idle / 5 per_host` | `50 idle / 10 per_host` | `200 idle / 50 per_host` |
| **Asynq Workers** | `3 workers` | `10 workers` | `20 workers` |
| **Kafka Batch Tuning** | `64KB / 200 msgs / 20ms` | `512KB / 500 msgs / 10ms` | `1MB / 1000 msgs / 5ms` |
| **Kafka Retention** | `3 ngày` | `3 ngày` | `7 ngày` |
| **Loki Log Retention** | `7 ngày` | `14 ngày` | `30 ngày` |
| **Monitoring Stack** | `Agent Promtail (:9100)` | `Hub + Promtail` | `Hub High-Availability + Promtail` |

---

## 3. Chi tiết Tối ưu Từng Loại Hạ Tầng

### 3.1. OpenSearch & Time-Series Engine
- **2 Cụm kết nối độc lập**: `logging1` (System & Danger Logs) và `activities1` (Customer & User Activities).
- **Index Retention & Partitioning**:
  - `mini` / Cloud: Phân vùng theo Tháng (`PartitionMonth`), Retention 6-12 tháng.
  - `standard` / `huge`: Phân vùng theo Quý (`PartitionQuarter`) hoặc Năm (`PartitionYear`), Retention 3-5 năm.
- **Connection Pool**: Nạp qua `OPENSEARCH_MAX_IDLE_CONNS`, `OPENSEARCH_MAX_IDLE_CONNS_PER_HOST`, `OPENSEARCH_IDLE_CONN_TIMEOUT_MS`.

---

### 3.2. Message Queue (Kafka / Redpanda Self-Hosted)
- **2 Cụm chuẩn hóa**: `general1` (Sự kiện nghiệp vụ, Socket progress, Logging) và `entity_sync1` (CDC Entity sync).
- **Kết nối Plaintext TCP**: Gỡ bỏ overhead mã hóa/xác thực không cần thiết trong mạng nội bộ.
- **Tự động Scale Consumer Worker**: `StartConsumerGroup` khởi tạo số worker Goroutines bằng đúng số partition (`KAFKA_DEFAULT_PARTITIONS`, mặc định `4`) đảm bảo tỷ lệ 1 Worker : 1 Partition.
- **Cổng kết nối**: Cổng `9092` nội bộ trong Docker network `app_net`, cổng `9094` mở ra ngoài cho máy Dev ở Local.

---

### 3.3. Redis In-Memory Caching & Asynq Queue
- **2 Cụm chuẩn hóa**:
  - `general1` (DB 0): Quản lý Cache, Session Key (E2EE), Rate Limit Token Bucket, User Hierarchy & Online Status Cache, Entity Change Cache.
  - `job1` (DB 2): Quản lý Asynq Background Job Task Queue.
- **Tuân thủ Cache DTO**: Bắt buộc sử dụng Cache DTO tối giản (`TenantCacheModel`, `RoleCacheModel`, `UserCacheModel`) để giảm 80% RAM Redis.
- **Pool Tuning**: Nạp động qua `REDIS_GENERAL_POOL_SIZE`, `REDIS_GENERAL_MIN_IDLE_CONNS`, `REDIS_GENERAL_MAX_CONN_IDLE_TIME_MS`.

---

### 3.4. Cơ sở Dữ liệu MongoDB
- **2 Cụm chuẩn hóa**:
  - `primary1`: Lưu trữ các DB nghiệp vụ cốt lõi (`tenant`, `system`, `config`, `customer`, `ticket`).
  - `secondary1`: Lưu trữ DB phụ trợ (`logging`).
- **Connection Pool**: Nạp động qua `MONGO_MAX_POOL_SIZE`, `MONGO_MIN_POOL_SIZE`, `MONGO_MAX_CONN_IDLE_TIME_MS`.
- **WiredTiger Engine Cache**: Cấu hình 50% RAM máy chủ cho MongoDB cache trên các profile `standard` và `huge`.
- **Replica Set & Change Streams (Advertised Host)**: Cấu hình `MONGO_ADVERTISED_HOST` (IP Public hoặc Private VPC của node) trong `.env`. Script `init_replica.sh` tự động cấu hình node thành viên Replica Set tương ứng để Change Streams (`Watch()`) hoạt động thông suốt.

---

## 4. Hướng dẫn Chuyển Đổi & Checklist Khi Triển Khai On-Premise

Khi chuẩn bị đóng gói và triển khai sản phẩm lên hạ tầng On-Premise của khách hàng (Private DataCenter, Bare-Metal Server, hoặc Private Cloud VM), cần tuân thủ bảng checklist toàn diện sau:

### 4.1. Checklist Cấu hình Môi trường & Kết nối (`.env`)
- [ ] **Khử Naming Đặc trưng (Generic Naming):** Đảm bảo không hardcode tên sản phẩm/thương hiệu trong container name, cluster name và image name. Cấu hình qua các biến:
  - `API_CONTAINER_NAME`, `API_IMAGE`
  - `MONGO_CONTAINER_NAME`, `REDIS_CONTAINER_NAME`, `REDPANDA_CONTAINER_NAME`
  - `OPENSEARCH_CONTAINER_NAME`, `OPENSEARCH_CLUSTER_NAME`
- [ ] **IP & Domain nội bộ doanh nghiệp:**
  - `API_PORT`, `API_HOST`, `CORS_ALLOWED_ORIGINS` (cập nhật dải domain/IP nội bộ khách hàng).
  - `MONGO_ADVERTISED_HOST`: Điền IP mạng LAN / Private VPC của node MongoDB để Replica Set và Change Streams kết nối đúng.
  - `REDPANDA_ADVERTISED_HOST`: Điền IP mạng LAN / Private VPC của node Kafka.
- [ ] **Connection Strings:** Cập nhật trỏ tới các node/cluster nội bộ:
  - `MONGO_*_URI`: Cập nhật user/pass, IP/Host và `authSource=admin` (kèm `?directConnection=true`).
  - `REDIS_*_URL`: Cập nhật mật khẩu và IP node Redis.
  - `KAFKA_*_BROKERS`: Cập nhật dải IP:Port broker.
  - `OPENSEARCH_*_URL`: Cập nhật URL node OpenSearch.

### 4.2. Checklist Bảo mật & Bí mật hệ thống (Secrets Rotation)
- [ ] **Thay đổi Default Credentials:**
  - Đổi mật khẩu Redis (`REDIS_PASSWORD`), MongoDB root password, OpenSearch auth.
- [ ] **Sinh mới Khóa JWT & Khóa E2EE Riêng Biệt:**
  - `JWT_SECRET`: Sinh chuỗi secret ngẫu nhiên bảo mật (ít nhất 32 ký tự).
  - `BLIND_INDEX_PEPPER`: Sinh chuỗi pepper ngẫu nhiên bảo mật cho tìm kiếm mã hóa.
  - `DATABASE_ENCRYPTION_KEY_v1`: Sinh 32-byte hex key độc lập cho mã hóa dữ liệu nhạy cảm (SĐT/Email).
  - `RSA_PRIVATE_KEY_BASE64` / `RSA_PUBLIC_KEY_BASE64`: Gen cặp khóa RSA 2048-bit mới cho từng khách hàng để phục vụ mã hóa payload E2EE giữa Client & Backend.

### 4.3. Checklist Tài nguyên Phần cứng & Hiệu năng (Resource Tuning)
- [ ] **Điều chỉnh RAM Limits theo cấu hình Server:**
  - `API_CONTAINER_MEMORY_LIMIT`: Nâng lên 1G - 2G tùy tải.
  - `MONGO_CONTAINER_MEMORY_LIMIT` & `MONGO_MAX_POOL_SIZE`: Tăng pool kết nối lên 100-300.
  - `REDIS_MAX_MEMORY` & `REDIS_CONTAINER_MEMORY_LIMIT`: Tăng theo dung lượng RAM vật lý.
  - `OPENSEARCH_JVM_HEAP`: Cấu hình 50% RAM máy chủ (ví dụ: `-Xms4g -Xmx4g` cho máy 8GB RAM).
  - `RATE_LIMIT_MAX_REQUESTS`: Nâng từ 100 lên 500 - 1000 requests/phút trong mạng nội bộ.
- [ ] **OpenSearch Time-Series Partitioning:**
  - Đổi Partition sang `osPkg.PartitionQuarter` hoặc `osPkg.PartitionYear` tại `cmd/api/main.go`.
  - Cập nhật `RetentionAmount` tương ứng (VD: 12 quý = 3 năm) tại `cmd/indexer/opensearch.go`.

### 4.4. Checklist Lưu trữ Dữ liệu & Backup (Volumes & Mount Points)
- [ ] **Mount Phân vùng Ổ cứng Chuyên dụng:**
  - Trỏ các volume `./data` (Mongo, Redis, Kafka, OpenSearch) ra các mount point SSD/NVMe chuyên dụng (VD: `/data/db`, `/data/redis`, `/data/opensearch`).
- [ ] **Thiết lập Backup Định kỳ:**
  - Thiết lập crontab tự động `mongodump` và snapshot OpenSearch/Redis hàng ngày đẩy về SAN/NAS nội bộ.

### 4.5. Checklist Hệ thống Mạng, Reverse Proxy & Thời gian
- [ ] **Đồng bộ Thời gian UTC & NTP:**
  - Bắt buộc kiểm tra server OS đã chạy chuẩn UTC: `timedatectl set-timezone UTC && timedatectl set-ntp true`.
- [ ] **Reverse Proxy & SSL/TLS:**
  - Cấu hình Nginx / HAProxy / Traefik làm cổng Gateway tiếp nhận HTTPS với chứng chỉ SSL/TLS nội bộ của doanh nghiệp.
- [ ] **Tường lửa & Phân vùng Mạng (Firewall / UFW):**
  - Đóng toàn bộ các port DB/Queue (`27017`, `6379`, `9092`, `9200`) ra ngoài Internet, chỉ cho phép kết nối trong dải IP mạng LAN / Docker Network nội bộ.

