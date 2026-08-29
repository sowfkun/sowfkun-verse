# 05. Message Queue & Kafka Architecture

## 1. Kiểm soát Topic Nghiêm ngặt (Strict Topic Control)
- Hệ thống kiểm soát và quản lý cực kỳ chặt chẽ danh sách các Kafka Topics. Nhà phát triển và Agent **TUYỆT ĐỐI KHÔNG** được tự ý tạo thêm topic mới khi chưa có sự chỉ định hoặc phê duyệt từ người quản trị / Platform Architect.
- Các topic được phân hoạch theo **Chiến lược xử lý (Processing Strategy)** dùng chung trên toàn hệ thống để tối ưu hóa hiệu năng và quản lý kết nối.

## 2. Hệ Sinh Thái Topic Toàn Cục
Hệ thống duy trì các Topic chính (được khai báo tại `pkg/mq/kafka/topics.go`):
1. `low-traffics-order-progress`: Dành cho các event cần chạy tuần tự, bảo đảm đúng thứ tự xử lý (FIFO) cho cùng một đối tượng (Dựa vào Routing Key).
2. `single-parallel-progress`: Dành cho các event độc lập, xử lý song song với hiệu năng cao bằng Worker Pool.
3. `batch-progress`: Dành cho các event gom lô (batching) để ghi hàng loạt (Bulk Write) xuống Database.
4. `send-socket-progress`: Dành cho việc phân phối tin nhắn socket gửi đi từ hệ thống xuống Client qua Hub.
5. `receive-socket-progress`: Dành cho việc nhận tin nhắn socket gửi lên từ Client để xử lý bất đồng bộ.
6. `low-entity-sync-order-progress`: Dành cho việc đồng bộ thực thể dựa trên MongoDB Change Stream.

## 3. Kiến Trúc Global Event Dispatcher
Để tiết kiệm tối đa số lượng Connection Consumer Group tới Kafka:
- **KHÔNG**: Không được phép cho các Domain tự mở Consumer hay tự khai báo Group ID riêng lẻ (Sẽ gây Duplicate Connection hoặc Load-Balancing sai lệch).
- **CÓ**: Hệ thống sử dụng mô hình **Global Event Dispatcher** (Centralized In-memory Pub/Sub).
  - Các Domain (VD: Tenant) chỉ việc viết hàm Handler và đăng ký với Dispatcher thông qua: `dispatcher.Register(coreDomain.EventX, handlerFunc)`.
  - Dispatcher sẽ tự động bóc vỏ JSON, đọc trường `Type` và định tuyến (Route) Message xuống đúng cho Domain cần xử lý.

## 4. Quy tắc Publish Message (Producer)
Mọi Message được đẩy lên Kafka bắt buộc phải tuân thủ chặt chẽ định dạng của `Event` (định nghĩa tại `pkg/core/domain/event.go`):
```go
type Event struct {
	Key         string    `json:"-"`               // Dùng để định tuyến Partition (VD: TenantID), không lưu vào JSON
	Topic       string    `json:"topic,omitempty"` // Đích đến trên Kafka (Topic name), chỉ dùng cho job
	Source      string    `json:"source"`          // Nguồn phát sinh sự kiện (ví dụ: "auth", "user")
	Type        string    `json:"type"`            // Loại sự kiện (ví dụ: EventEmailSendRequested)
	MessageTime time.Time `json:"message_time"`    // Thời điểm publish (UTC)
	Data        any       `json:"data"`            // Payload dữ liệu (Struct/Map tự do)
}
```
- Nếu dùng `low-traffics-order-progress`: **Bắt buộc** truyền `Key` để đảm bảo 2 event của cùng 1 đối tượng rớt vào chung 1 Partition.
- Nếu không cần Order, có thể bỏ trống `Key`, Kafka sẽ tự rải (Round-Robin).

## 5. Các Loại Consumer & Batching Pattern
- **Ordered Consumer**: Chạy tuần tự từng dòng (1 vòng lặp for duy nhất).
- **Parallel Consumer**: Chạy qua Worker Pool. `ReadMessage` liên tục và quăng vào `Channel` cho các Worker tranh nhau cày.
- **Batch Consumer**: Sử dụng thuật toán Application-Level Batching (Time & Count Window). Chỉ xả mẻ dữ liệu xuống Handler khi gom đủ số lượng (VD: 50 tin) HOẶC quá thời gian chờ (VD: 2 giây) để tránh giam dữ liệu khi hệ thống ít request.

## 6. Quy trình từng bước tích hợp Kafka (Kafka Flow Initialization)
Để đảm bảo tính nhất quán (Consistency) trong việc đặt tên và khởi tạo luồng Kafka mới cho bất kỳ Domain nào, Agent BẮT BUỘC phải tuân theo các bước sau:

**Bước 1: Khai báo Event Type Constant**
- Mọi tên Event (Ví dụ: `EventEmailSendRequested`, `EventSocketProgressSend`) **BẮT BUỘC** phải được định nghĩa tập trung thành biến hằng số trong file `pkg/core/domain/event.go`.
- Cú pháp tên biến (Golang Variable): Bắt đầu bằng chữ `Event`, tiếp theo là Tên Domain, rồi đến hành động (Ví dụ: `EventEmailSendRequested`).
- Cú pháp giá trị String (Kafka Event Type): Bắt buộc dùng `UPPER_SNAKE_CASE` (Toàn bộ viết hoa, cách nhau bởi dấu gạch dưới).

**Bước 2: Tạo MQ Handler cho Domain**
- Tại thư mục `internal/[domain_name]/presentation/mq/`, tạo file `handler.go`.
- Struct xử lý Event bắt buộc phải được đặt tên theo cú pháp `[DomainName]MQHandler` (Ví dụ: `TenantMQHandler`, `EmailMQHandler`). Tuyệt đối không dùng tên tuỳ tiện như `EmailKafkaHandler`.
- Hàm Constructor phải là `New[DomainName]MQHandler()`.

**Bước 3: Đăng ký Handler với Global Dispatcher**
- Mở file `cmd/api/setup_kafka.go`.
- Trong hàm `startGlobalConsumers`, tiến hành khởi tạo UseCase (nếu cần) và gọi Constructor của MQ Handler.
- Đăng ký hàm xử lý bằng Dispatcher sử dụng hằng số đã tạo ở Bước 1 (Ví dụ: `dispatcher.Register(domain.EventEmailSendRequested, emailHandler.HandleEmailRequested)`).
- Tuyệt đối không hardcode chuỗi string trực tiếp vào hàm `Register()`.

## 7. Socket & Realtime Message Queue Rules
- **Model dùng chung**: Mọi tin nhắn truyền qua Socket cho Client bắt buộc phải được đóng gói qua struct `socket.SocketMessagePayload` và được publish qua hàm `socket.PublishSocketMessage` (với tham số `isSend bool`). Nghiêm cấm việc gửi trực tiếp JSON thủ công không qua schema định sẵn.

## 8. Đồng bộ Tag Entity với Change Stream & MQ Handler Filter
- Khi xử lý sự kiện Entity Change từ Change Stream (`Handle[Domain]Changed`), Handler sử dụng `reflection.GetStructTags` trên Cache Model và Response DTO để trích xuất danh sách key cần theo dõi (`cacheFields`, `socketFields`).
- **Yêu cầu bắt buộc**: Tên tag BSON trong Entity và JSON tag trong Response DTO / Cache Model phải đồng nhất 100% (ví dụ: cùng là `tz`, `phone`, `status`, `tier`, `meta`). Nếu đặt lệch tên, hàm `HasFieldIntersection` sẽ không phát hiện được sự thay đổi dẫn tới việc bỏ sót xoá cache hoặc không bắn WebSocket cập nhật realtime.

## 9. Đọc Lại Dữ Liệu Sau Tác Động DB Trong MQ / Async Handlers (Read-After-Write Consistency & Delay Awareness)
Khi một MQ Handler, Consumer hoặc Job thực hiện tác động lên DB (Insert/Update/Soft-Delete) hoặc nhận event DB vừa thay đổi và cần query/get lại dữ liệu để xử lý tiếp:
- **Phân biệt rạch ròi 2 cơ chế Đọc (Read Consistency)**:
  1. **Strong Consistency (Realtime 100% / Zero-Lag)**:
     - Các hàm `GetByID`, `GetOne` truy vấn trực tiếp vào MongoDB Primary (WiredTiger Storage Engine qua B-Tree Index).
     - **Tính chất**: Dữ liệu vừa ghi/xóa xong 1ms sau đọc lại là có kết quả chuẩn xác tuyệt đối tức thì.
  2. **Eventual Consistency (Độ trễ Re-indexing / Index Lag)**:
     - Các truy vấn tìm kiếm/danh sách đi qua **Atlas Search (`$search`)**, **OpenSearch**, **Elasticsearch**, hoặc **Read Replicas**.
     - **Tính chất**: Engine tìm kiếm bất đồng bộ cần thời gian (thường từ 500ms đến 2-3 giây) để ingest Change Stream và re-index tài liệu.
- **Luật Thép Khi Viết MQ Handler / Async Service**:
  - Khi cần đọc lại entity ngay sau khi vừa tác động DB (Read-after-write): **BẮT BUỘC** dùng `GetByID` hoặc `Find()` trực tiếp từ DB chính để đảm bảo Realtime, **TUYỆT ĐỐI KHÔNG** dùng các hàm List/Query đi qua Atlas Search / OpenSearch vì dữ liệu sẽ bị "bóng ma" (stale data hoặc miss).
  - Nếu nghiệp vụ bắt buộc phải dùng Search Engine (ví dụ: cần aggregate, search phân cấp, re-ranking toàn cục sau khi entity thay đổi): **BẮT BUỘC** phải có cơ chế **Delay / Retry** (ví dụ: dispatch qua Asynq Delayed Task sau 2-3 giây, hoặc retry exponential backoff) để đảm bảo engine tìm kiếm đã hoàn tất re-indexing trước khi đọc.

## 10. Kiến Trúc Change Stream Zero-Waste (Không Dùng UpdateLookup) & Consumer-side Projection
- **Cấm dùng UpdateLookup tại Watcher**: `ChangeStreamWatcher` TUYỆT ĐỐI KHÔNG cấu hình `SetFullDocument(options.UpdateLookup)` khi khởi tạo Change Stream cursor. Điều này loại bỏ hoàn toàn việc MongoDB Server phải chạy truy vấn lookup ngầm cho mỗi sự kiện update, giảm tải tối đa CPU/Disk I/O và tối ưu tốc độ Change Stream lên mức tối đa.
- **Payload Tối Giản (Zero-Waste)**: Payload của sự kiện phát sinh từ Change Stream chỉ chứa các trường metadata gọn nhẹ: `id`, `op`, `collection`, và `updateDescription` (chứa `updatedFields`, `removedFields`).
- **Chủ Động Projection Tại Consumer**: Khi MQ Consumer (`RoleMQHandler`, `UserMQHandler`, `TenantMQHandler`, `TagMQHandler`, `AttributeMQHandler`, v.v.) nhận event thay đổi và cần dữ liệu để đóng gói payload Socket hoặc xóa Cache theo trường phụ thuộc:
  - BẮT BUỘC phải gọi `repo.GetByID(ctx, id, projection)` với `projection` chỉ định đích danh các trường cần thiết.
  - TUYỆT ĐỐI KHÔNG dựa dẫm vào `fullDocument` trong event payload và KHÔNG truyền projection `nil` (SELECT *) khi không thực sự cần thiết.

## 11. Cấu Hình Kafka Producer (Non-blocking Asynchronous & Fast Batch Timeout)
- **Cơ chế**: Kafka Producer (`NewProducer`) được cấu hình `Async: true` và nạp động các tham số gom batch từ biến môi trường:
  - `KAFKA_PRODUCER_BATCH_BYTES`: Giới hạn dung lượng byte của mỗi batch (mini: 64KB, standard: 512KB, huge: 1MB).
  - `KAFKA_PRODUCER_BATCH_SIZE`: Số lượng message tối đa trong 1 batch (mini: 200, standard: 500, huge: 1000).
  - `KAFKA_PRODUCER_BATCH_TIMEOUT_MS`: Thời gian chờ gom batch tối đa trước khi xả đi (mini: 20ms, standard: 10ms, huge: 5ms).
- **Mục đích**: `Async: true` đảm bảo hàm `Publish()` ghi message vào memory buffer và trả về ngay tức thì (< 0.1ms), không bị block chờ round-trip mạng.

## 12. Cụm Kafka Chuẩn Hóa (Kafka 2-Clusters Standard)
Hệ thống chuẩn hóa thành **2 Cụm Kafka vật lý/logic độc lập**:
1. **Cụm `general1` (`KAFKA_GENERAL1_BROKERS`)**: Tiếp nhận toàn bộ sự kiện nghiệp vụ liên Domain (`low-traffics-order-progress`, `single-parallel-progress`, `batch-progress`), sự kiện WebSocket (`send-socket-progress`, `receive-socket-progress`), và logging events.
2. **Cụm `entity_sync1` (`KAFKA_ENTITY_SYNC1_BROKERS`)**: Kênh chuyên biệt vận chuyển sự kiện CDC từ MongoDB Change Stream (`low-entity-sync-order-progress`) để cập nhật `SyncMeta` và xóa Cache thực thể.

## 13. Kết Nối Redpanda / Kafka Self-Hosted (Plaintext TCP) & Port Mapping
- **Giao thức**: Gỡ bỏ hoàn toàn lớp bảo mật rườm rà (SASL / SCRAM / TLS) trong `pkg/mq/kafka/manager.go`, sử dụng kết nối Plaintext TCP gọn nhẹ, tối ưu hóa tốc độ I/O.
- **Cổng kết nối**:
  - **Cổng nội bộ `9092` (`PLAINTEXT`)**: Dành cho các container chạy cùng mạng Docker `app_net` (vd: `app_api`).
  - **Cổng ngoài `9094` (`OUTSIDE`)**: Dành cho môi trường Local Dev kết nối từ xa hoặc ngoài Host. Bắt buộc mở firewall trên Cloud/GCP (`tcp:9094`) và khai báo `REDPANDA_ADVERTISED_HOST` là IP Public của Server.

## 14. Dynamic Consumer Worker Scaling theo Partition
- Số lượng Goroutine Workers của Consumer (`StartConsumerGroup`) được tự động đồng bộ theo số lượng partition: `numWorkers := config.DefaultPartitions` (nạp từ `KAFKA_DEFAULT_PARTITIONS`, mặc định `4`).
- Đảm bảo tỷ lệ tối ưu **1 Consumer Worker : 1 Partition**, ngăn ngừa lãng phí tài nguyên CPU và tránh hiện tượng Consumer Goroutine dư thừa bị nhàn rỗi (idle).

