# Table & List Standards (Quy chuẩn Bảng & Danh sách Dữ liệu)

Tài liệu này quy định toàn bộ tiêu chuẩn về việc xây dựng, cấu hình hiển thị, bộ lọc thông minh và tương tác cho các thành phần Bảng dữ liệu (`DataTable`) và Danh sách trên toàn bộ hệ thống Frontend.

---

## 1. Schema-Driven Column Definition & Table Cells
- **Schema-Driven Metadata**: Mọi cấu hình cột cho `<DataTable>` bắt buộc phải được khai báo dưới dạng cấu hình schema metadata thông qua các thuộc tính của `Column<T>` (`type`, `getSubtitle`, `getIndex`, `getLine2`, `getBadgeVariant`, `render`).
- **Nghiêm cấm viết logic JSX thủ công hoặc switch-case màu sắc trực tiếp trong `render` của cột** ở các file Page (trừ trường hợp tuỳ biến giao diện đặc biệt).
- **Đóng gói Table Cells**: Các kiểu hiển thị cell chuẩn (`title-subtitle`, `double-text`, `badge`) bắt buộc phải được gom chung và đóng gói xử lý tự động trong lõi Table để tái sử dụng ở mọi module, đảm bảo tính đóng gói và tối ưu hiệu năng.

---

## 2. Universal Base Audit Columns (`getBaseAuditColumns`)
- **4 Cột Audit hệ thống**: Các thuộc tính Audit hệ thống (`c_at` - Ngày tạo, `u_at` - Lần update cuối, `c_by` - Người tạo, `u_by` - Người update cuối) phản chiếu trực tiếp từ `BaseEntity` của Backend Go và xuất hiện ở mọi collection dữ liệu.
- **BẮT BUỘC** sử dụng helper dùng chung `...getBaseAuditColumns<T>(t)` từ `@/components` khi khai báo cột cho bảng dữ liệu. TUYỆT ĐỐI KHÔNG tự khai báo lặp lại 4 cột này thủ công ở từng page riêng lẻ.
- Helper này đã được đóng gói toàn bộ logic i18n (`t`), định dạng thời gian 24h UTC, Typography chuẩn `<Typo variant="body">` và font Monospace thống nhất toàn hệ thống.

---

## 3. Universal Common Column Builders (`commonColumns.tsx`)
- Đối với các cột dữ liệu thông dụng lặp lại giữa các module (như Tên chính `getNameColumn`, Email `getEmailColumn`, Số điện thoại `getPhoneColumn`, Trạng thái `getStatusColumn`, Người phụ trách `getOwnerColumn`):
- **BẮT BUỘC** sử dụng các hàm builder chuẩn từ `@/components` để khởi tạo cột thay vì viết lại schema thủ công.
- Các builder này đã thiết lập sẵn độ rộng chuẩn (`initialWidth`), kiểu hiển thị (`type`), typography chuẩn (`<Typo variant="body">`), Font Monospace cho số/mã định danh, màu sắc Badge tự động theo trạng thái, và liên kết từ điển đa ngôn ngữ (`t`).
- **Cơ chế Alias Resolution tự động (Zero-Allocation)**: Các builder đã tích hợp cơ chế phân giải tên trường linh hoạt bằng mảng hằng số tĩnh module-level (VD: Email tự nhận `email`, `mail`, `email_address`; Phone tự nhận `phone`, `phone_number`, `mobile`, `tel` và hỗ trợ cả phone object lẫn phone string; Name tự nhận `name`, `full_name`, `display_name`; Owner tự nhận `owner_id`, `owner`, `assignee` và hỗ trợ cả Actor object).

---

## 4. Hệ Thống Bộ Lọc Thông Minh (Smart Filter Rules)
- **Thứ tự Ưu tiên của Bộ lọc (Filter Priority Order)**:
  - Bộ lọc khoảng thời gian (`DateRangePicker` - Ngày tạo / `c_at` / `joined_at`) **BẮT BUỘC LUÔN ĐƯỢC ĐẶT Ở VỊ TRÍ ĐẦU TIÊN (INDEX 0)** trong mảng `availableFilters` để tạo điểm neo tìm kiếm mốc thời gian rõ ràng nhất cho người dùng.
  - Theo sau lần lượt là các bộ lọc phân loại chính: Trạng thái (`status`), Người phụ trách (`owner_id`), và các bộ lọc nghiệp vụ riêng.
- **Đồng bộ hóa Nhãn Bộ lọc & Tiêu đề Cột (Filter-Column Label Synchronization)**:
  - Tên nhãn của các bộ lọc (`availableFilters`) bản chất chính là tiêu đề của các cột thuộc tính tương ứng trên bảng.
  - **BẮT BUỘC** sử dụng chung các khóa dịch `col_*` (VD: `col_status`, `col_owner`, `col_created_at`) cho cả cột và bộ lọc. TUYỆT ĐỐI KHÔNG tạo các khóa `filter_*` trùng lặp nghĩa.
  - `<DataTable />` tự động kế thừa chính xác `column.header` sang nhãn bộ lọc nếu `AvailableFilterItem.label` được để trống.
- **Quy tắc Bộ lọc "Chọn tất cả" (Select All Filter & Zero API Payload Rule)**:
  - Tất cả các bộ lọc dạng chọn nhiều (`<MultiSelect />`) mặc định hỗ trợ tùy chọn `"Tất cả"` (`select_all`) ở đầu danh sách popover.
  - Khi người dùng chọn `"Tất cả"` (toàn bộ options được chọn) hoặc để trống (`[]`):
    - **Phía UI**: Badge hiển thị nhãn `: Tất cả` trực quan.
    - **Phía Network / API**: **TUYỆT ĐỐI KHÔNG TRUYỀN** tham số filter đó lên API (bỏ qua / omit khỏi query parameters) để tiết kiệm băng thông và tối ưu câu lệnh query DB. Chỉ gửi query parameter lên API khi người dùng lọc một tập con cụ thể (`0 < value.length < options.length`).

---

## 5. Quy Tắc Tìm Kiếm Bảng (Table Search Rules)
- **Tối thiểu 3 ký tự & Nhấn Enter (Min 3 Chars & Enter-to-Search Rule)**:
  - Thanh tìm kiếm (`<SearchBar />` trong `<DataTable />`) **BẮT BUỘC CHỈ KÍCH HOẠT TÌM KIẾM KHI NGƯỜI DÙNG NHẬP TỪ 3 KÝ TỰ TRỞ LÊN VÀ NHẤN PHÍM ENTER** (`trimmed.length >= 3` on `Enter`).
  - Tuyệt đối **KHÔNG** gọi API liên tục theo từng phím gõ (realtime per-keystroke is disallowed) nhằm chống spam request và tối ưu tải server.
  - Khi người dùng xóa trắng ô tìm kiếm (`val === ''` hoặc `trimmed.length === 0` on `Enter`), hệ thống tự động kích hoạt tìm kiếm rỗng để reset lại toàn bộ danh sách ban đầu.

---

## 6. Cấu Hình Hiển Thị & Phân Trang (Settings & Pagination)
- **Cấu hình Bảng Tích hợp (`TableSettingsModal`)**: `<DataTable />` tích hợp sẵn nút bấm cấu hình (Sliders Icon) mở modal 2 Tab:
  * Tab 1: Ẩn/Hiện bộ lọc (`availableFilters`).
  * Tab 2: Sắp xếp thứ tự cột (Drag & Drop) và ẩn/hiện cột thuộc tính (`columns`).
- **Nút Hành Động Chuẩn**: Nút thêm mới đi kèm danh sách bắt buộc sử dụng component `<AddButton />` (thuần chữ, có cơ chế chống double-click 400ms và async promise lock).
