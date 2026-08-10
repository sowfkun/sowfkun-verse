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

## 4. API Request & Global Exception Handling
Mọi giao tiếp API với Backend đều được chuẩn hóa và tự động hóa cơ chế bắt lỗi để tăng cường trải nghiệm người dùng (UX):
- **Cơ chế apiFetch và Global Toast**: Mặc định, mọi request gọi qua `apiFetch` khi thất bại (status code khác 200 hoặc lỗi kết nối mạng) sẽ tự động phát sự kiện `'api-error'` toàn cục. `NotificationProvider` lắng nghe sự kiện này và hiển thị Toast thông báo lỗi màu đỏ ở góc dưới bên phải.
- **Message đa ngôn ngữ sẵn từ Backend**: Backend tự động dịch nội dung lỗi dựa trên ngôn ngữ Client truyền lên. Frontend hiển thị trực tiếp `message` nhận được từ phản hồi lên Toast, tuyệt đối KHÔNG gọi hàm dịch `t()` thủ công ở Frontend cho các lỗi API.
- **Tùy chọn skipToastOnError (Bắt buộc cho tất cả API)**:
  - Tất cả các API được viết ra ở Frontend **bắt buộc** phải nhận tham số cấu hình tùy chọn kèm theo (ví dụ: `options?: ApiOptions` ở cuối signature) để đảm bảo khả năng tùy chỉnh từ bên ngoài.
  - Khi cần ẩn Toast lỗi hệ thống để tự xử lý lỗi cục bộ trong trang (ví dụ hiển thị viền đỏ, alert riêng), truyền `{ skipToastOnError: true }` từ ngoài vào.
- **Cấm log console**: Tuyệt đối không sử dụng `console.log` hoặc `console.error` để in vết lỗi API trong catch block của component/trang nhằm giữ console trình duyệt sạch đẹp.

## 5. Socket Event Standards & Conventions
Hệ thống WebSocket sử dụng mô hình sự kiện 2 chiều (Bidirectional) thống nhất. Để tránh sự tùy tiện khi tích hợp:
- **Định nghĩa tập trung**: Toàn bộ Socket Event và data type payload bắt buộc phải được khai báo tập trung trong `src/lib/socket/events.ts`. Nghiêm cấm hardcode chuỗi sự kiện ở các components/hooks.
- **Unified Payload Model**: Tất cả các gói tin gửi đi hay nhận về đều phải bọc qua struct `SocketMessagePayload<T>` chuẩn (gồm các field `event`, `data`, `target_type`, `target_id`, `source`).
- **Phân tách xử lý (Clean Dispatching)**:
  - **Global/System events**: Các sự kiện ảnh hưởng diện rộng hoặc trạng thái kết nối chung (như `CLIENT_PONG`, `NOTIFICATION_RECEIVED`) được quản lý thông qua custom hook `useGlobalSocketHandlers.ts` và tích hợp tại `SocketProvider`.
  - **Local/Domain-specific events**: Các sự kiện đặc thù (ví dụ: Chat, Task, Project changes) **không được** gọi `subscribe` trực tiếp từ giao diện (Component View). Chúng phải được bọc trong một Custom Hook riêng biệt của Domain tương ứng (ví dụ: `useChatSocket`), chịu trách nhiệm subscribe, cập nhật state/cache, và tự động cleanup khi unmount.
- **Tránh kết nối lại vô hạn (Connection Loop Protection)**: Khi viết callback socket hoặc handler, bắt buộc sử dụng cơ chế `useRef` hoặc dependency array rỗng để giữ hàm ổn định, không đưa các hàm động thay đổi liên tục vào dependency array của `connect` / `SocketProvider`.
