# 09. Testing, Verification & Logging Standards (Quy Chuẩn Kiểm Thử & Ghi Vết Toàn Diện)

Tài liệu này định nghĩa "Luật Thép" về quy trình kiểm thử tự động, thẩm định toàn diện các phân hệ (Request, Validation, DB, Projection, Index, Cache, Quota, WebSocket, UI State), và tiêu chuẩn quản lý Log trong hệ thống Sowfkun-Verse.

---

## 1. Phân Định 2 Tầng Log Hệ Thống (Two-Tier Logging Separation)

> **Luật Thép**: Tuyệt đối không được lẫn lộn giữa Log hạ tầng hệ thống và Log thăm dò kiểm thử tạm thời.

### 1.1 Tầng 1: Log Hạ Tầng Hệ Thống (System Infrastructure Logging)
- **Cơ chế**: Được kiểm soát hoàn toàn bằng biến môi trường `ENABLE_DEBUG_QUERY_LOG=true` trong `.env`.
- **Phạm vi áp dụng**:
  - **Tầng Middleware**: Tự động log HTTP Method, URL Path, Decrypted DTO Payload tại `pkg/middleware/payload_crypto.go`.
  - **Tầng Database Hạ Tầng**: Tự động log Collection Name, Filter BSON, Projection Map, Sort Order, Page/Size tại `pkg/database/mongodb/abstract_repository.go`.
- **Mục đích**: Phục vụ việc soi toàn diện mọi request/query khi debug và test mà không cần thêm code riêng lẻ ở từng Domain.

### 1.2 Tầng 2: Log Thăm Dò Kiểm Thử Tạm Thời (Temporary Test Probe Logs)
- **Quy tắc**: Trong quá trình phát triển tính năng hoặc kiểm thử một kịch bản phức tạp, nếu Agent/Lập trình viên đặt các lệnh log thăm dò trong các UseCase, Handler, Repository, MQ, hoặc Frontend:
  - **BẮT BUỘC PHẢI DỌN DẸP XÓA SẠCH 100%** sau khi hoàn thành phiên kiểm thử.
  - Tuyệt đối **NGHIÊM CẤM** để lại các dòng log rác, cờ debug tạm thời trong mã nguồn Production.

---

## 2. Tiêu Chuẩn Thẩm Định 6 Phân Hệ Khi Kiểm Thử (The 6 Verification Pillars)

Mọi kịch bản kiểm thử tính năng (CRUD, Danh mục, Cấu hình) bắt buộc phải đối soát qua **6 phân hệ cốt lõi**:

### 2.1 Thẩm Định Request & Input Validation (Input Verification)
- Kiểm tra tính đúng đắn của DTO giải mã.
- Thẩm định bắt lỗi chuẩn xác các trường hợp: Rỗng, vượt ký tự tối đa, sai kiểu Enum/Scope, xung đột cờ xóa (`is_sel_all` + `include_ids`).
- Thẩm định cơ chế **Dirty Check (Rule 9)**: Chỉ gửi và nhận các trường có thay đổi thực sự.

### 2.2 Thẩm Định Truy Vấn MongoDB, Index & Projection (DB & Index Verification)
- **Projection Strictness**: Xác nhận câu query MongoDB chỉ project đúng các trường cần hiển thị trên UI. Cấm `SELECT *` / Full Document không lý do.
- **Index Optimization**: Xác nhận query lọc đúng các trường đã đánh chỉ mục (`tid`, `is_del`, `kws`, ranges).
- **Audit Logging**: Xác nhận `c_at`, `c_by`, `u_at`, `u_by` được cập nhật chính xác.

### 2.3 Thẩm Định Luồng Cache Invalidation & Freshness (Cache Verification Probe)
- Khi Update / Delete $\rightarrow$ MongoDB Change Stream kích hoạt $\rightarrow$ Kafka Handler xóa cache cũ trên Redis.
- **Thăm dò kiểm chứng (Probe Verification)**:
  - Gọi lại hàm Get Cached ngay sau khi xóa cache: Lần 1 phải **Cache Miss** $\rightarrow$ Tự động fallback xuống MongoDB đọc bản ghi mới $\rightarrow$ Nạp lại Redis. Lần 2 phải **Cache Hit** với dữ liệu mới 100%.

### 2.4 Thẩm Định Giới Hạn Quota (Quota & Max Limit Verification)
- Thao tác thêm bản ghi liên tục tới khi chạm ngưỡng giới hạn của Tenant Tier.
- Xác nhận Backend chặn đứng và trả về đúng mã lỗi `ERR_QUOTA_EXCEEDED` (hoặc `ERR_ROLE_QUOTA_EXCEEDED`).
- Xác nhận Frontend bắt lỗi hiển thị Dialog/Toast cảnh báo rõ ràng.

### 2.5 Thẩm Định Realtime WebSocket Dispatch (WebSocket Verification)
- Xác nhận sau khi ghi DB thành công: Kafka Producer bắn sự kiện $\rightarrow$ WebSocket Hub gửi payload `ENTITY_CHANGED` (`entity_type`, `op_type`, `data`) xuống Client.

### 2.6 Thẩm Định Giao Diện & Local State (Frontend Zero-Lag Verification)
- **Zero-Lag State Handling**:
  - Thêm mới $\rightarrow$ Chèn ngay lên đầu danh sách (`items = [newItem, ...items]`, `total + 1`).
  - Chỉnh sửa $\rightarrow$ Cập nhật tại chỗ trong state (Zero network re-fetch).
  - Xóa $\rightarrow$ Lọc bỏ trực tiếp khỏi state (`items = items.filter(...)`, `total - 1`) mà không gọi lại `fetchList()` khi danh sách chưa đầy trang.
- **Form & UX**: Nút Lưu/Submit bị disabled nếu không có thay đổi hiệu dụng (Dirty Check).

