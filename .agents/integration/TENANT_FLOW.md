# Tenant Management Integration Flow

Tài liệu hướng dẫn quy trình tích hợp các API quản lý Tenant (doanh nghiệp/tổ chức) cho Frontend và Mobile Client.

---

## 1. Overview & Security Rules

1. **Owner-Only Control**: API Cập nhật thông tin Tenant chỉ áp dụng cho người dùng có quyền **Owner** (`is_owner == true`).
2. **ClientType Isolation**: Phải truyền Bearer Token phát hành cho **User Client / Mobile App** (`client_type == "USER"` hoặc `"MOBILE"`). Nếu truyền Token Admin sẽ bị từ chối với mã lỗi `403 Forbidden` (`ERR_FORBIDDEN: token client type mismatch`).
3. **Model-Driven Optional Update**: Tất cả các trường dữ liệu đều là con trỏ string (`*string`). Chỉ cập nhật những trường thực sự được truyền lên và có sự thay đổi.

---

## 2. Update Tenant Information API

- **Endpoint:** `POST /api/v1/tenant/update-info`
- **Requires Auth:** Yes (`Authorization: Bearer <jwt_access_token>`)
- **Headers:**
  - `Authorization: Bearer <access_token>`
  - `Content-Type: application/json`

### Request Body (`UpdateTenantRequest`)

Tất cả các trường đều là **optional**:

```typescript
interface UpdateTenantRequest {
  name?: string;         // Tên hiển thị mới của doanh nghiệp (VD: "Sowfkun Corporation")
  phone_number?: string; // Số điện thoại mới của doanh nghiệp (VD: "0987654321")
  language?: string;     // Ngôn ngữ mặc định ("vi" | "en")
}
```

### Response Formats

#### Success Response (`200 OK`)
```json
{
  "message": "Cập nhật thành công",
  "data": null,
  "error_code": ""
}
```

#### Forbidden Response (`403 Forbidden`) - Không phải Owner hoặc Dùng sai ClientType Token
```json
{
  "message": "Forbidden: only owner can update tenant info",
  "data": null,
  "error_code": "ERR_FORBIDDEN"
}
```

#### Unauthorized Response (`401 Unauthorized`) - Thiếu hoặc Token không hợp lệ
```json
{
  "message": "ERR_UNAUTHORIZED",
  "data": null,
  "error_code": "ERR_UNAUTHORIZED"
}
```

---

*(Tài liệu này được duy trì trong thư mục `.agents/integration/TENANT_FLOW.md` phục vụ các Agent và Client tích hợp).*
