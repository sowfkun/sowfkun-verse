# 05. Message Queue & Kafka Architecture

## 1. Giới hạn Hạ Tầng (Cloud Free Tier constraints)
- **Aiven Kafka Free Tier**: Hệ thống bị giới hạn tối đa **5 Topics** và mỗi Topic chỉ có tối đa **2 Partitions**.
- Vì giới hạn này, tuyệt đối KHÔNG quy hoạch Topic theo từng Domain (VD: `tenant-topic`, `noti-topic`) vì sẽ cạn kiệt tài nguyên ngay lập tức.
- Thay vào đó, Topic phải được quy hoạch theo **Chiến lược xử lý (Processing Strategy)** dùng chung cho toàn hệ thống.

## 2. Hệ Sinh Thái Topic Toàn Cục
Hệ thống duy trì 3 Topic chính (khai báo tại `pkg/mq/kafka/topics.go`):
1. `low-traffics-order-progress`: Dành cho các event cần chạy tuần tự, đảm bảo đúng thứ tự xử lý (FIFO) cho một đối tượng (Dựa vào Routing Key).
2. `single-parallel-progress`: Dành cho các event độc lập, cường độ cao. Hệ thống sẽ cày cuốc bằng Worker Pool đa luồng (Multi-threading).
3. `batch-progress`: Dành cho các event gom lô. Phù hợp để xả Bulk Write (InsertMany, UpdateMany) xuống MongoDB để giảm số lượng Query.

## 3. Kiến Trúc Global Event Dispatcher
Để tiết kiệm tối đa số lượng Connection Consumer Group tới Kafka:
- **KHÔNG**: Không được phép cho các Domain tự mở Consumer hay tự khai báo Group ID riêng lẻ (Sẽ gây Duplicate Connection hoặc Load-Balancing sai lệch).
- **CÓ**: Hệ thống sử dụng mô hình **Global Event Dispatcher** (Centralized In-memory Pub/Sub).
  - Có đúng 3 Consumer chạy ngầm ở `main.go` (Ordered, Parallel, Batch) với 3 Group ID toàn cục (`global-ordered-group`, v.v.).
  - Các Domain (VD: Tenant) chỉ việc viết hàm Handler và đăng ký với Dispatcher thông qua: `dispatcher.Register("EVENT_TYPE", handlerFunc)`.
  - Dispatcher sẽ tự động bóc vỏ JSON, đọc trường `Type` và định tuyến (Route) Message xuống đúng cho Domain cần thiết.

## 4. Quy tắc Publish Message (Producer)
Mọi Message được đẩy lên Kafka bắt buộc phải tuân thủ chặt chẽ định dạng của `CommonEvent`:
```go
type CommonEvent struct {
	Key    string `json:"-"` // Dùng để định tuyến Partition. BẮT BUỘC có nếu đẩy lên Ordered Topic (VD: ID của User/Tenant).
	Source string `json:"source"`
	Type   string `json:"type"` // Dùng để Dispatcher phân loại (VD: "TENANT_CREATED")
	Data   any    `json:"data"` // Truyền Struct/Map thoải mái, hệ thống tự động Serialize thành JSON
}
```
- Nếu dùng `low-traffics-order-progress`: **Bắt buộc** truyền `Key` để đảm bảo 2 event của cùng 1 đối tượng rớt vào chung 1 Partition.
- Nếu không cần Order, có thể bỏ trống `Key`, Kafka sẽ tự rải (Round-Robin).

## 5. Các Loại Consumer & Batching Pattern
- **Ordered Consumer**: Chạy tuần tự từng dòng (1 vòng lặp for duy nhất).
- **Parallel Consumer**: Chạy qua Worker Pool. `ReadMessage` liên tục và quăng vào `Channel` cho các Worker tranh nhau cày.
- **Batch Consumer**: Sử dụng thuật toán Application-Level Batching (Time & Count Window). Chỉ xả mẻ dữ liệu xuống Handler khi gom đủ số lượng (VD: 50 tin) HOẶC quá thời gian chờ (VD: 2 giây) để tránh giam dữ liệu khi hệ thống ít request.
