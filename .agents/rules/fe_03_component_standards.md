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
    - Nút bấm: Gọi `<Button>`
    - Khối layout / Card: Gọi `<Zone>`
    - Ô nhập liệu: Gọi `<TextInput>`

## 3. Form & Input Standards (ForwardRef)
- Tất cả các component đóng vai trò nhập liệu (Input, Checkbox, Select, Textarea) bắt buộc phải được bọc qua `React.forwardRef`.
- Mục đích: Để hỗ trợ các thư viện quản lý form như `react-hook-form` có thể truy xuất ref trực tiếp vào thẻ HTML cơ bản.

## 4. UI Separation (Divider)
- Để phân tách các khối nội dung, tuyệt đối tránh dùng các class `border-t`, `border-b` nội tuyến nếu không thật sự cần thiết.
- Khuyến khích tận dụng tối đa `<Divider />` component để phân tách nội dung rõ ràng và nhất quán trên toàn hệ thống. Mặc định dùng `<Divider />` (chạy ngang). Nếu phân chia cột dọc, truyền prop hướng `vertical` tương ứng nếu component có hỗ trợ.
