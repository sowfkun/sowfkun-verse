# 09. Testing, Verification & Logging Standards (Quy Chuẩn Kiểm Thử & Ghi Vết)

Tài liệu này định nghĩa toàn bộ "Luật Thép" về quy trình kiểm thử tự động, thẩm định luồng Cache, và tiêu chuẩn quản lý Log trong hệ thống Backend Sowfkun-Verse.

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
- **Quy tắc**: Trong quá trình phát triển tính năng hoặc kiểm thử một kịch bản phức tạp, nếu Agent/Lập trình viên đặt các lệnh `log.Printf` thăm dò trong các UseCase, Handler, hay Repository:
  - **BẮT BUỘC PHẢI DỌN DẸP XÓA SẠCH** sau khi hoàn thành phiên kiểm thử.
  - Tuyệt đối **NGHIÊM CẤM** để lại các dòng log rác trong mã nguồn Production.

---

## 2. Quy Chuẩn Kiểm Thử Luồng Cache & Invalidation (Cache Verification Probe)

Khi thực hiện kiểm thử tự động một luồng Cập nhật / Xóa dữ liệu (Update / Delete):
1. **Ghi DB**: Thực hiện request cập nhật dữ liệu xuống MongoDB WiredTiger.
2. **Kích hoạt Change Stream**: MongoDB Change Stream phát hiện thay đổi $\rightarrow$ Kafka dispatch sự kiện sang MQ Handler $\rightarrow$ Xóa key Cache trên Redis (`[domain]Cache.BuildKey`).
3. **Thăm dò kiểm chứng (Freshness Verification Probe)**:
   - Ngay sau khi xóa cache, thực hiện gọi lại hàm `GetCachedByID(id)`.
   - **Xác nhận tính toàn vẹn**:
     - Lần đọc đầu tiên: Bắt buộc rơi vào **Cache Miss** $\rightarrow$ Hệ thống tự động fallback xuống MongoDB đọc bản ghi mới nhất $\rightarrow$ Nạp lại vào Redis (Cache Set).
     - Lần đọc thứ hai: Bắt buộc rơi vào **Cache Hit** với dữ liệu mới cập nhật 100%.

---

## 3. Quy Chuẩn Bắt Lỗi & Validate Đầu Vào (Input Validation Verification)

- Khi kiểm thử một API Endpoint mới:
  - Phải kiểm tra ít nhất 4 trường hợp dữ liệu sai:
    1. **Payload rỗng / thiếu trường bắt buộc**: Trả về `400 ERR_VALIDATION_FAILED` kèm struct chi tiết lỗi.
    2. **Độ dài vượt quá giới hạn** (vd: Tên > 50 ký tự): Trả về `400 ERR_VALIDATION_FAILED`.
    3. **Enum / Scope không hợp lệ**: Trả về `400 ERR_VALIDATION_FAILED`.
    4. **Xung đột tham số xóa** (`is_sel_all = true` kèm `include_ids`): Trả về `400 ERR_BAD_REQUEST`.
