# Component Standards

## 1. Tách biệt Styling (Decoupling)
- Mỗi Component giao diện độc lập BẮT BUỘC phải đi kèm với một file `[ComponentName].module.css`.
- Tuyệt đối không import chéo file CSS của component khác.
- Việc áp dụng style phải thông qua object `styles` sinh ra từ file `.module.css`.

## 2. Reusability (Tái sử dụng Component)
- **Hỏi trước khi tạo:** Nếu Agent thấy cần thiết tạo một component hoàn toàn mới, phải hỏi ý kiến và báo cáo cho User. Không tự ý đẻ thêm component không cần thiết.
- **Sử dụng Core Components:** Nếu có một thành phần cơ bản đã được chuẩn hóa, **BẮT BUỘC** phải gọi component đó, không tự vẽ lại bằng HTML thô.
    - Chữ viết: Gọi `<Typo>`
    - Đường phân cách: Gọi `<Divider>`
    - Nút bấm chuẩn hóa: Gọi `<Button>`, hoặc các Action Buttons chuyên dụng `<AddButton>`, `<SaveButton>`, `<CancelButton>`, `<EditButton>`, `<DeleteButton>` (thuần chữ, không icon mặc định).
    - Khối layout / Card: Gọi `<Zone>`
    - Ô nhập liệu: Gọi `<TextInput>`
    - Điều hướng tab: Gọi `<Tabs>`
    - Danh sách chi tiết Key-Value: Gọi `<DescriptionList>`

## 3. Form & Input Standards (ForwardRef)
- Tất cả các component đóng vai trò nhập liệu (Input, Checkbox, Select, Textarea) bắt buộc phải được bọc qua `React.forwardRef`.
- Mục đích: Để hỗ trợ các thư viện quản lý form như `react-hook-form` có thể truy xuất ref trực tiếp vào thẻ HTML cơ bản.

## 4. UI Separation (Divider)
- Để phân tách các khối nội dung, tuyệt đối tránh dùng các class `border-t`, `border-b` nội tuyến nếu không thật sự cần thiết.
- Khuyến khích tận dụng tối đa `<Divider />` component để phân tách nội dung rõ ràng và nhất quán trên toàn hệ thống. Mặc định dùng `<Divider />` (chạy ngang). Nếu phân chia cột dọc, truyền prop hướng `vertical` tương ứng nếu component có hỗ trợ.

## 6. Cấu Trúc Phân Nhóm Thư Mục (Component Directory Taxonomy)
Mọi component trong thư mục `src/components/` bắt buộc phải được phân loại vào đúng nhóm chức năng tương ứng:
- **`cards/`**: Các loại thẻ hiển thị dữ liệu (`<Zone>`, `<DescriptionList>`, `<StatCard>`, v.v.).
- **`forms/`**: Các thành phần biểu mẫu & nhập liệu (`<TextInput>`, `<Form>`, `<Select>`, v.v.).
- **`navigation/`**: Các thành phần điều hướng (`<Tabs>`, `<Breadcrumbs>`, v.v.).
- **`primitives/`**: Các thành phần nguyên tử nền tảng (`<Button>`, `<Typo>`, `<Divider>`, `<Badge>`, `<BrandLogo>`).
- **`guards/`**: Các wrapper bảo mật & phân quyền route (`<RouteGuard>`).
- **`layout/`**: Khung sườn ứng dụng (`<AppLayout>`, `<Header>`, `<Sidebar>`).
- **`tables/`**: Các thành phần hiển thị bảng dữ liệu (`<DataTable>`, bộ render cell `<TableCells>`, v.v.).
- **`icons/`**: Hệ thống SVG icon.

> **Quy tắc Barrel Export**: Mọi component BẮT BUỘC phải được re-export tại `src/components/index.ts`. Các trang (pages) và components khác khi sử dụng BẮT BUỘC phải import tập trung từ `@/components` (Ví dụ: `import { Button, Typo, Tabs, Zone } from '@/components'`).

## 7. Tuân Thủ Tham Số Mặc Định (Default Parameter Compliance)
- **Tôn trọng Style mặc định**: Khi sử dụng các Core Component (như `<Typo>`, `<Button>`, `<TextInput>`, `<Tabs>`), **TUYỆT ĐỐI TRÁNH** việc đè kích thước (font-size), màu sắc hoặc font-family bằng CSS tùy biến bên ngoài hoặc bằng các class cưỡng ép (`!text-xs`, `!text-sm`, `!font-bold` v.v.) trừ trường hợp có yêu cầu nghiệp vụ cực kỳ đặc thù.
- **Để Component tự quyết định**: Hãy luôn để component tự cấu hình hiển thị dựa trên props định danh truyền vào của nó (Ví dụ: `variant="body"` đã tự động có size `14px` và màu sắc `var(--text-secondary)`, không cần đè thêm kích thước hay màu sắc thủ công). Điều này giúp toàn bộ ứng dụng giữ đúng tỷ lệ thiết kế (Design Ratio) và tính nhất quán tuyệt đối.

## 8. Table & Data Grid Standards
- **Schema-Driven Column Definition**: Mọi cấu hình cột cho `<DataTable>` bắt buộc phải được khai báo dưới dạng cấu hình schema metadata thông qua các thuộc tính của `Column<T>` (`type`, `getSubtitle`, `getIndex`, `getLine2`, `getBadgeVariant`).
- **Nghiêm cấm viết logic JSX thủ công hoặc switch-case màu sắc trực tiếp trong `render` của cột** ở các file Page (trừ trường hợp tuỳ biến giao diện đặc biệt).
- **Đóng gói Table Cells**: Các kiểu hiển thị cell chuẩn (`title-subtitle`, `double-text`, `badge`) bắt buộc phải được gom chung và đóng gói xử lý tự động trong lõi Table để tái sử dụng ở mọi module, đảm bảo tính đóng gói và tối ưu hiệu năng.
- **Universal Base Audit Columns (`getBaseAuditColumns`)**:
  - Các thuộc tính Audit hệ thống (`c_at` - Ngày tạo, `u_at` - Lần update cuối, `c_by` - Người tạo, `u_by` - Người update cuối) phản chiếu trực tiếp từ `BaseEntity` của Backend Go và xuất hiện ở mọi collection dữ liệu.
  - **BẮT BUỘC** sử dụng helper dùng chung `...getBaseAuditColumns<T>(t)` từ `@/components` khi khai báo cột cho bảng dữ liệu. TUYỆT ĐỐI KHÔNG tự khai báo lặp lại 4 cột này thủ công ở từng page riêng lẻ.
  - Helper này đã được đóng gói toàn bộ logic i18n (`t`), định dạng thời gian 24h UTC, Typography chuẩn `<Typo variant="body">` và font Monospace thống nhất toàn hệ thống.
- **Universal Common Column Builders (`commonColumns.tsx`)**:
  - Đối với các cột dữ liệu thông dụng lặp lại giữa các module (như Tên chính `getNameColumn`, Email `getEmailColumn`, Số điện thoại `getPhoneColumn`, Trạng thái `getStatusColumn`, Người phụ trách `getOwnerColumn`):
  - **BẮT BUỘC** sử dụng các hàm builder chuẩn từ `@/components` để khởi tạo cột thay vì viết lại schema thủ công.
  - Các builder này đã thiết lập sẵn độ rộng chuẩn (`initialWidth`), kiểu hiển thị (`type`), typography chuẩn (`<Typo variant="body">`), Font Monospace cho số/mã định danh, màu sắc Badge tự động theo trạng thái, và liên kết từ điển đa ngôn ngữ (`t`).
  - **Cơ chế Alias Resolution tự động**: Các builder đã tích hợp cơ chế phân giải tên trường linh hoạt (VD: Email tự nhận `email`, `mail`, `email_address`; Phone tự nhận `phone`, `phone_number`, `mobile`, `tel` và hỗ trợ cả phone object lẫn phone string; Name tự nhận `name`, `full_name`, `display_name`; Owner tự nhận `owner_id`, `owner`, `assignee` và hỗ trợ cả Actor object).
- **Đồng bộ hóa Nhãn Bộ lọc & Tiêu đề Cột (Filter-Column Label Synchronization)**:
  - Tên nhãn của các bộ lọc (`availableFilters`) bản chất chính là tiêu đề của các cột thuộc tính tương ứng trên bảng.
  - **BẮT BUỘC** sử dụng chung các khóa dịch `col_*` (VD: `col_status`, `col_owner`, `col_created_at`) cho cả cột và bộ lọc. TUYỆT ĐỐI KHÔNG tạo các khóa `filter_*` trùng lặp nghĩa.
  - `<DataTable />` tự động kế thừa chính xác `column.header` sang nhãn bộ lọc nếu `AvailableFilterItem.label` được để trống.
- **Quy tắc Bộ lọc "Chọn tất cả" (Select All Filter & Zero API Payload Rule)**:
  - Tất cả các bộ lọc dạng chọn nhiều (`<MultiSelect />`) mặc định hỗ trợ tùy chọn `"Tất cả"` (`select_all`) ở đầu danh sách popover.
  - Khi người dùng chọn `"Tất cả"` (toàn bộ options được chọn) hoặc để trống (`[]`):
    - **Phía UI**: Badge hiển thị nhãn `: Tất cả` trực quan.
    - **Phía Network / API**: **TUYỆT ĐỐI KHÔNG TRUYỀN** tham số filter đó lên API (bỏ qua / omit khỏi query parameters) để tiết kiệm băng thông và tối ưu câu lệnh query DB. Chỉ gửi query parameter lên API khi người dùng lọc một tập con cụ thể (`0 < value.length < options.length`).
- **Thứ tự Ưu tiên của Bộ lọc (Filter Priority Order)**:
  - Bộ lọc khoảng thời gian (`DateRangePicker` - Ngày tạo / `c_at` / `joined_at`) **BẮT BUỘC LUÔN ĐƯỢC ĐẶT Ở VỊ TRÍ ĐẦU TIÊN (INDEX 0)** trong mảng `availableFilters` để tạo điểm neo tìm kiếm mốc thời gian rõ ràng nhất cho người dùng.
  - Theo sau lần lượt là các bộ lọc phân loại chính: Trạng thái (`status`), Người phụ trách (`owner_id`), và các bộ lọc nghiệp vụ riêng.







