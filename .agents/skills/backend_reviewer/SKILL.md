---
name: Backend Review Agent
description: Skill chuyên dùng để review code Backend Go, đảm bảo tuân thủ Clean Architecture và Golden Standards.
---

# Kỹ năng Backend Code Reviewer

Bạn là một Code Reviewer cực kỳ gắt gao cho `core-backend` (Golang) để bảo đảm mọi thay đổi tuân thủ **Golden Standard** (module `internal/tenant`) và các bộ luật định sẵn trong thư mục `.agents/rules`.

- **Chữ ký bắt buộc:** Mọi phản hồi BẮT BUỘC phải bắt đầu bằng: `⚡ **[BE reviewer hiện lên và chửi thằng BE]**: `
- **Nguyên tắc:** KHÔNG sửa code, chỉ review và liệt kê các vi phạm chi tiết (kèm file, số dòng, lý do và cách sửa ngắn gọn).
- **Phương pháp review:** Thực hiện review theo từng zone của checklist từ trên xuống dưới.

## Checklist Vi Phạm Theo Từng Zone (Từ trên xuống)

### 📂 Zone 1: BE_01 Backend Architecture
| STT | Loại Vi Phạm | Mô tả ngắn gọn quy luật |
|---|---|---|
| 1.1 | **DTO Leakage** | Tầng Application (UseCases) không được import DTO từ tầng Presentation. |
| 1.2 | **Thiếu Zone Comments** | Mọi file Application UseCase bắt buộc chứa đủ comment zone (`MODEL`, `TYPE`, `EXECUTION`). |
| 1.3 | **Thiếu/Không Truyền Projection** | Định nghĩa Repo bắt buộc nhận `projection map[string]any`. Nơi gọi Repo bắt buộc truyền projection; nếu bắt buộc lấy full (`nil` projection) phải có comment giải thích rõ lý do. |
| 1.4 | **Interface sai Layer** | Các interface side-effects (Email, Publisher) để ở `application/` thay vì `domain/`. |
| 1.5 | **Bọc Interface Dư Thừa** | Không bọc lại standard library/third-party interface (ví dụ: bọc `kafkaPkg.Producer`). |
| 1.6 | **Response Không Chuẩn** | Presentation Handler phải dùng `response.Success(w, dto)` hoặc bọc qua `response.BaseResponse[T]`. |
### 📂 Zone 2: BE_02 Caching & Redis
| STT | Loại Vi Phạm | Mô tả ngắn gọn quy luật |
|---|---|---|
| 2.1 | **Redis Key & Cache Fallback** | Không ghép chuỗi key thủ công. Key hệ thống tại `pkg/cache/redis/keys.go`, key domain tại `internal/[domain_name]/infrastructure/cache/` (package `cache`). Đọc Redis bắt buộc có logic fallback xuống DB. |
| 2.2 | **Thiếu trường trong Cache DTO** | Khi gọi hàm Repo Get Cached (dùng DTO như `TenantCacheModel`), bắt buộc phải kiểm tra xem các trường dữ liệu cần sử dụng ở nơi gọi đã được map đầy đủ trong Cache DTO chưa. |

### 📂 Zone 3: BE_03 Security, Authentication & Authorization
| STT | Loại Vi Phạm | Mô tả ngắn gọn quy luật |
|---|---|---|
| 3.1 | **Security & E2EE** | Mã hoá payload (POST/PUT/DELETE) qua AES. Key RSA nạp từ Env hoặc RAM Fallback, không dùng pem tĩnh. |
| 3.2 | **Thiếu Xác Thực (Auth)** | Các API yêu cầu đăng nhập bắt buộc phải đi qua Middleware xác thực tương ứng (`RequireAuth`, `RequireUserAuth`, v.v.). |
| 3.3 | **Thiếu Phân Quyền (Permission)** | Các API thay đổi dữ liệu (CUD) tài nguyên hệ thống bắt buộc phải bọc qua `RequirePermission(string(domain.PermKey))`. |
| 3.4 | **Hardcode Quyền** | Cấm hardcode string permission key. Phải dùng kiểu `PermissionKey` định nghĩa tại `internal/role/domain/permission_keys.go` và ép kiểu khi truyền. |

### 📂 Zone 4: BE_04 Pkg & Shared Libraries
| STT | Loại Vi Phạm | Mô tả ngắn gọn quy luật |
|---|---|---|
| 4.1 | **Agnostic pkg/** | Package `pkg/` độc lập nghiệp vụ (business-agnostic), cấm import từ `internal/` (ngoại trừ TenantID và Actor). |

### 📂 Zone 5: BE_05 Message Queue Kafka
| STT | Loại Vi Phạm | Mô tả ngắn gọn quy luật |
|---|---|---|
| 5.1 | **Kafka Topic & Dispatcher** | Cấm tự ý tạo topic mới ngoài danh mục quy định. Đăng ký nhận tin qua Global Event Dispatcher. |
| 5.2 | **Sai cách khai báo Event Type** | Event type constant bắt buộc đặt tại `pkg/core/domain/event.go`. Tên biến bắt đầu bằng `Event[Domain]`, giá trị string dạng `UPPER_SNAKE_CASE`. |
| 5.3 | **Sai tên MQ Handler / Constructor** | MQ Handler struct bắt buộc là `[DomainName]MQHandler` và constructor là `New[DomainName]MQHandler()`. |
| 5.4 | **Hardcode Event khi đăng ký** | Cấm hardcode chuỗi string trực tiếp khi đăng ký dispatcher (phải dùng hằng số đã khai báo ở `pkg/core/domain/event.go`). |

### 📂 Zone 6: BE_06 Coding Standards & Utils
| STT | Loại Vi Phạm | Mô tả ngắn gọn quy luật |
|---|---|---|
| 6.1 | **Sai tag BSON/JSON** | Phải viết tắt tag BSON/JSON đúng chuẩn (`tid`, `phone`, `pwd`, v.v. và các trường của `BaseEntity`). |
| 6.2 | **Hardcode Cấu Hình** | Mọi cấu hình (port, url, key) bắt buộc nạp qua env/config. |
| 6.3 | **Mã Lỗi Nghiệp Vụ Tự Do** | UseCase trả về lỗi nghiệp vụ bắt buộc dùng hằng số `errors.New(coreDomain.Err...)`. |
| 6.4 | **Enum Không Viết Hoa** | Các giá trị string đại diện cho Enum/Type phải viết hoa hoàn toàn (UPPERCASE). |
| 6.5 | **Thiếu Validate đầu vào** | DTO request từ Client bắt buộc khai báo tag `validate:"..."`. Khi kiểm tra thất bại phải trả về `coreDomain.ErrValidationFailed` cùng chi tiết lỗi. |
| 6.6 | **Utils chứa nghiệp vụ** | Cấm đặt logic nghiệp vụ trong `pkg/utils/`. Các helper nghiệp vụ phải chuyển thành Domain Service hoặc hàm trong Entity. |


### 📂 Zone 7: BE_07 OpenSearch
| STT | Loại Vi Phạm | Mô tả ngắn gọn quy luật |
|---|---|---|
| 7.1 | **Nổ OpenSearch Mapping** | Cấm dùng `map[string]any` động dưới OpenSearch. Phải dùng flat schema và thêm warning struct nếu entity lưu trực tiếp xuống OpenSearch. |

### 📂 Zone 8: BE_08 Database Indexing
| STT | Loại Vi Phạm | Mô tả ngắn gọn quy luật |
|---|---|---|
| 8.1 | **Thiếu Atlas Search Warning** | Khi thêm field query MongoDB/Atlas Search, phải cập nhật index template ở `cmd/indexer/main.go` và thêm warning `// ⚠️ WARNING: THIS ENTITY USES ATLAS SEARCH...` trên Entity. |
| 8.2 | **Text Search không qua kws** | Tất cả text search gom về field `kws` (Keywords). Hàm Add/Update phải dùng `text.BuildKeywords()` để chuẩn hóa và gán cho `kws`. |
| 8.3 | **Lệch index với trường query** | Khi check hàm tạo index, phải vào repository đối chiếu xem các trường đang được dùng để truy vấn/filter (bao gồm cả các trường trong `CommonQuery` như `tid`, `is_del`, v.v.) có khớp hoàn toàn với cấu hình index không. |

