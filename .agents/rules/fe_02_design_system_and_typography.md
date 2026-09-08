# Design System & Typography Rules

Đây là bộ quy tắc cốt lõi về UI/UX bắt buộc Agent phải tuân thủ nghiêm ngặt để đảm bảo tính nhất quán của hệ thống.

## A. Typography (Hệ thống chữ)
Tuyệt đối không dùng trực tiếp các thẻ HTML (`h1`, `h2`, `p`, `span`) chứa class text tùy tiện. **BẮT BUỘC** sử dụng component `<Typo level="...">` hoặc `<Typo variant="...">` với các cấp độ chuẩn sau:

*   **`h1` (16px, `text-base font-bold`)**: Dùng cho **Tiêu đề trang (Page Title)** và **Tiêu đề Modal (`<Modal />`)**.
*   **`h2` (14px, `text-sm font-semibold`)**: Dùng cho **Tiêu đề Zone (`<Zone />`)** và các khối form/card nhỏ.
*   **`body` (14px, `text-sm font-normal`)**: Dùng cho **Nội dung văn bản chính**, nhãn của Input (Label), nội dung trong Table.
*   **`body-sm` (12px, `text-xs font-normal`)**: Dùng cho các **Mô tả phụ**, text hỗ trợ dưới label, nội dung hướng dẫn.
*   **`caption` (11px, `text-[11px] font-medium`)**: Dùng cho **Timestamp, text báo lỗi** (Error message của input), chú thích siêu nhỏ.
*   **`overline` (10px, `text-[10px] font-bold`, ALL CAPS)**: Bắt buộc dùng cho các nhãn phân loại, badge, hoặc các cụm từ nhấn mạnh đặc tính.
*   **Quy tắc Không Đè Style Tuỳ Tiện**: Tuyệt đối không được phép sử dụng class CSS (như `!text-[var(--text-secondary)]`, `!text-xs`, v.v.) nhằm ghi đè trực tiếp kích thước font hoặc màu sắc của component `<Typo>`. Mọi cấu hình hiển thị phải sử dụng đúng variant/level đã được quy chuẩn để đảm bảo tính nhất quán của hệ thống.

## B. Spacing & Padding Tokens (Hệ thống khoảng cách - On-Premise Design Tokens)
Hệ thống sử dụng base 8px (Grid 8pt). **BẮT BUỘC** sử dụng các biến CSS Design Tokens đã được định nghĩa trong `:root` của `globals.css`, tuyệt đối không hardcode khoảng cách tùy tiện:

### 1. Spacing Scale Tokens (Max 24px Compact Style)
*   `var(--spacing-xs)`: `4px` - Khoảng cách siêu nhỏ (icon và text, nhãn và dấu hoa thị `*`).
*   `var(--spacing-sm)`: `8px` - Khoảng cách nhóm sát nhau (Label và Input, padding dọc input).
*   `var(--spacing-md)`: `12px` - Khoảng cách trung bình (padding ngang input `px-[var(--padding-input-x)]`).
*   `var(--spacing-base)`: `16px` - Khoảng cách giữa các row trong form, padding nút nhỏ `sm`.
*   `var(--spacing-lg)`: `24px` - Khoảng cách lớn nhất (Padding Card/Form `p-[var(--padding-card)]`, padding `Zone`, padding ngang nút `md`/`lg`, lề tiêu đề).

### 2. Component Specific Tokens (Padding & Dimensions)
*   **Card / Form / Zone:** `var(--padding-card)`: Mặc định trỏ về `var(--spacing-lg)` (`24px`).
*   **Input Field:**
    *   Padding dọc: `var(--padding-input-y)`: `var(--spacing-sm)` (`8px`).
    *   Padding ngang: `var(--padding-input-x)`: `var(--spacing-md)` (`12px`).
    *   Chiều cao chuẩn: `var(--height-input)`: `40px`.
*   **Button Dimensions (Chiều cao & Padding ngang):**
    *   `var(--height-btn-sm)`: `32px` (Đi kèm padding ngang `var(--spacing-base)` - `16px`).
    *   `var(--height-btn-md)`: `40px` (Đi kèm padding ngang `var(--spacing-lg)` - `24px`).
    *   `var(--height-btn-lg)`: `48px` (Đi kèm padding ngang `var(--spacing-lg)` - `24px`).

## C. Color & Design Tokens (Biến màu sắc)
Tuyệt đối không dùng mã màu Hex (VD: `#fff`, `#333`). Bắt buộc dùng biến CSS để đảm bảo khả năng đổi Theme dễ dàng (On-Premise Ready):

*   `var(--bg-primary)`: Nền tổng thể của toàn trang web (Page Background).
*   `var(--bg-secondary)`: Nền của Sidebar, thanh điều hướng, card phụ.
*   `var(--bg-zone)`: Nền của component `<Zone />`, Card, Modal.
*   `var(--bg-active)`: Nền trạng thái Active của Menu/Tabs (`rgba(99, 102, 241, 0.22)`).
*   `var(--bg-active-hover)`: Nền trạng thái Active khi hover (`rgba(99, 102, 241, 0.32)`).
*   `var(--text-primary)`: Dành cho text chính (H1-H4 và Body text).
*   `var(--text-secondary)`: Dành cho text phụ (Body-sm, Caption, mô tả phụ, placeholder của Input).
*   `var(--border-color)`: Màu viền tiêu chuẩn cho Input, Divider, viền của Zone/Card.
*   `var(--border-active)`: Màu viền trạng thái Active (`rgba(99, 102, 241, 0.45)`).
*   `var(--primary-color)` / `var(--accent-primary)`: Màu thương hiệu chính, dùng cho Button chính, text link, trạng thái Focus/Active.
*   `var(--error-color)`: Dùng cho trạng thái lỗi (Border lỗi, Caption báo lỗi).
*   **Quy tắc màu sắc Badge/Tag**: Tuyệt đối không được phép hardcode màu sắc Hex hoặc mã màu RGBA cụ thể cho các Badge vai trò hay trạng thái (như `text-[#fbbf24]`, `bg-[rgba(251,191,36,0.12)]`). Bắt buộc phải sử dụng component `<Badge variant="...">` chung để tự động ánh xạ theo hệ màu Semantic Status Colors (`success`, `danger`, `warning`, `info`, `neutral`) thông qua các biến CSS (`--color-success`, `--color-danger`, `--color-warning`, `--color-info`, `--text-muted`).

## D. Quy Tắc Đặt Tên & Nhãn Phân Cấp (Non-Redundant Hierarchical Naming Rules)
- **Không lặp lại tiêu đề cha**: Khi một khối, nhóm card, modal hoặc khu vực giao diện đã có **Tiêu đề lớn / Tiêu đề nhóm** (Parent/Group Header - ví dụ: "Nhân viên", "Quản trị hệ thống", "Cấu hình"), các tiêu đề con, mục lựa chọn hoặc nhãn con bên trong (Child Items / Checkboxes / Action Labels) **TUYỆT ĐỐI KHÔNG** lặp lại từ khóa của tiêu đề lớn.
- **Quy tắc Tinh gọn (Chỉ dùng Động từ hành động hoặc Danh từ thuần túy)**:
  - ✅ **Đúng**: Nhóm "Nhân viên" -> các mục con chỉ ghi "Xem", "Quản lý" (mô tả: "Xem danh sách và hồ sơ", "Tạo mới, chỉnh sửa, phân quyền và xóa").
  - ❌ **Sai**: Nhóm "Nhân viên" -> mục con ghi "Xem nhân viên", "Quản lý nhân viên", "Xóa nhân viên".
  - ✅ **Đúng**: Tiêu đề Modal tạo mới là "Thêm mới", modal xóa là "Xóa" (không ghi "Thêm mới vai trò", "Xóa vai trò", "Thêm vai trò mới").


