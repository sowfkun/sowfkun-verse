# Dynamic Attribute & Zone Integration Flow

Tài liệu hướng dẫn quy trình tích hợp các API quản lý thuộc tính động (Custom Fields) và vùng hiển thị (Zones) cho Frontend và Mobile Client.

---

## 1. Overview

Hệ thống cho phép cấu hình các trường động (custom fields) cho từng phân hệ (Module) như `CUSTOMER`, `TICKET`. 
- **Zones (Vùng hiển thị)**: Gom nhóm các thuộc tính động lại với nhau trên UI.
- **Attributes (Thuộc tính động)**: Mỗi thuộc tính tương ứng với một ô lưu trữ (`slot`) như `t1`..`t50` (text), `n1`..`n50` (number), `d1`..`d50` (datetime), `s1`..`s50` (select).
- **Quyền hạn**: Các API tạo, sửa, xóa thuộc tính và zone yêu cầu quyền **Owner** (`is_owner == true`).

---

## 2. API Endpoints

### 2.1. Get Attribute Set (Lấy danh sách cấu hình của module)

- **Endpoint:** `GET /api/v1/attribute/set`
- **Params:** `module` (Ví dụ: `CUSTOMER`)
- **Headers:** `Authorization: Bearer <jwt_access_token>`

#### Response Success (`200 OK`)
```json
{
  "message": "success",
  "data": {
    "module": "CUSTOMER",
    "zones": {
      "zone_info": {
        "id": "zone_info",
        "label": {
          "vi": "Thông tin cá nhân",
          "en": "Personal Information"
        },
        "order": 1
      }
    },
    "attributes": {
      "t1": {
        "slot": "t1",
        "label": {
          "vi": "Biệt danh",
          "en": "Nickname"
        },
        "data_type": "TEXT_PLAIN",
        "status": "ACTIVE",
        "apply_idx": true,
        "zid": "zone_info"
      }
    }
  },
  "error_code": ""
}
```

---

### 2.2. Add Display Zone (Tạo vùng hiển thị)

- **Endpoint:** `POST /api/v1/attribute/zone/add`
- **Headers:** 
  - `Authorization: Bearer <jwt_access_token>`
  - `Content-Type: application/json`

#### Request Body
```typescript
interface CreateZoneRequest {
  module: string;               // Phân hệ áp dụng ("CUSTOMER" | "TICKET")
  label: {                      // Tên hiển thị đa ngôn ngữ
    vi: string;
    en: string;
  };
  order: number;                // Thứ tự sắp xếp (phải >= 1)
}
```

---

### 2.3. Update Display Zone (Cập nhật vùng hiển thị)

- **Endpoint:** `POST /api/v1/attribute/zone/update`

#### Request Body
```typescript
interface UpdateZoneRequest {
  id: string;                   // ID của Module Attribute Set (lấy từ dữ liệu trả về của Attribute Set)
  zone_id: string;              // Key của zone cần update (Ví dụ: "zone_info")
  label: {
    vi: string;
    en: string;
  };
  order: number;                // Thứ tự sắp xếp mới
}
```

---

### 2.4. Delete Display Zone (Xóa vùng hiển thị)

- **Endpoint:** `POST /api/v1/attribute/zone/delete`

> [!WARNING]
> Chỉ có thể xóa display zone khi zone đó không chứa bất kỳ active attribute nào.

#### Request Body
```typescript
interface DeleteZoneRequest {
  id: string;                   // ID của Module Attribute Set
  zone_id: string;              // Key của zone cần xóa
}
```

---

### 2.5. Add Attribute (Tạo thuộc tính động)

- **Endpoint:** `POST /api/v1/attribute/add`

#### Request Body
```typescript
interface CreateAttributeRequest {
  module: string;               // "CUSTOMER" | "TICKET"
  label: {
    vi: string;
    en: string;
  };
  data_type: "TEXT_PLAIN" | "TEXT_HTML" | "NUMBER" | "SELECT_SINGLE" | "SELECT_MULTI" | "DATETIME";
  apply_index: boolean;         // Đánh chỉ mục tìm kiếm/sắp xếp
  zone_id: string;              // Liên kết đến Display Zone ID
  number_opts?: {               // Bắt buộc nếu data_type = NUMBER (tùy chọn)
    unit: "%" | "VND" | "USD" | "NONE";
    thous_sep: boolean;
  };
  datetime_opts?: {             // Bắt buộc nếu data_type = DATETIME (tùy chọn)
    display_type: "DATE_ONLY" | "TIME_ONLY" | "DATE_TIME";
    format: "dd/MM/yyyy" | "yyyy-MM-dd" | "dd-MM-yyyy" | "HH:mm" | "HH:mm:ss" | "HH:mm dd/MM/yyyy" | "HH:mm:ss dd/MM/yyyy";
  };
  select_opts?: Array<{         // Bắt buộc nếu data_type chứa SELECT (tùy chọn)
    id: string;
    label: {
      vi: string;
      en: string;
    };
  }>;
}
```

---

### 2.6. Update Attribute (Sửa thuộc tính động)

- **Endpoint:** `POST /api/v1/attribute/update`

#### Request Body
```typescript
interface UpdateAttributeRequest {
  id: string;                   // ID của Module Attribute Set
  slot: string;                 // Slot của attribute cần sửa (Ví dụ: "t1")
  label: {
    vi: string;
    en: string;
  };
  zone_id: string;              // ID của display zone mới
  number_opts?: {
    unit: string;
    thous_sep: boolean;
  };
  datetime_opts?: {
    display_type: string;
    format: string;
  };
  select_opts?: Array<{
    id: string;
    label: {
      vi: string;
      en: string;
    };
  }>;
}
```

---

### 2.7. Delete Attribute (Xóa thuộc tính động)

- **Endpoint:** `POST /api/v1/attribute/delete`

> [!NOTE]
> Hành động này thực hiện soft delete (hủy kích hoạt slot thuộc tính động). Dữ liệu cũ đã lưu trên thực thể (Ví dụ: Customer) vẫn giữ nguyên slot, nhưng sẽ không còn render cấu hình này nữa.

#### Request Body
```typescript
interface DeleteAttributeRequest {
  id: string;                   // ID của Module Attribute Set
  slot: string;                 // Slot cần xóa (Ví dụ: "t1")
}
```

---

*(Tài liệu này được duy trì trong thư mục `.agents/integration/ATTRIBUTE_FLOW.md` phục vụ các Agent và Client tích hợp).*
