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

## 5. Cấu Trúc Phân Nhóm Thư Mục (Component Directory Taxonomy)
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

## 6. Tuân Thủ Tham Số Mặc Định (Default Parameter Compliance)
- **Tôn trọng Style mặc định**: Khi sử dụng các Core Component (như `<Typo>`, `<Button>`, `<TextInput>`, `<Tabs>`), **TUYỆT ĐỐI TRÁNH** việc đè kích thước (font-size), màu sắc hoặc font-family bằng CSS tùy biến bên ngoài hoặc bằng các class cưỡng ép (`!text-xs`, `!text-sm`, `!font-bold` v.v.) trừ trường hợp có yêu cầu nghiệp vụ cực kỳ đặc thù.
- **Để Component tự quyết định**: Hãy luôn để component tự cấu hình hiển thị dựa trên props định danh truyền vào của nó (Ví dụ: `variant="body"` đã tự động có size `14px` và màu sắc `var(--text-secondary)`, không cần đè thêm kích thước hay màu sắc thủ công). Điều này giúp toàn bộ ứng dụng giữ đúng tỷ lệ thiết kế (Design Ratio) và tính nhất quán tuyệt đối.











