# Kế Hoạch Kiểm Thử Tự Động Phối Hợp Frontend (Browser) & Backend (Audit Log)

Tài liệu này xác định kế hoạch phối hợp tự động giữa **Frontend** (sử dụng Browser Subagent thao tác trực tiếp trên giao diện web thật) và **Backend** (hệ thống Audit Logger toàn diện tự động kích hoạt khi có cờ `ENABLE_DEBUG_QUERY_LOG=true`).

---

## 1. Cơ Chế Bắt Vết Tự Động Phía Backend (`ENABLE_DEBUG_QUERY_LOG=true`)

Hệ thống Backend đã được tích hợp cơ chế ghi vết tập trung:
1. **`🌐 [HTTP_IN]`**: Ghi nhận Method, URL Path và Decrypted JSON Payload gửi từ Frontend.
2. **`📥 [BE AUDIT]`**: Ghi nhận DTO sau validation, Actor ID, Tenant ID, cờ Dirty Check.
3. **`🔍 [MONGO_QUERY]`**: Ghi nhận chính xác câu query MongoDB BSON, map `Projection`, `Sort`, và phân trang `Page/Size`.
4. **`📡 [MQ / WEBSOCKET]`**: Ghi nhận sự kiện Change Stream, lệnh xóa cache Redis `role:{id}` và phát tin nhắn WebSocket `ENTITY_CHANGED` xuống Client.

---

## 2. Kịch Bản Kiểm Thử Trình Duyệt Tự Động (Web Browser Subagent)

Browser Subagent sẽ truy cập `http://localhost:3000/settings` và thực thi tuần tự các bước:

### Bước 1: Test Giao Diện & Tải Danh Sách Ban Đầu
* Mở tab "Vai trò & Phân quyền".
* Xác nhận Bảng `DataTable` render đúng các cột và có nút `<AddButton />`.
* **Kỳ vọng BE Log**: `[HTTP_IN] POST /api/v1/role/list` $\rightarrow$ `[MONGO_QUERY] [roles.List]` chỉ project các cột visible.

### Bước 2: Test Thêm Mới & Validate Tham Số Rỗng/Sai
* Bấm "Thêm mới" $\rightarrow$ Thử bấm lưu khi tên rỗng $\rightarrow$ Kiểm tra validation error đỏ trên form.
* Nhập:
  * Tên: `Trưởng Phòng Kinh Doanh Auto Test`
  * Mô tả: `Kịch bản kiểm thử tự động UI & BE Sync`
  * Bật quyền `CONFIG_MANAGE` và `USER_VIEW` với scope `ALL`.
* Bấm "Tạo mới".
* **Kỳ vọng FE**: Modal đóng ngay, Toast thông báo xanh xuất hiện, role mới hiện lên đầu bảng tức thì.
* **Kỳ vọng BE Log**: `[ROLE ADD IN]` nhận đầy đủ DTO $\rightarrow$ DB insert thành công $\rightarrow$ Kafka dispatch event $\rightarrow$ WebSocket broadcast.

### Bước 3: Test Chỉnh Sửa & Dirty Check (Rule 9)
* Click vào dòng role vừa tạo $\rightarrow$ Đổi scope `USER_VIEW` sang `SAME_DEPT`.
* Bấm "Lưu thay đổi" $\rightarrow$ Xác nhận trên Mini Dialog.
* **Kỳ vọng FE**: Dữ liệu cập nhật tại chỗ (Zero-Lag).
* **Kỳ vọng BE Log**: `[ROLE UPDATE IN]` chỉ nhận payload dirty $\rightarrow$ Xóa cache Redis `role:{id}` và hierarchy cache.

### Bước 4: Test Xóa Mềm & Local State Filter
* Click vào dòng role $\rightarrow$ Bấm nút "Xóa" góc trái $\rightarrow$ Xác nhận trên Mini Dialog.
* **Kỳ vọng FE**: Dòng biến mất ngay khỏi bảng, `total` giảm 1, không phát sinh `fetchList` thừa.
* **Kỳ vọng BE Log**: `[ROLE DELETE IN]` nhận `include_ids` $\rightarrow$ `$match` stage xóa mềm `is_del: true`.

---

## 3. Kỹ Năng Đã Khởi Tạo: `E2E Tester Agent`
Đã tạo mới Skill **[E2E Tester Agent](file:///f:/Coding/Project/sowfkun.verse.v2/.agents/skills/e2e_tester/SKILL.md)** phục vụ toàn bộ quy trình kiểm thử tự động hai chiều FE-BE.
