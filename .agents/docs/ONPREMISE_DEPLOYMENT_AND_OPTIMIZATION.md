# ON-PREMISE DEPLOYMENT & INFRASTRUCTURE OPTIMIZATION

Tài liệu này tổng hợp toàn diện các cấu hình tối ưu hóa khi triển khai hệ thống **Sowfkun-Verse** trên môi trường **On-Premise** (Private Cloud / Bare-Metal Server của Doanh nghiệp) so với môi trường **Cloud / SaaS (Free/Shared Tier)**.

---

## 1. Triết lý Thiết kế On-Premise First

Toàn bộ kiến trúc Backend và Frontend của Sowfkun-Verse được thiết kế theo nguyên tắc **On-Premise First**:
- **Không Hardcode:** Toàn bộ thông số hạ tầng (Cluster URLs, Credentials, Retention, Sharding, Concurrency, Rate Limit) được cấu hình 100% qua Biến môi trường (`.env`) và Dynamic Registry.
- **Tùy biến Quy mô linh hoạt (Scalability by Configuration):** Cùng một source code, hệ thống có thể chạy siêu tiết kiệm trên các cụm Cloud Free Tier (giới hạn dung lượng/shard), đồng thời có thể bung toàn bộ sức mạnh phần cứng (RAM, CPU, NVMe SSD) khi đưa vào Server On-Premise doanh nghiệp.

---

## 2. Bảng Ma Trận So Sánh (Cloud/SaaS vs On-Premise)

| Phân hệ Hạ tầng | Môi trường Cloud / SaaS Free | Cấu hình On-Premise Khuyến nghị | Lợi ích Đạt được trên On-Premise |
|---|---|---|---|
| **OpenSearch Time-Series** | `PartitionMonth` / `PartitionDay`, Retention: 6 - 12 tháng | `PartitionQuarter` / `PartitionYear`, Retention: 3 - 5 năm | Giảm 70-90% số lượng Shard, tránh tràn RAM JVM Heap, lưu trữ lịch sử dài hạn. |
| **OpenSearch Replication** | `replicas: 0`, `shards: 1` | `replicas: 1`, `shards: 2 - 4` | Tăng tính sẵn sàng (High Availability), tìm kiếm song song đa luồng. |
| **Kafka / Redpanda** | Batch: 50 msgs / 2s, Concurrency: 2 | Batch: 200 - 500 msgs / 500ms, Concurrency: 8 - 16 | Tăng Throughput xử lý lên 10,000+ msg/s, độ trễ ingestion thời gian thực (<0.5s). |
| **Redis In-Memory** | Cache DTO tối giản, TTL ngắn (1 - 24h), LRU eviction gắt gao | Cache DTO chuẩn hóa, TTL dài (7 - 30 ngày), Tăng Rate Limit (500-1000 req/s) | Tăng Cache Hit Ratio > 95%, giảm tải 80% truy vấn xuống MongoDB chính. |
| **MongoDB Database** | Shared ReplicaSet, Connection Pool: 20 - 50 | Dedicated ReplicaSet, Connection Pool: 100 - 300, WiredTiger 50% RAM | Giảm độ trễ I/O xuống <1ms (Local LAN), tối ưu hóa ghi đồng thời. |

---

## 3. Chi tiết Tối ưu Từng Loại Hạ Tầng

### 3.1. OpenSearch & Time-Series Engine

#### Hiện trạng Cloud / SaaS:
* Phân vùng theo Tháng (`PartitionMonth`) hoặc Ngày (`PartitionDay`).
* Nguyên nhân: Do dùng các gói Cloud Free/Tier nhỏ (Aiven, AWS OpenSearch t3.small), RAM Heap chỉ 1-2GB, nếu giữ index quá lâu sẽ bị lỗi **Over-sharding** làm sập Cluster.

#### Cấu hình On-Premise tối ưu:
1. **Chuyển Phân vùng sang Quý (`QUARTER`) hoặc Năm (`YEAR`):**
   * *Vị trí cấu hình:* Tại `cmd/api/main.go` và `cmd/indexer/opensearch.go`.
   ```go
   // Triển khai On-Premise lưu 3 năm theo Quý:
   customerActivityRepo = activityInfra.NewActivityRepository(
       customerActivitiesClient,
       "customer_activities",
       osPkg.PartitionQuarter, // Sinh: customer_activities-2026.q1
   )
   ```
   * *Retention Rule:*
   ```go
   RetentionRule: osPkg.IndexRetentionRule{
       Name:            "Customer Activities",
       Prefix:          "customer_activities",
       Partition:       osPkg.PartitionQuarter,
       RetentionAmount: 12, // 12 quý = 3 năm
   }
   ```
2. **Tăng Shards & Replicas trong Index Template (`cmd/indexer/opensearch.go`):**
   ```json
   "settings": {
       "number_of_shards": 2,
       "number_of_replicas": 1,
       "refresh_interval": "1s"
   }
   ```
3. **Lợi ích:**
   * Tiết kiệm số lượng Shards từ **36 shards** (theo tháng) xuống còn **12 shards** (theo quý) hoặc **3 shards** (theo năm).
   * Tận dụng tốc độ đọc ghi vượt trội của ổ cứng Enterprise NVMe SSD On-Premise.

---

### 3.2. Message Queue (Kafka / Redpanda)

#### Hiện trạng Cloud / SaaS:
* Sử dụng Kafka Serverless hoặc cụm nhỏ, cấu hình batch 50 messages / 2 giây, Concurrency = 2.

#### Cấu hình On-Premise tối ưu:
1. **Tăng Kích thước Mẻ Gom (Batch Size) & Giảm Độ Trễ (Latency Window):**
   * *Vị trí cấu hình:* `cmd/api/setup_kafka.go`.
   ```go
   // Cụm general2 - Logging & Activity Batch Ingestion
   kafkaManager.StartBatchConsumer(
       ctx,
       "general2",
       kafkaPkg.TopicEntityActivitiesProgress,
       "entity-activities-batch-group",
       200,                // Tăng lên 200 items mỗi mẻ
       500*time.Millisecond, // Gom nhanh trong 500ms
       dispatcher.HandleBatchMessage,
   )
   ```
2. **Tăng Số lượng Worker Xử lý Song song (Concurrency):**
   ```go
   concurrency := 8 // Tăng từ 2 lên 8 hoặc 16 tùy số nhân CPU server
   ```
3. **Lợi ích:**
   * Tăng Throughput ghi dữ liệu Activity/Audit Logs lên gấp 4-8 lần.
   * Người dùng thao tác trên Web/App thấy lịch sử tương tác cập nhật gần như tức thì.

---

### 3.3. Redis Caching & In-Memory Storage

#### Hiện trạng Cloud / SaaS:
* RAM Redis bị giới hạn (25MB - 256MB), phải dùng Cache DTO lược bỏ trường, TTL ngắn 1 - 24h để tránh OOM.
* `RATE_LIMIT_MAX_REQUESTS=100`.

#### Cấu hình On-Premise tối ưu:
1. **Luôn Tuân Thủ Golden Standard Cache DTO:**
   * Dù triển khai trên On-Premise có RAM dồi dào, hệ thống **bắt buộc vẫn sử dụng Cache DTO** (như `TenantCacheModel`, `RoleCacheModel`, `UserCacheModel`) thay vì lưu thẳng raw Entity xuống Redis.
   * *Mục đích:* Chỉ cache các trường thực sự cần thiết cho nghiệp vụ đọc nhanh, loại bỏ các trường nặng (desc, raw metadata, hash không dùng) để giữ Redis luôn gọn nhẹ, serialization nhanh và tránh rò rỉ dữ liệu.
2. **Mở rộng Dung lượng RAM & Nâng Rate Limit (`.env`):**
   ```env
   # Nâng ngưỡng giới hạn request cho mạng nội bộ/doanh nghiệp
   RATE_LIMIT_MAX_REQUESTS=1000
   RATE_LIMIT_WINDOW_SECONDS=60
   ```
3. **Mở rộng TTL Cache Domain (`pkg/cache/redis/`):**
   * Session Token TTL: Tăng từ 1 ngày lên 7 - 30 ngày.
   * Metadata/Role/Permission Cache TTL: Tăng lên 7 ngày.
4. **Lợi ích:**
   * Giảm thiểu 90% truy vấn xác thực quyền và thông tin người dùng xuống MongoDB.
   * Trải nghiệm ứng dụng mượt mà, phản hồi API trung bình dưới 5ms.

---

### 3.4. Cơ sở Dữ liệu MongoDB

#### Hiện trạng Cloud / SaaS:
* Kết nối qua Internet tới MongoDB Atlas, Connection Pool mặc định 20-50 kết nối.

#### Cấu hình On-Premise tối ưu:
1. **Cấu hình Connection Pool & Socket Timeout (`.env`):**
   ```env
   MONGO_TENANT1_MAX_POOL_SIZE=200
   MONGO_TENANT1_MIN_POOL_SIZE=50
   MONGO_TENANT1_MAX_IDLE_TIME_MS=30000
   ```
2. **Cấu hình WiredTiger Cache Size (Tại file cấu hình `mongod.conf` trên Server):**
   ```yaml
   storage:
     wiredTiger:
       engineConfig:
         cacheSizeGB: 16 # Dành 50% RAM máy chủ cho MongoDB cache
   ```
3. **Lợi ích:**
   * Không còn độ trễ kết nối mạng công cộng (Network latency LAN < 1ms).
   * Phục vụ hàng nghìn kết nối đồng thời từ các chi nhánh/phòng ban mà không bị nghẽn Pool.

---

## 4. Hướng dẫn Chuyển Đổi Nhanh Sang On-Premise (Checklist)

Khi bàn giao và triển khai cho khách hàng On-Premise:

1. [ ] **Thiết lập File `.env` On-Premise:**
   * Cập nhật các URL nội bộ: `MONGO_*_URI`, `REDIS_*_URL`, `KAFKA_*_BROKERS`, `OPENSEARCH_*_URL`.
   * Tăng `RATE_LIMIT_MAX_REQUESTS=1000`.
2. [ ] **Cập nhật Phân vùng OpenSearch:**
   * Đổi Partition sang `osPkg.PartitionQuarter` hoặc `osPkg.PartitionYear` tại `cmd/api/main.go`.
   * Cập nhật `RetentionAmount` tương ứng (VD: 12 quý = 3 năm) tại `cmd/indexer/opensearch.go`.
3. [ ] **Chạy Indexer khởi tạo:**
   * Khởi động server để tự động nạp Template và Retention Registry: `go run cmd/api/*.go`.
4. [ ] **Kiểm tra Logs Khởi động:**
   * Xác nhận toàn bộ kết nối các cụm DB, Redis, Kafka, OpenSearch đều hiển thị `[OK]`.
