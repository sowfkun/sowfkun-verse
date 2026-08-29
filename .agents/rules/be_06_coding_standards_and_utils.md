---
trigger: always_on
---

# 06. Coding Standards & Utils

## 1. Tiêu chuẩn Code & Đặt tên (Coding Standards & Naming Conventions)
- **Idiomatic Go**: Tuân thủ chuẩn định dạng `gofmt`. Sử dụng `camelCase` cho biến/hàm nội bộ, `PascalCase` cho public.
- **Ubiquitous Language**: Tên biến, tên hàm, tên struct phải phản ánh đúng thuật ngữ nghiệp vụ (Ubiquitous Language) của DDD. Tên hàm nên bắt đầu bằng động từ hành động (VD: `PlaceOrder`, `CancelSubscription`).
- **Error Handling**: Xử lý lỗi tường minh, gói lỗi (wrap errors). Tuyệt đối không lạm dụng `panic()`.
- **Concurrency**: Sử dụng goroutines/channels an toàn, có cơ chế timeout/cancellation qua `context.Context`.

## 2. Quản lý Constants, Cấu hình & Utils
- **Cấu hình & Biến môi trường (Environment Variables)**: Tuyệt đối **không được hardcode** các thông tin kết nối (Connection URLs, Port), thông tin nhạy cảm (API Keys, Secrets, Passwords) trong source code. Bắt buộc phải inject thông qua biến môi trường (`.env`, env vars) hoặc các trình quản lý config (VD: `Viper`).
  - **Đồng bộ đặt tên (Naming Consistency):** Khi khai báo các biến môi trường cho cùng một hệ thống hạ tầng (Infrastructure) cụ thể, bắt buộc phải đồng bộ prefix/suffix theo mục đích sử dụng. Ví dụ: Nếu là Redis dùng cho "general", các biến phải được đặt tên đồng nhất như `REDIS_GENERAL_URL`. Tuyệt đối không đặt tên lộn xộn, thiếu tính liên kết.
  - **Chuẩn hóa Giá trị 1 Dòng (Single-line .env Values):** Tuyệt đối **KHÔNG** để các giá trị đa dòng (multi-line) như RSA Key, Private Key, Certificate ngắt dòng trực tiếp trong file `.env` vì Docker Compose và trình nạp biến môi trường sẽ bị lỗi cắt cụt chuỗi hoặc lỗi cú pháp (`unexpected character`). Mọi giá trị Key/Certificate trong `.env` **BẮT BUỘC** phải được mã hóa thành chuỗi Base64 trên **1 dòng duy nhất** (Single-line Compact Base64).
- **Constants (Hằng số tĩnh)**:
  - Domain-specific (ví dụ: Enum trạng thái đơn hàng): Đặt ngay bên trong package của lớp `Domain` tương ứng.
  - System-wide (ví dụ: HTTP Status Codes đặc chế, mã lỗi chung): Đặt tại `pkg/constant/`.
- **Utils (Hàm tiện ích)**:
  - Logic không chứa nghiệp vụ: Gom vào thư mục `pkg/utils/...`.
  - Logic liên quan tới nghiệp vụ nội bộ: Chuyển thành **Domain Service** hoặc hàm trong Entity. Không đặt ở Utils.

## 3. Đặt Tên Field trong Entity (BSON/JSON Tag Abbreviation)

> **Triết lý**: Viết tắt khi nó **tiết kiệm thực sự** và **không làm mờ nghĩa**. Giữ nguyên khi viết tắt chỉ gây khó đọc mà không mang lại lợi ích đáng kể. Readability > Storage optimization ở scale vừa.

- **Nguyên tắc chung**: Go struct field giữ tên đầy đủ (readable). Rút gọn trong `bson:""` và `json:""` tag theo **3 tầng ưu tiên** dưới đây.

---

### Tầng 1 — BẮT BUỘC viết tắt (Cross-cutting IDs + Universally recognized)

Những field này xuất hiện ở **mọi collection**, tiết kiệm storage thực sự và đã là convention phổ biến trên thế giới.

| Field Name (Go) | bson/json tag | Lý do |
|---|---|---|
| `TenantID` | `bson:"tid"` | Cross-cutting, xuất hiện mọi collection |
| `UserID` | `bson:"uid"` | Cross-cutting, convention phổ biến |
| `PhoneNumber` | `bson:"phone"` | Convention quốc tế (`phone` là đủ rõ) |
| `Description` | `bson:"desc"` | Convention SQL/NoSQL phổ biến |
| `Quantity` | `bson:"qty"` | Convention inventory/e-commerce |
| `Metadata` | `bson:"meta"` | Convention phổ biến (HTML meta, API meta) |
| `Configuration` | `bson:"cfg"` | Convention phổ biến trong config systems |
| `Permissions` | `bson:"perms"` | Convention phổ biến trong auth systems |
| `Organization` | `bson:"org"` | Convention phổ biến (GitHub org, LDAP org) |
| `Department` | `bson:"dept"` | Convention phổ biến trong HR systems |
| `Thumbnail` | `bson:"thumb"` | Convention phổ biến trong media systems |
| `Category` | `bson:"cat"` | Convention phổ biến trong e-commerce |
| `TemplateID` | `bson:"tmpl_id"` | Rõ nghĩa, không quá ngắn |

---

### Tầng 2 — NÊN viết tắt (Rõ nghĩa + Tiết kiệm vừa phải)

Viết tắt được, nhưng phải **comment inline** để tránh nhầm lẫn.

| Field Name (Go) | bson/json tag | Ghi chú |
|---|---|---|
| `Password` | `bson:"pwd"` | `pwd` là convention Linux/Unix phổ biến |
| `Address` | `bson:"addr"` | `addr` là convention networking phổ biến |
| `Language` | `bson:"lang"` | `lang` là convention HTTP/HTML (`Accept-Language`) |
| `Timestamp` | `bson:"ts"` | `ts` là convention logging/time-series |
| `ExpiresAt` | `bson:"exp_at"` | `exp` là convention JWT (`exp` claim) |

---

### Tầng 3 — GIỮ NGUYÊN (Không viết tắt)

Những field này nếu viết tắt sẽ **mất ngữ nghĩa** hoặc **dễ gây nhầm lẫn**.

| Field Name (Go) | bson/json tag | Lý do KHÔNG viết tắt |
|---|---|---|
| `Subject` | `bson:"subject"` | `subj` không phải convention phổ biến |
| `BodyHTML` | `bson:"body_html"` | `body` mất context (HTML? Text? Request body?) |
| `IsOwner` | `bson:"is_owner"` | Boolean flag domain-specific, giữ nguyên cho rõ |

> **Lưu ý về BaseEntity**: Các field trong `BaseEntity` đã được cập nhật theo convention ngắn:
> `c_at` (created_date) | `u_at` (last_updated_date) | `is_del` (is_deleted) | `c_by` (created_by) | `u_by` (last_updated_by) | `exp_ref` (expired_ref) | `kws` (keywords)

---

### Ví dụ entity chuẩn

```go
type User struct {
    coreDomain.BaseEntity `bson:",inline"`
    TenantID    string     `bson:"tid" json:"tid"`                  // tenant_id → tid (Tầng 1)
    Email       string     `bson:"email" json:"email"`              // ngắn sẵn, giữ nguyên
    Password    string     `bson:"pwd" json:"-"`                    // password → pwd (Tầng 2)
    Name        string     `bson:"name" json:"name"`               // ngắn sẵn, giữ nguyên
    PhoneNumber string     `bson:"phone" json:"phone"`             // phone_number → phone (Tầng 1)
    IsOwner     bool       `bson:"is_owner" json:"is_owner"`       // Boolean flag, giữ nguyên (Tầng 3)
    Status      UserStatus `bson:"status" json:"status"`           // ngắn sẵn, giữ nguyên
}
```

- **Đối với field chưa có trong bảng**: Tra cứu convention phổ biến trong ngành trước. Nếu không có, giữ tên đầy đủ và comment lý do.

---

### 3.1. Đồng bộ Tag BSON/JSON giữa Entity, DTO và Event Change (Change Stream Synchronization)

> **LUẬT THÉP**: Khi thêm mới hoặc sửa đổi tên field/tag trong Entity (`bson:"..." json:"..."`), **BẮT BUỘC** phải đối chiếu và đồng bộ tag đó xuyên suốt toàn bộ hệ thống:
> 1. **Entity**: `bson:"<tag>" json:"<tag>"` (ví dụ: `bson:"tz" json:"tz"`).
> 2. **Cache DTO / Cache Model**: `json:"<tag>"` (ví dụ: `TenantCacheModel` trường `Timezone` có tag `json:"tz"`).
> 3. **Response DTO**: `json:"<tag>"` (ví dụ: `TenantResponse`, `UserBriefResponse` có tag `json:"tz"`).
> 4. **Request DTO / Command**: `json:"<tag>,omitempty"`.

**Lý do sống còn:**
- MongoDB Change Stream khi phát hiện update sẽ gửi payload chứa danh sách các BSON key bị thay đổi (ví dụ: `tz`, `phone`, `status`, `meta`).
- Các MQ Handler (`TenantMQHandler`, `UserMQHandler`, `RoleMQHandler`, v.v.) sử dụng `reflection.GetStructTags` trên DTO/CacheModel để trích xuất danh sách key cần theo dõi.
- Nếu tên tag trong Response DTO/Cache Model bị lệch so với Entity BSON key (ví dụ: Entity là `tz` nhưng DTO lại đặt là `timezone`), hàm `reflection.HasFieldIntersection` sẽ **bị miss và không khớp key**, dẫn tới:
  - ❌ **Không xóa cache Redis** (dữ liệu cache bị stale/lỗi thời).
  - ❌ **Không bắn WebSocket `ENTITY_CHANGED`** xuống Frontend (Client không nhận được cập nhật realtime).

---

## 4. Chuẩn hóa Enum & Const Values (UPPERCASE)
- **BẮT BUỘC viết hoa toàn bộ (UPPERCASE)** đối với tất cả các giá trị string đại diện cho các trường kiểu Enum/Type (ví dụ: `Status`, `Type`, `Role`, `Module`, v.v.) trong cả mã nguồn Go và khi lưu trữ xuống Database MongoDB.
- **Quy ước**: `ACTIVE`, `INACTIVE`, `CUSTOMER`, `TICKET`, `USER`, `ADMIN`.
- Tránh việc đặt giá trị hỗn hợp chữ hoa, chữ thường hoặc kiểu CamelCase cho giá trị Enum thực tế để đảm bảo tính nhất quán trên toàn bộ hệ thống (ngoại trừ các chuẩn quốc tế bắt buộc viết thường như mã ngôn ngữ ISO `"vi"`, `"en"`).

---

## 5. Input Validation (Kiểm tra dữ liệu đầu vào)
- **BẮT BUỘC** phải validate toàn bộ dữ liệu từ Client gửi lên (qua REST API, gRPC, MQ, v.v.).
- Sử dụng thư viện `github.com/go-playground/validator/v10` thông qua wrapper `pkg/utils/validator`.
- Khai báo các rule validate trực tiếp bằng struct tag `validate:"..."` trong các DTO / Request model (ví dụ: `validate:"required,max=100,email"`).
- Khi gọi `validator.Validate(req)` trong Handler, nếu có lỗi phải trả về mã lỗi chung `coreDomain.ErrValidationFailed` cùng chi tiết lỗi `err.(validator.ValidationErrors)` thông qua hàm `response.AppErrorWithData` để Client có thể hiển thị thông báo lỗi tương ứng cho từng field.

