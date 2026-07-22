# Authentication & Onboarding Flow

Tài liệu này hướng dẫn chi tiết luồng đăng ký, xác thực, đăng nhập và xoay vòng token trong hệ thống Sowfkun Verse.

---

## 1. Luồng Onboarding (Đăng ký mới)

### Bước 1: Gửi yêu cầu đăng ký (Register & Send OTP)
Gửi yêu cầu khởi tạo tổ chức và tài khoản Owner. Hệ thống sẽ tự sinh OTP lưu vào Redis và gửi qua Kafka để gửi mail cho User.

- **Endpoint:** `POST /api/v1/auth/register`
- **Yêu cầu bảo mật:** Đi qua E2EE Middleware (nếu cờ `ENABLE_PAYLOAD_ENCRYPTION=true`).
- **Request Body (JSON):**
```typescript
interface RegisterRequest {
  business_name: string; // Tên doanh nghiệp/tổ chức
  owner_name: string;    // Tên chủ tài khoản
  phone: string;         // Số điện thoại liên hệ
  email: string;         // Email đăng ký (được lowercase tự động)
  password: string;      // Mật khẩu (độ dài >= 8 ký tự, gồm chữ hoa/thường, số, ký tự đặc biệt)
  language?: string;     // Ngôn ngữ gửi mail ("vi" hoặc "en", mặc định "vi")
}
```
- **Response thành công (`MSG_OTP_SENT`):**
```json
{
  "message": "Mã OTP đã được gửi về email của bạn"
}
```

### Bước 2: Xác thực OTP (Verify OTP & Complete)
Xác nhận mã OTP nhận qua Email. Nếu hợp lệ, hệ thống sẽ chính thức tạo mới Tenant (status: `ACTIVE`), User (status: `ACTIVE`), xóa OTP khỏi Redis và trả về cặp Token.

- **Endpoint:** `POST /api/v1/auth/verify-otp`
- **Request Body (JSON):**
```typescript
interface VerifyOTPRequest {
  email: string;
  otp: string; // Chuỗi 6 chữ số
}
```
- **Response thành công (`MSG_SUCCESS`):**
```typescript
interface AuthSuccessResponse {
  access_token: string;  // Access Token dùng trong header Bearer (hạn ngắn)
  refresh_token: string; // Refresh Token lưu tại HttpOnly Cookie (hạn dài 7 ngày)
  user: {
    id: string;
    tenant_id: string;
    email: string;
    name: string;
    is_owner: boolean;
  };
}
```

---

## 2. Luồng Đăng nhập (Login Flow)

Hệ thống hỗ trợ chống Brute Force (khóa 30 phút khi nhập sai 5 lần liên tiếp).

- **Endpoint:** `POST /api/v1/auth/login`
- **Request Body (JSON):**
```typescript
interface LoginRequest {
  email: string;
  password: string;
}
```
- **Response thành công (`MSG_SUCCESS`):**
Trả về đầy đủ thông tin User và Tenant của họ để phục vụ lưu trữ context ở Frontend.
```typescript
interface AuthSuccessResponse {
  access_token: string;
  refresh_token: string;
  user: {
    id: string;
    tenant_id: string;
    email: string;
    name: string;
    is_owner: boolean;
  };
  tenant: {
    id: string;
    name: string;
    email: string;
    phone: string;
    status: string; // ACTIVE, INACTIVE
    tier: string;   // FREE, PREMIUM
    language: string;
  };
}
```
- **Mã lỗi bảo mật cần lưu ý:**
  - `ERR_MAX_LOGIN_ATTEMPTS` (HTTP 400): Tài khoản bị khóa 30 phút do brute-force.
  - `ERR_INVALID_CREDENTIALS` (HTTP 400): Lỗi chung khi nhập sai pass hoặc email chưa active (chống User Enumeration).

---

## 3. Luồng Refresh Token (Xoay vòng Session)

Refresh Token được quản lý dưới dạng **Redis Hashmap** tại key `auth:user_sessions:<user_id>`. Khi gọi API, token cũ sẽ bị xóa và thay thế bằng token mới (Token Rotation).

- **Endpoint:** `POST /api/v1/auth/refresh-token`
- **Request Body (JSON):**
```typescript
interface RefreshTokenRequest {
  refresh_token: string;
}
```
- **Response thành công (`MSG_SUCCESS`):**
*Lưu ý: API Refresh Token KHÔNG trả về thông tin Tenant để giảm tải truy vấn cơ sở dữ liệu.*
```typescript
interface RefreshSuccessResponse {
  access_token: string;
  refresh_token: string;
  user: {
    id: string;
    tenant_id: string;
    email: string;
    name: string;
    is_owner: boolean;
  };
}
```

---

## 4. Cơ chế lưu trữ & Quản lý Session ở Client (FE)

Để đáp ứng yêu cầu **"tắt trình duyệt mở lại dưới 15 phút không cần đăng nhập lại, quá 15 phút bắt buộc đăng nhập lại"**:

1. **Vấn đề lưu trữ Refresh Token**:
   - Để session có thể khôi phục sau khi tắt hẳn trình duyệt, **Refresh Token TUYỆT ĐỐI không dùng Session Cookie** (vì Session Cookie bị xóa ngay khi tắt trình duyệt).
   - Thay vào đó, sử dụng **HttpOnly Cookie thông thường có đặt `Max-Age` / `Expires` dài hạn** (ví dụ: 7 ngày) được cấu hình tự động từ Backend, HOẶC lưu trữ `refresh_token` trong **LocalStorage/SessionStorage** (hoặc Cookie thường có thể truy cập nếu Backend không dùng HttpOnly).
   - *Khuyên dùng:* Lưu Refresh Token trong **HttpOnly Cookie** có cấu hình `Max-Age` dài hạn để tránh bị tấn công XSS, đồng thời cho phép khôi phục phiên khi mở lại trình duyệt.

2. **Cơ chế Tracking Active & Kiểm tra 15 phút**:
   - Khi đăng nhập/refresh thành công, FE lưu biến `last_active_at` (Unix Timestamp milliseconds) vào `localStorage`.
   - **Khi người dùng đang sử dụng (Active)**: Cứ mỗi 5 phút một lần, nếu có hoạt động (click, scroll, keypress), FE cập nhật lại `last_active_at = CurrentTime` trong `localStorage`.
   - **Khi tắt trình duyệt và mở lại**:
     - FE đọc `last_active_at` từ `localStorage`.
     - Tính toán khoảng thời gian rảnh: `diff = CurrentTime - last_active_at`.
     - **Nếu `diff > 15 phút`**: FE chủ động xóa sạch localStorage (User Context, Access Token) và redirect người dùng về trang `/login` ngay lập tức mà không cần gọi API lên server.
     - **Nếu `diff <= 15 phút`**: FE tự động gọi API `/refresh-token` gửi kèm `refresh_token` để lấy cặp Access Token mới và tiếp tục phiên làm việc bình thường.

3. **Luồng tự động Refresh Token (Silent Refresh)**:
   - FE cấu hình một interceptor (ví dụ: Axios Interceptor). Khi Access Token hết hạn (Server trả lỗi 401 hoặc token client check expired), FE sẽ tự động gọi API `/refresh-token` dưới nền để lấy token mới mà không làm gián đoạn trải nghiệm của người dùng.
