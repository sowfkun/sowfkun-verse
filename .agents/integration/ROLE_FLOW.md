# Role & Permission Integration Flow

Tài liệu hướng dẫn quy trình tích hợp các API quản lý Vai trò (Role) và Phân quyền (Permission) trong hệ thống dành cho Frontend và Mobile Client.

---

## 1. Overview & Security Rules

1. **Role-Based Access Control (RBAC)**: Hệ thống sử dụng cơ chế kiểm tra quyền hạn dựa theo mã quyền (`PermissionKey`) và phạm vi quyền (`PermissionScope`).
2. **CUD Operation Protection**: Các API tạo mới (`add`), cập nhật (`update`) và xóa (`delete`) vai trò là API Quản trị Lõi. Các API này bắt buộc phải đi kèm JWT Token hợp lệ và tài khoản thực thi phải có quyền quản trị cấu hình hệ thống: **`CONFIG_MANAGE`** (hoặc tài khoản là Owner của Tenant: `is_owner == true`).
3. **Read Operation Accessibility**: Các API xem thông tin (`get`, `list`) chỉ cần xác thực người dùng đã đăng nhập (`RequireAuth`), không yêu cầu mã quyền đặc biệt để cho phép các Client "Get để Show" nhanh chóng.
4. **Chuẩn hóa Enum**: Tất cả các giá trị string biểu thị quyền và phạm vi đều bắt buộc viết hoa toàn bộ (**UPPERCASE**).

---

## 2. Models & Data Structures

Khi làm việc với Role API, Client cần hiểu rõ cấu trúc dữ liệu sau:

### 2.1. Permission Key (Mã Quyền)
Là string định danh duy nhất cho từng hành động trong hệ thống.
- `CONFIG_MANAGE` (Quản lý cấu hình hệ thống: Tag, Role, Tenant, Attribute)
- `CUSTOMER_VIEW` (Xem thông tin khách hàng)
- `CUSTOMER_CREATE` (Tạo mới khách hàng)
- `CUSTOMER_UPDATE` (Cập nhật thông tin khách hàng)
- `CUSTOMER_DELETE` (Xóa khách hàng)

### 2.2. Permission Scope (Phạm Vi)
Là string xác định phạm vi dữ liệu được phép áp dụng quyền:
- `ALL`: Toàn quyền trên mọi dữ liệu thuộc Tenant.
- `SUBORDINATES`: Chỉ áp dụng trên dữ liệu thuộc cấp dưới quản lý.
- `SAME_DEPT`: Chỉ áp dụng trên dữ liệu thuộc cùng phòng ban/bộ phận.
- `OWN_ONLY`: Chỉ áp dụng trên dữ liệu do chính tài khoản tạo ra hoặc sở hữu.

---

## 3. API Specifications

### 3.1. Add Role (Thêm vai trò)

- **Endpoint:** `POST /api/v1/role/add`
- **Requires Auth:** Yes
- **Requires Permission:** `CONFIG_MANAGE` (hoặc `is_owner == true`)

#### Request Body (`CreateRoleRequest`)
```typescript
interface CreateRoleRequest {
  name: string;        // Tên vai trò (VD: "Trưởng phòng Kinh doanh") - validate: required, max=50
  desc?: string;       // Mô tả chi tiết vai trò - validate: max=255
  perms: Record<string, string[]>; // Map chứa mã quyền và danh sách phạm vi áp dụng
}
```
*Ví dụ payload:*
```json
{
  "name": "Trưởng phòng Kinh doanh",
  "desc": "Quản lý kinh doanh khu vực miền Nam",
  "perms": {
    "CUSTOMER_VIEW": ["SAME_DEPT", "SUBORDINATES"],
    "CUSTOMER_CREATE": ["ALL"],
    "CUSTOMER_UPDATE": ["OWN_ONLY"]
  }
}
```

#### Success Response (`200 OK`)
```json
{
  "message": "MSG_SUCCESS",
  "data": {
    "id": "64d0bc7df8a4d2e5a1b8c09a"
  },
  "error_code": ""
}
```

---

### 3.2. Update Role (Cập nhật vai trò)

- **Endpoint:** `POST /api/v1/role/update`
- **Requires Auth:** Yes
- **Requires Permission:** `CONFIG_MANAGE` (hoặc `is_owner == true`)

#### Request Body (`UpdateRoleRequest`)
```typescript
interface UpdateRoleRequest {
  id: string;          // ID của vai trò cần cập nhật - validate: required
  name?: string;       // Tên vai trò mới (optional) - validate: max=50
  desc?: string;       // Mô tả mới (optional) - validate: max=255
  perms?: Record<string, string[]>; // Bản đồ quyền mới (optional)
}
```

#### Success Response (`200 OK`)
```json
{
  "message": "MSG_SUCCESS",
  "data": null,
  "error_code": ""
}
```

---

### 3.3. Delete Roles (Xóa vai trò)

Hỗ trợ xóa một hoặc nhiều vai trò cùng lúc bằng ID hoặc các tiêu chí bộ lọc.

- **Endpoint:** `POST /api/v1/role/delete`
- **Requires Auth:** Yes
- **Requires Permission:** `CONFIG_MANAGE` (hoặc `is_owner == true`)

#### Request Body (`DeleteRolesRequest`)
```typescript
interface DeleteRolesRequest {
  include_ids?: string[]; // Danh sách các ID vai trò muốn xóa (CommonQuery.include_ids)
  // Có thể bổ sung các tiêu chí filter khác từ CommonQuery để xóa hàng loạt
}
```

#### Success Response (`200 OK`)
```json
{
  "message": "MSG_SUCCESS",
  "data": null,
  "error_code": ""
}
```

---

### 3.4. Get Role Detail (Lấy chi tiết vai trò)

- **Endpoint:** `GET /api/v1/role/get`
- **Requires Auth:** Yes (Không yêu cầu Permission cụ thể)
- **Query Parameters:**
  - `id` (string, required): ID của vai trò cần lấy.
  - `projection` (string, optional): Danh sách các trường muốn lấy, phân cách bằng dấu phẩy (VD: `name,perms`).

#### Success Response (`200 OK`)
```json
{
  "message": "MSG_SUCCESS",
  "data": {
    "id": "64d0bc7df8a4d2e5a1b8c09a",
    "name": "Trưởng phòng Kinh doanh",
    "desc": "Quản lý kinh doanh khu vực miền Nam",
    "perms": {
      "CUSTOMER_VIEW": ["SAME_DEPT", "SUBORDINATES"],
      "CUSTOMER_CREATE": ["ALL"],
      "CUSTOMER_UPDATE": ["OWN_ONLY"]
    }
  },
  "error_code": ""
}
```

---

### 3.5. List Roles (Danh sách vai trò)

- **Endpoint:** `POST /api/v1/role/list`
- **Requires Auth:** Yes (Không yêu cầu Permission cụ thể)

#### Request Body (`ListRolesRequest`)
```typescript
interface ListRolesRequest {
  page?: number;               // Trang hiện tại (mặc định: 1)
  size?: number;               // Số lượng trên mỗi trang (mặc định: 10, tối đa: 100)
  keyword?: string;            // Từ khóa tìm kiếm theo tên vai trò (Atlas Search)
  include_ids?: string[];      // Danh sách các ID vai trò bắt buộc chứa
  exclude_ids?: string[];      // Danh sách các ID vai trò cần loại bỏ
  projection?: Record<string, number>; // Các trường dữ liệu muốn lấy (VD: {"name": 1, "desc": 1})
  sort?: Record<string, number>; // Hướng sắp xếp (VD: {"name": 1, "c_at": -1})
}
```

#### Success Response (`200 OK`)
```json
{
  "message": "MSG_SUCCESS",
  "data": [
    {
      "id": "64d0bc7df8a4d2e5a1b8c09a",
      "name": "Trưởng phòng Kinh doanh",
      "desc": "Quản lý kinh doanh khu vực miền Nam",
      "perms": {
        "CUSTOMER_VIEW": ["SAME_DEPT", "SUBORDINATES"]
      }
    }
  ],
  "error_code": ""
}
```

---

*(Tài liệu này được duy trì tại thư mục `.agents/integration/ROLE_FLOW.md` nhằm phục vụ việc tích hợp hệ thống phân quyền của các Agent và các Client).*
