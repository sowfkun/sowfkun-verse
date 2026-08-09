# Icon Standards (Quy chuẩn Biểu tượng)

Tài liệu này quy định toàn bộ tiêu chuẩn về việc sử dụng và tổ chức Icon trên toàn bộ hệ thống Frontend.

---

## 1. Phong cách Thiết kế Chuẩn (Icon Style: Lucide Stroke)
Tất cả các icon trong dự án bắt buộc phải tuân theo phong cách **Lucide / Feather Stroke** để đảm bảo tính đồng bộ, tinh giản và hiện đại (Modern Dark UI):
- **ViewBox:** `0 0 24 24`
- **Fill:** `none`
- **Stroke:** `currentColor` (kế thừa màu chữ của phần tử cha hoặc token CSS)
- **Stroke Width:** `2` (hoặc `1.75` / `2.5` tùy theo độ dày mong muốn, mặc định `2`)
- **Stroke Linecap / Linejoin:** `round`

---

## 2. Tổ chức & Đóng gói (Organization)
- **Tập trung hóa (Centralized Icons):** Tất cả các icon dùng chung **BẮT BUỘC** được đặt trong thư mục `src/components/icons/`.
- **Tách biệt Component:** Mỗi icon là một component React độc lập hoặc gom xuất qua `src/components/icons/index.ts`.
- **Props chuẩn:** Mỗi Icon Component nhận các props cơ bản:
  ```tsx
  export interface IconProps extends React.SVGProps<SVGSVGElement> {
    size?: number | string;
    className?: string;
  }
  ```

---

## 3. Kích thước Chuẩn (Size Scale)
Tuyệt đối không sử dụng kích thước tùy tiện. Tuân thủ 4 kích thước chuẩn:
- **`sm` (16px):** Dùng bên trong badge, chip, nút bấm kích thước nhỏ (`sm`), thông báo phụ.
- **`md` (20px) - Mặc định:** Dùng cho thanh điều hướng Sidebar, menu items, nút bấm thông thường (`md`), input prefix/suffix icon.
- **`lg` (24px):** Dùng cho tiêu đề trang, TopBar actions, modal headers, card headers.
- **`xl` (32px - 48px):** Dùng cho Empty States, trang 404, màn hình chào đón (Hero/Feature blocks).

---

## 4. Quy tắc Màu sắc & Tương tác
- **Không hardcode mã màu:** Luôn sử dụng `stroke="currentColor"` hoặc các biến CSS Design Tokens (`var(--text-secondary)`, `var(--accent-primary)`).
- **Hover & Active States:** Thay đổi màu sắc thông qua CSS của thẻ cha (vd: `color: var(--text-primary)` khi hover) để icon tự đổi màu mượt mà.
