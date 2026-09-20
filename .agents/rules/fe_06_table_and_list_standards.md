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

---

## 7. Tối Ưu State Sau Khi Xóa / Cập Nhật (Local State vs Refetch)
- **Khi Xóa Thành Công (Delete Success)**:
  - Nếu danh sách hiện tại **chưa đầy trang** (`items.length < size` hoặc `total <= size`):
    - **TUYỆT ĐỐI KHÔNG gọi lại API danh sách (`fetchList()`)** nhằm tiết kiệm tài nguyên mạng và triệt tiêu ảnh hưởng của độ trễ Index Lag từ Search Engine phía Backend.
    - **Chỉ cập nhật Local State**: Lọc bỏ item trực tiếp qua `setItems(prev => prev.filter(item => item.id !== deletedId))` và giảm tổng số bản ghi `setTotal(prev => Math.max(0, prev - 1))`.
  - Chỉ gọi lại API khi danh sách đang ở trang đầy đủ (`items.length === size`) để kéo bản ghi ở trang tiếp theo lên lấp chỗ trống, hoặc khi trang cuối cùng bị xóa hết bản ghi để lùi về trang trước đó.
- **Khi Cập Nhật Thành Công (Update Success)**:
  - Cập nhật trực tiếp bản ghi trong Local State `setItems(prev => prev.map(item => item.id === updated.id ? updated : item))` thay vì reload toàn bộ bảng.
  - Sử dụng `patchEntityCacheItem(ENTITY_TYPE, id, 'UPDATE', data)` để vá trực tiếp bản ghi vào `localStorage` mà không làm mất toàn bộ cache. TUYỆT ĐỐI KHÔNG gọi `invalidateEntityCache`.

---

## 8. Quy Chuẩn Nạp Options Lười & Local Dictionary Cache (Lazy On-Demand Options Loading)
- **Lazy On-Demand Options Loading**:
  - Đối với các cột hiển thị thông tin tra cứu ngoại lai (như `role_ids`, `owner_id`, `tag_ids`, `attribute_ids`):
    - Khi trang vừa load: **Chỉ gọi hàm `get*Map(tenant)` NẾU cột đó đang hiển thị (`visibleColumnKeys.includes(key)`) hoặc bộ lọc tương ứng đang được áp dụng (`selected*.length > 0`)**.
    - Nếu cột đang bị ẩn và bộ lọc chưa mở: **TUYỆT ĐỐI KHÔNG gọi API lấy Options**.
  - **Kích hoạt qua Dropdown Trigger (`onOpen`)**:
    - Truyền callback `onOpen` vào component `<MultiSelect />` để khi người dùng click mở bộ lọc lần đầu tiên mới kích hoạt hàm nạp dữ liệu từ điển.
  - **Cơ chế Cache Hit 0ms**:
    - Hàm `getEntityCacheMap` so khớp version với `tenant.meta[entity_type]`. Nếu trùng version, đọc trực tiếp từ `localStorage` với độ trễ 0ms và 0 request mạng.

---

## 9. Quy Chuẩn Đồng Bộ Realtime Không Refetch (Zero-Refetch WebSocket Integration)
- **Xử lý sự kiện `ENTITY_CHANGED` tại Component View**:
  - Khi nhận sự kiện WebSocket `ENTITY_CHANGED` của thực thể đang xem trên bảng:
    - **`op_type === 'UPDATE'`**: Cập nhật trực tiếp trường dữ liệu (`name`, `email`, v.v.) vào Map từ điển (`set*Map`) và mảng State của bảng (`setItems(prev => prev.map(...))`).
    - **`op_type === 'DELETE'`**: Lọc bỏ trực tiếp khỏi state (`setItems(prev => prev.filter(...))`) và giảm tổng số bản ghi (`setTotal(prev => Math.max(0, prev - 1))`).
  - **LUẬT THÉP BẤT BIẾN**: **TUYỆT ĐỐI CẤM gọi `fetchList()` hoặc `get*Map()` từ sự kiện WebSocket**. Mọi đồng bộ dữ liệu phải diễn ra tại chỗ (In-place Mutation) trên RAM và Local Storage.

---

## 10. Quy Chuẩn Hiển Thị "Tôi" (Me), Sắp Xếp Đầu Danh Sách & Sao Chép Tên Thật (Actor Identity Resolution & "Me" Rules)
- **Thư Viện Dùng Chung Bắt Buộc (`src/lib/userUtils.ts`)**:
  - **Phân giải Danh tính (`resolveActorInfo`)**: Mọi logic hiển thị tên người dùng (Người phụ trách, Người quản lý, Người tạo `c_by`, Người cập nhật `u_by`) **BẮT BUỘC** gọi `resolveActorInfo(actor, { usersMap, currentUser, t })`. Hàm trả về `{ displayName, realName, isMe, uid }`.
  - **Đa ngôn ngữ (i18n)**: Sử dụng khóa từ điển `t('lbl_me')` (tiếng Việt: `"Tôi"`, tiếng Anh: `"Me"`). Tuyệt đối **KHÔNG hardcode** chuỗi `"Tôi"` trong JSX.
- **Quy Tắc Đẩy Lên Đầu Danh Sách (`buildUserOptionsWithMe`)**:
  - Trong tất cả các **Bộ lọc (Filter MultiSelect)** và **Dropdown Lựa chọn (Select / SearchableSelect / MultiSelect trong Modal)**:
  - **BẮT BUỘC** dùng `buildUserOptionsWithMe(usersList, { currentUserId, t, excludeId })`.
  - Hàm tự động sắp xếp tài khoản người dùng hiện tại (`currentUserId`) lên **vị trí đầu tiên (Index 0 - trên cùng)** của danh sách options với nhãn hiển thị dạng `Tôi (Tên | Email)` hoặc `Me (Name | Email)`. Các user khác được sắp xếp theo bảng chữ cái A-Z bên dưới.
- **Quy Tắc Sao Chép Tên Thật (Real Name Clipboard Copying Rule)**:
  - Khi người dùng bấm nút Copy hoặc click sao chép trên bất kỳ thành phần nào đang hiển thị nhãn "Tôi" / "Me" (trong `DescriptionList`, Tooltip hoặc Table cell):
  - **BẮT BUỘC SAO CHÉP TÊN THẬT HOẶC EMAIL (`realName`)** của người dùng, **TUYỆT ĐỐI KHÔNG** sao chép chuỗi chữ `"Tôi"` hay `"Me"`.
  - Với `DescriptionList` / `DescriptionItem`: Bắt buộc truyền `copyText: info.realName`.
- **Đồng Bộ Trên Cột Audit Hệ Thống (`getBaseAuditColumns`)**:
  - Khi gọi `getBaseAuditColumns`, **BẮT BUỘC** truyền thêm `currentUserId: user?.id` và `meLabel: t('lbl_me')` để các cột `c_by`, `u_by` tự động nhận diện tài khoản hiện tại và hiển thị "Tôi" / "Me" chuẩn xác trên toàn bộ các bảng danh sách (Khách hàng, Nhân viên, Tag, Vai trò, v.v.).



