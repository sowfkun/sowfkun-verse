# Design System & Typography Rules

Đây là bộ quy tắc cốt lõi về UI/UX bắt buộc Agent phải tuân thủ nghiêm ngặt để đảm bảo tính nhất quán của hệ thống.

## A. Typography (Hệ thống chữ)
Tuyệt đối không dùng trực tiếp các thẻ HTML (`h1`, `h2`, `p`, `span`) chứa class text tùy tiện. **BẮT BUỘC** sử dụng component `<Typo level="...">` với 8 cấp độ sau:

*   **`H1`**: Dùng cho tựa đề trang (Page Title), kích thước lớn nhất của màn hình.
*   **`H2`**: Dùng cho các tiêu đề phần lớn, phân vùng chính trong trang.
*   **`H3`**: Dùng làm tiêu đề cho component `<Zone />` hoặc các khối nội dung độc lập.
*   **`H4`**: Dùng cho tiêu đề các Card, Modal, hoặc nhóm form nhỏ.
*   **`Body`**: Dùng cho nội dung văn bản chính, nhãn của Input (Label), nội dung trong table.
*   **`Body-sm`**: Dùng cho các mô tả phụ, text hỗ trợ dưới label, nội dung không quá quan trọng.
*   **`Caption`**: Dùng cho timestamp, text lỗi (Error message của input), chú thích siêu nhỏ.
*   **`Overline`**: (ALL CAPS) Bắt buộc dùng cho các nhãn phân loại, badge, hoặc các cụm từ nhấn mạnh đặc tính (như tag "TYPO" hoặc "LEVEL SECOND" trong palette).

## B. Spacing (Hệ thống khoảng cách - 8pt Grid)
Hệ thống sử dụng base 8px. Mọi khoảng cách đều phải là bội số của 8 (hoặc 4 đối với khoảng cách siêu nhỏ).

*   **Giữa các Zone (Khối lớn):** Dùng `40px` (`gap-10`) hoặc padding tương đương để tạo không gian thở (Breathing room) tối đa giữa các khối nội dung độc lập.
*   **Bên trong Zone (Padding):** Sử dụng chuẩn Padding dọc `40px` (`py-10`) và ngang `32px` (`px-8`).
*   **Giữa Tiêu đề Zone và Nội dung:** Khoảng cách tiêu chuẩn là `24px` (`gap-6`) hoặc `32px` (`gap-8`).
*   **Giữa các thành phần nội dung nhỏ:** (ví dụ các Row trong form, các nút bấm): Dùng `16px` (`gap-4`).
*   **Khoảng cách nhóm sát nhau:** (ví dụ Label và Input): Dùng `8px` (`gap-2`) hoặc `4px` (`gap-1`).

## C. Color & Design Tokens (Biến màu sắc)
Tuyệt đối không dùng mã màu Hex (VD: `#fff`, `#333`). Bắt buộc dùng biến CSS để đảm bảo khả năng đổi Theme dễ dàng (On-Premise Ready):

*   `var(--bg-primary)`: Nền tổng thể của toàn trang web (Page Background).
*   `var(--bg-zone)` / `var(--bg-secondary)`: Nền của component `<Zone />`, Card, Modal.
*   `var(--text-primary)`: Dành cho text chính (H1-H4 và Body text).
*   `var(--text-secondary)`: Dành cho text phụ (Body-sm, Caption, mô tả phụ, placeholder của Input).
*   `var(--border-color)`: Màu viền tiêu chuẩn cho Input, Divider, viền của Zone/Card.
*   `var(--primary-color)`: Màu thương hiệu chính, dùng cho Button chính, text link, trạng thái Focus/Active.
*   `var(--error-color)`: Dùng cho trạng thái lỗi (Border lỗi, Caption báo lỗi).
