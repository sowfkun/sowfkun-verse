# 06. Coding Standards & Utils

## 1. Tiêu chuẩn Code & Đặt tên (Coding Standards & Naming Conventions)
- **Idiomatic Go**: Tuân thủ chuẩn định dạng `gofmt`. Sử dụng `camelCase` cho biến/hàm nội bộ, `PascalCase` cho public.
- **Ubiquitous Language**: Tên biến, tên hàm, tên struct phải phản ánh đúng thuật ngữ nghiệp vụ (Ubiquitous Language) của DDD. Tên hàm nên bắt đầu bằng động từ hành động (VD: `PlaceOrder`, `CancelSubscription`).
- **Error Handling**: Xử lý lỗi tường minh, gói lỗi (wrap errors). Tuyệt đối không lạm dụng `panic()`.
- **Concurrency**: Sử dụng goroutines/channels an toàn, có cơ chế timeout/cancellation qua `context.Context`.

## 2. Phân chia Use Case & Tách Hàm (Application Layer)
- **Thiết kế Use Case (Application)**: Không dồn tất cả nghiệp vụ phức tạp vào một Application/UseCase khổng lồ.
  - Ở giai đoạn đầu, nếu chỉ là các thao tác CRUD cơ bản, hệ thống cho phép gom chung vào một Application Service cho gọn.
  - Tuy nhiên, đối với các nghiệp vụ phức tạp hoặc có ngữ cảnh khác nhau (Ví dụ: Việc tạo User có thể đến từ `Register`, `AdminCreate`, hoặc `PublicAPI`), **phải tách riêng** thành các Application/UseCase riêng biệt thay vì dồn chung và dùng `if/else` để kiểm tra role/ngữ cảnh.
- **Quy tắc tách hàm (Function Splitting)**: Không lạm dụng việc tách hàm (over-engineering). **Hạn chế việc tách hàm** đối với những đoạn code chỉ có vài dòng và chỉ được sử dụng duy nhất ở một nơi. Hãy giữ code liền mạch (inline) để tăng tính dễ đọc (readability) và dễ theo dõi luồng thực thi từ trên xuống dưới.

## 3. Quản lý Constants, Cấu hình & Utils
- **Cấu hình & Biến môi trường (Environment Variables)**: Tuyệt đối **không được hardcode** các thông tin kết nối (Connection URLs, Port), thông tin nhạy cảm (API Keys, Secrets, Passwords) trong source code. Bắt buộc phải inject thông qua biến môi trường (`.env`, env vars) hoặc các trình quản lý config (VD: `Viper`).
  - **Đồng bộ đặt tên (Naming Consistency):** Khi khai báo các biến môi trường cho cùng một hệ thống hạ tầng (Infrastructure) cụ thể, bắt buộc phải đồng bộ prefix/suffix theo mục đích sử dụng. Ví dụ: Nếu là Redis dùng cho "general", các biến phải được đặt tên đồng nhất như `REDIS_GENERAL_URL`. Tuyệt đối không đặt tên lộn xộn, thiếu tính liên kết.
- **Constants (Hằng số tĩnh)**:
  - Domain-specific (ví dụ: Enum trạng thái đơn hàng): Đặt ngay bên trong package của lớp `Domain` tương ứng.
  - System-wide (ví dụ: HTTP Status Codes đặc chế, mã lỗi chung): Đặt tại `pkg/constant/`.
- **Utils (Hàm tiện ích)**:
  - Logic không chứa nghiệp vụ: Gom vào thư mục `pkg/utils/...`.
  - Logic liên quan tới nghiệp vụ nội bộ: Chuyển thành **Domain Service** hoặc hàm trong Entity. Không đặt ở Utils.

## 4. Đặt Tên Field trong Entity (BSON/JSON Tag Abbreviation)

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
