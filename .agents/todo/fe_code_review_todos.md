# Danh sách các điểm cần khắc phục và cải thiện (Frontend Code Review Todo)

Tài liệu này ghi nhận các điểm chưa hợp lý, chưa tối ưu hoặc vi phạm các quy tắc thiết kế (Rules) được phát hiện trong quá trình rà soát source code của `sowfkun-verse-web`.

---

## 1. Vi phạm Quy định Styling (Decoupling CSS)
*   **Hiện trạng**: Quy tắc số 1 trong `fe_03_component_standards.md` yêu cầu mọi component độc lập bắt buộc đi kèm file `[ComponentName].module.css` để cô lập style.
*   **Vấn đề**: 
    *   Toàn bộ components trong `src/components/forms/` (`DateRangePicker.tsx`, `DateTimePicker.tsx`, `Form.tsx`, `MultiSelect.tsx`, `SearchBar.tsx`, `Select.tsx`, `TextInput.tsx`) đang dùng trực tiếp Tailwind classes inline.
    *   Hầu hết components trong `src/components/primitives/` (`Button.tsx`, `Typo.tsx`, `Divider.tsx`, `Badge.tsx`) không có file `.module.css` đi kèm.
*   **Todo**: Chuyển đổi các styles Tailwind cứng này sang CSS Modules tương ứng để bảo vệ tính đóng gói và dễ tùy biến theme.

---

## 2. Hardcode mã màu Hex trong CSS Modules
*   **Hiện trạng**: Quy tắc mục C trong `fe_02_design_system_and_typography.md` nghiêm cấm sử dụng mã màu Hex (`#fff`, `#333`...) để đảm bảo đổi theme On-Premise dễ dàng.
*   **Vấn đề**: Vẫn còn nhiều mã màu Hex bị hardcode trực tiếp trong các file CSS Module:
    *   `src/components/tables/DataTable.module.css:156`: `background-color: #1e293b;` (Màu nền của tiêu đề cột `th`).
    *   `src/components/layout/Sidebar.module.css:186`: `color: #c7d2fe;`
    *   `src/components/layout/Header.module.css:98/117/184`: `color: #ffffff;`
    *   `src/components/layout/Header.module.css:207`: `color: #fbbf24;`
    *   `src/components/layout/Header.module.css:358`: `color: #60a5fa;`
    *   `src/components/layout/Header.module.css:364`: `color: #f472b6;`
*   **Todo**: Thay thế toàn bộ mã màu Hex trên bằng các biến màu CSS thích hợp (như `var(--bg-primary)`, `var(--text-secondary)`, `var(--color-warning)`, `var(--color-info)`, v.v.).

---

## 3. Hardcode mã màu RGBA
*   **Hiện trạng**: Việc lạm dụng `rgba(...)` với mã màu RGB cứng sẽ làm mất tính đồng bộ khi đổi theme.
*   **Vấn đề**: Có rất nhiều đoạn định nghĩa nền mờ và viền mờ dùng màu RGBA cứng (như `rgba(255, 255, 255, 0.05)` hay màu thương hiệu `rgba(99, 102, 241, 0.15)`) rải rác trong:
    *   `DataTable.module.css` (Nền hàng, border, page jump input).
    *   `Header.module.css` và `Sidebar.module.css` (Hiệu ứng kính mờ, bóng đổ glow).
    *   `Button.tsx` (Màu hover nền mờ).
*   **Todo**: Thay thế các màu RGBA cứng bằng hàm `color-mix(in srgb, var(--accent-primary) X%, transparent)` hoặc định nghĩa thêm các biến opacity trong `:root` của `globals.css` (ví dụ: `var(--bg-active)`).

---

## 4. Tái cấu trúc và Phân chia Component
*   **Vấn đề**: Component `<Badge>` đang nằm ở thư mục `primitives/`. Tuy nhiên, về mặt ngữ nghĩa nó phục vụ hiển thị dữ liệu trạng thái (Data Display), có thể xem xét chuyển sang nhóm phù hợp hơn hoặc giữ nguyên nhưng cần bổ sung tài liệu hướng dẫn.
*   **Todo**: Đồng bộ hoá tài liệu đặc tả thư mục trong `fe_03_component_standards.md` với thực tế cấu trúc files.
