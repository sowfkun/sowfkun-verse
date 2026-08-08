# User Management Integration Flow

Tài liệu hướng dẫn quy trình tích hợp các API quản lý nhân viên và phân quyền dữ liệu (User & Hierarchy) cho Frontend và Mobile Client.

---

## 1. Overview & Security Rules

1. **Permission Check**:
   - Thêm nhân viên (`/add-employee`): Người dùng bắt buộc phải có quyền `USER_MANAGE`.
   - Xem danh sách nhân viên (`/list`, `/list-all`): Người dùng bắt buộc phải có quyền `USER_VIEW`.
   - Kích hoạt tài khoản (`/activate`): API công khai (Public API) dùng khi người dùng xác nhận link kích hoạt từ email.
2. **Accessible Hierarchy (Phân quyền dữ liệu cấp dưới)**:
   - Khi gọi API `/list` hoặc `/list-all`, hệ thống tự động phân giải cây quản lý (Hierarchy) để xác định danh sách các ID nhân viên mà tài khoản hiện tại được quyền xem dựa trên vai trò của họ (VD: Cấp quản lý chỉ xem được cấp dưới trực tiếp/gián tiếp).
   - Nếu là **Owner** (`is_owner == true`), hệ thống bỏ qua phân quyền và cho phép xem tất cả (`"ALL"`).
3. **UTC Time Standard**: Tất cả các giá trị thời gian trả về (như `c_at`, `u_at`) đều theo chuẩn UTC (Unix timestamp dạng number).

---

## 2. Add Employee API

Khởi tạo tài khoản nhân viên mới trong doanh nghiệp. Hệ thống sẽ lưu trạng thái `INACTIVE` và gửi email chứa token kích hoạt tài khoản.

- **Endpoint:** `POST /api/v1/user/add-employee`
- **Requires Auth:** Yes (Bearer Token)
- **Permissions:** `USER_MANAGE`
- **Headers:**
  - `Authorization: Bearer <access_token>`
  - `Content-Type: application/json`

### Request Body (`AddEmployeeRequest`)
```typescript
interface AddEmployeeRequest {
  email: string;       // Email nhân viên (bắt buộc, không trùng lặp)
  name: string;        // Tên hiển thị (bắt buộc, max 100 ký tự)
  phone?: string;      // Số điện thoại (tùy chọn)
  role_ids: string[]; // Danh sách các ID vai trò được gán (tùy chọn)
}
```

### Response Formats
#### Success Response (`200 OK`)
```json
{
  "message": "MSG_SUCCESS",
  "data": {
    "id": "64cb1c34a2df43a908be5812" // ID nhân viên mới tạo
  },
  "error_code": ""
}
```

#### Validation Error (`400 Bad Request`)
```json
{
  "message": "ERR_VALIDATION_FAILED",
  "data": [
    {
      "field": "email",
      "error": "email is a required field"
    }
  ],
  "error_code": "ERR_VALIDATION_FAILED"
}
```

---

## 3. Activate User API

Kích hoạt tài khoản nhân viên và đổi trạng thái sang `ACTIVE`. Đây là Public API được gọi từ trang xác nhận email.

- **Endpoint:** `POST /api/v1/user/activate`
- **Requires Auth:** No (Public API)
- **Headers:**
  - `Content-Type: application/json`

### Request Body (`ActivateUserRequest`)
```typescript
interface ActivateUserRequest {
  token: string; // Token kích hoạt gửi qua email
}
```

### Response Formats
#### Success Response (`200 OK`)
```json
{
  "message": "MSG_SUCCESS",
  "data": null,
  "error_code": ""
}
```

#### Invalid/Expired Token (`400 Bad Request`)
```json
{
  "message": "token is invalid or expired",
  "data": null,
  "error_code": "ERR_BAD_REQUEST"
}
```

---

## 4. List Users API

Lấy danh sách nhân viên có phân trang, tìm kiếm và phân quyền dữ liệu tự động.

- **Endpoint:** `POST /api/v1/user/list`
- **Requires Auth:** Yes (Bearer Token)
- **Permissions:** `USER_VIEW`
- **Headers:**
  - `Authorization: Bearer <access_token>`
  - `Content-Type: application/json`

### Request Body (`ListUsersRequest`)
Kế thừa cấu trúc `CommonQuery` chuẩn của hệ thống:
```typescript
interface ListUsersRequest {
  page?: number;     // Số trang (mặc định: 1)
  size?: number;     // Số phần tử mỗi trang (mặc định: 10)
  keyword?: string;  // Từ khóa tìm kiếm theo tên, email, phone (tùy chọn)
  status?: string;   // Lọc theo trạng thái "ACTIVE" | "INACTIVE" (tùy chọn)
}
```

### Response Formats
#### Success Response (`200 OK`)
```json
{
  "message": "MSG_SUCCESS",
  "data": {
    "items": [
      {
        "id": "64cb1c34a2df43a908be5812",
        "email": "employee@tenant.com",
        "name": "Nguyen Van A",
        "phone": "0987654321",
        "is_owner": false,
        "status": "ACTIVE",
        "role_ids": ["64cb1b21a2df43a908be57ff"],
        "owner_id": "64cb1a11a2df43a908be57ee" // ID người quản lý trực tiếp
      }
    ],
    "total": 1,
    "page": 1,
    "size": 10
  },
  "error_code": ""
}
```

---

## 5. List All Users API (Dropdown Selection)

Lấy danh sách rút gọn toàn bộ nhân viên được quyền truy cập để phục vụ cho các trường Dropdown hiển thị trên UI.

- **Endpoint:** `POST /api/v1/user/list-all`
- **Requires Auth:** Yes (Bearer Token)
- **Permissions:** `USER_VIEW`
- **Headers:**
  - `Authorization: Bearer <access_token>`
  - `Content-Type: application/json`

### Response Formats
#### Success Response (`200 OK`)
```json
{
  "message": "MSG_SUCCESS",
  "data": [
    {
      "id": "64cb1c34a2df43a908be5812",
      "name": "Nguyen Van A",
      "email": "employee@tenant.com"
    }
  ],
  "error_code": ""
}
```

---

*(Tài liệu này được duy trì trong thư mục `.agents/integration/USER_FLOW.md` phục vụ các Agent và Client tích hợp).*
