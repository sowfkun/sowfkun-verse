# Tag Management Integration Flow

Tài liệu hướng dẫn quy trình tích hợp các API quản lý Tag phân loại (Nhãn) cho Frontend và Mobile Client.

---

## 1. Overview

Tag được sử dụng để phân loại các thực thể trong hệ thống (như `CUSTOMER`). 
- **Quyền hạn**: Thao tác thêm, sửa, xóa tag yêu cầu quyền tương ứng theo phân hệ hoặc được phân quyền cấu hình.
- **Color**: Định dạng mã màu Hex (Ví dụ: `#FF0000`).

---

## 2. API Endpoints

### 2.1. Add Tag (Tạo mới tag)

- **Endpoint:** `POST /api/v1/tag/add`
- **Headers:**
  - `Authorization: Bearer <jwt_access_token>`
  - `Content-Type: application/json`

#### Request Body
```typescript
interface CreateTagRequest {
  module: string;       // Phân hệ áp dụng ("CUSTOMER" | "TICKET")
  name: string;         // Tên tag (Ví dụ: "VIP", tối đa 50 ký tự)
  desc?: string;        // Mô tả tag (tối đa 255 ký tự)
  color: string;        // Mã màu Hex (Ví dụ: "#FF0000")
}
```

#### Response Success (`200 OK`)
```json
{
  "message": "success",
  "data": {
    "id": "60d5ecb..."  // ID của tag vừa tạo
  },
  "error_code": ""
}
```

---

### 2.2. Update Tag (Cập nhật tag)

- **Endpoint:** `POST /api/v1/tag/update`

#### Request Body
```typescript
interface UpdateTagRequest {
  id: string;           // ID của tag cần sửa
  name?: string;        // Tên tag mới
  desc?: string;        // Mô tả mới
  color?: string;       // Mã màu Hex mới
}
```

#### Response Success (`200 OK`)
```json
{
  "message": "success",
  "data": null,
  "error_code": ""
}
```

---

### 2.3. Delete Tags (Xóa hàng loạt tag)

- **Endpoint:** `POST /api/v1/tag/delete`

> [!NOTE]
> Hành động này thực hiện soft delete (hủy kích hoạt tag).

#### Request Body
```typescript
interface DeleteTagsRequest {
  include_ids?: string[]; // Danh sách ID tag cần xóa (CommonQuery.include_ids)
  modules?: string[];     // Phân hệ lọc xóa để xóa toàn bộ tag thuộc phân hệ
}
```

#### Response Success (`200 OK`)
```json
{
  "message": "success",
  "data": null,
  "error_code": ""
}
```

---

### 2.4. List Tags (Lấy danh sách tag phân trang)

- **Endpoint:** `POST /api/v1/tag/list`

#### Request Body
```typescript
interface ListTagsRequest {
  page?: number;               // Trang hiện tại (mặc định 1)
  size?: number;               // Số lượng trên mỗi trang (mặc định 10, tối đa 100)
  keyword?: string;            // Từ khóa tìm kiếm (Atlas Search)
  modules?: string[];          // Phân hệ lọc danh sách (Ví dụ: ["CUSTOMER"])
  is_deleted?: boolean;        // Lọc theo trạng thái xóa
  include_ids?: string[];      // Danh sách ID bắt buộc chứa
  exclude_ids?: string[];      // Danh sách ID cần loại trừ
  projection?: Record<string, number>; // Map các field cần lấy (Ví dụ: {"name": 1, "color": 1})
  sort?: Record<string, number>; // Map sắp xếp (Ví dụ: {"name": 1, "c_at": -1})
}
```

#### Response Success (`200 OK`)
```json
{
  "message": "success",
  "data": {
    "items": [
      {
        "id": "60d5ecb...",
        "name": "VIP",
        "desc": "Very Important Person",
        "color": "#FF0000",
        "modules": ["CUSTOMER"]
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

*(Tài liệu này được duy trì trong thư mục `.agents/integration/TAG_FLOW.md` phục vụ các Agent và Client tích hợp).*
