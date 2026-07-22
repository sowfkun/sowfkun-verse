# Frontend Architecture & Framework Rules

## 1. Next.js App Router
Dự án sử dụng **Next.js App Router**. Toàn bộ hệ thống routing phải được tổ chức trong thư mục `src/app`.
- **`src/app`**: Chỉ chứa các file liên quan đến routing (`page.tsx`, `layout.tsx`, `loading.tsx`, `error.tsx`). Không chứa UI components phức tạp ở đây.
- **`src/components`**: Chứa toàn bộ các UI components dùng chung và các logic view độc lập.

## 2. Styling Strategy (Tailwind CSS v4 + CSS Modules)
Dự án kết hợp sức mạnh của Tailwind CSS v4 (cho utility classes nhanh) và CSS Modules (cho scoped component styles).
- **Tránh xung đột:** Để tránh class CSS bị conflict hoặc rò rỉ (leak) ra ngoài scope, mỗi UI component độc lập bắt buộc phải sử dụng **CSS Modules** (tạo file `[ComponentName].module.css`).
- **Tailwind trong CSS Modules:** Bạn có thể sử dụng `@apply` của Tailwind bên trong các file `.module.css` để giữ code ngắn gọn mà vẫn đảm bảo tính cô lập của class.

## 3. Server vs Client Components
- Mặc định, mọi component trong App Router đều là **Server Components**.
- Chỉ thêm `"use client"` ở đầu file khi component thực sự cần:
  - React State/Lifecycle hooks (`useState`, `useEffect`, `useRef`, v.v.)
  - Tương tác trực tiếp với DOM hoặc Browser API.
  - Xử lý các event listeners (như `onClick`, `onChange`).
- Đẩy `"use client"` xuống các component con (leaf components) sâu nhất có thể để tối ưu hiệu suất.
