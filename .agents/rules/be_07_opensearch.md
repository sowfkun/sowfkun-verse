# Hướng dẫn quy chuẩn OpenSearch / ElasticSearch

Khi thiết kế và triển khai các tính năng tương tác với OpenSearch (hoặc ElasticSearch), bạn BẮT BUỘC phải tuân thủ nghiêm ngặt các quy tắc sau để đảm bảo cụm server luôn ổn định, hiệu năng cao và dễ mở rộng.

## 1. Phân loại Dữ liệu & Quản lý Vòng đời (Index Lifecycle)
- **Đối với Dữ liệu Thời gian/Log (Time-Series):**
  - **Không xoá thủ công từng Document:** Việc xoá từng dòng dữ liệu log là vô nghĩa, tốn tài nguyên và gây phân mảnh index.
  - **Dùng Composable Templates + Phân vùng Thời gian (UTC):** Ghi dữ liệu vào index theo phân vùng thời gian (ví dụ: `general_logs-YYYY.MM.DD` hoặc `danger_logs-YYYY.MM`). Template Composable `_index_template` tự động áp dụng Mapping & Shards tức thì khi OpenSearch tạo index mới.
  - **Quản lý Lưu giữ Tập trung (Centralized Retention Registry & Asynq Cron Job):** Đăng ký chính sách lưu giữ (`IndexRetentionRule`) tại `pkg/database/opensearch/retention_registry.go` thông qua `internal/indexer/opensearch.go`. Asynq Cron Job chạy định kỳ hàng ngày quét qua OpenSearch cluster và tự động xoá triệt để các index quá hạn theo UTC (ví dụ: quá 30 ngày, quá 6 tháng). Tuyệt đối KHÔNG dùng plugin ISM trên các cụm Cloud Managed (như Aiven) để tránh lỗi phân quyền 403 và tràn Shard lịch sử.
- **Đối với Dữ liệu Nghiệp vụ (Business Entities):**
  - **Xoá Document thủ công (Sync Delete):** Các index chứa dữ liệu thực thể (ví dụ: Users, Products, Emails) BẮT BUỘC phải dùng cấu trúc Index tĩnh (hoặc chia shard tuỳ quy mô) và **ĐƯỢC PHÉP** gọi lệnh xoá từng Document để đồng bộ trạng thái khi dữ liệu đó bị xoá ở Database chính (MongoDB).

## 2. Khởi tạo & Template (Init Template)
- **Dùng Composable Templates:** Bạn BẮT BUỘC phải dùng Index Templates (`_index_template`) để định nghĩa sẵn Mapping và Setting cho các mẫu index (ví dụ: `general_logs-*`). Không bao giờ được phép tạo một index mà không có Template định nghĩa sẵn từ trước.
- **Tự động Khởi tạo (Indexer & Startup):** Các Index Template BẮT BUỘC phải được định nghĩa tập trung tại `internal/indexer/opensearch.go` và đồng bộ tự động khi ứng dụng khởi động hoặc chạy qua lệnh `go run cmd/indexer/main.go opensearch`.

## 3. Thiết kế Model & Mapping (Chống Nổ Mapping)
- **Tránh dùng Map Động không xác định:** KHÔNG BAO GIỜ định nghĩa các trường object động như `Payload map[string]any` trong Go Model để chứa các key JSON tuỳ ý. Việc này dẫn tới thảm họa "Mapping Explosion" (Nổ Mapping), khiến OpenSearch sinh ra hàng ngàn field rác và làm sập cụm server.
- **Thiết kế Cấu trúc Phẳng (Generic Flat Schema):** Hãy thiết kế các trường chung, phẳng, có thể tái sử dụng cho nhiều loại log khác nhau. Ví dụ: `Action`, `Target`, `Source`, `Status`, `Duration`, `Message`, `Context`.
- **Giải nghĩa theo Type:** Ý nghĩa của các trường Generic này sẽ được quyết định bởi trường `Type` (ví dụ: Nếu `Type="REQUEST"`, `Source` là IP; Nếu `Type="AUDIT"`, `Source` là UserID).
- **Cảnh báo Đồng bộ (Sync Warning):** Bất kỳ Domain Entity nào (Go struct) được dùng để map trực tiếp xuống OpenSearch thì BẮT BUỘC phải có comment cảnh báo bự chà bá ở trên đầu struct đó (ví dụ: `// ⚠️ WARNING: ENTITY NÀY DÙNG OPENSEARCH. KHI ĐỔI MODEL PHẢI CẬP NHẬT MIGRATION TEMPLATE!`). Tuyệt đối không để xảy ra tình trạng sửa model Go mà quên sửa Template Mapping.

## 4. Phân mảnh Thời gian (UTC & Truncate)
- **Luôn dùng UTC:** Khi sinh tên index theo Ngày/Tháng/Năm hoặc phân tích khoảng thời gian truy vấn, LUÔN LUÔN convert Unix Timestamp về `.UTC()`. Tuyệt đối không dùng `.Local()` vì ứng dụng phải đảm bảo tính nhất quán trên toàn cầu, bất kể Data Center đặt ở múi giờ nào.
- **Gọt thời gian (Truncate):** Khi chạy vòng lặp để sinh tên index từ ngày A đến ngày B, LUÔN LUÔN ép (Truncate) thời gian bắt đầu và kết thúc về đúng mốc `00:00:00` của phân vùng (ví dụ mốc ngày đối với `PartitionDay`) trước khi thực hiện cộng thêm ngày (`AddDate`). Điều này giúp vòng lặp không bị nhảy cóc hoặc bỏ sót ngày do phần giờ phút lẻ gây ra.
