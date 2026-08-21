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
