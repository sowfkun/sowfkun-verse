# 01. Backend Architecture (Golang)

Đây là các "Luật Thép" về kiến trúc.
**GOLDEN STANDARD**: Module `internal/tenant/` là module chuẩn mực nhất. Mọi module khác BẮT BUỘC phải sao chép chính xác cấu trúc, cách đặt tên, và phân zone từ thư mục này.

---

## 1. Domain Layer (`domain/`)
- **Rule 1.1 - Tách biệt Entity & Interface**: `entity.go` chứa struct kế thừa `BaseEntity`. `repository.go` chỉ định nghĩa Interface, TUYỆT ĐỐI không chứa logic DB.
  - *Tham chiếu:* `internal/tenant/domain/entity.go`

## 2. Application Layer (`application/`)
- **Rule 2.1 - Tách bạch CQRS**: Các UseCase phải chia vào 2 thư mục `commands/` (Write) và `queries/` (Read). Mỗi nghiệp vụ 1 file riêng. Tên hàm UseCase phải thể hiện rõ nghiệp vụ (vd: `ChangeTenantTier` thay vì `Update`).
- **Rule 2.2 - Phân Zone Rõ Ràng**: BẮT BUỘC chia mỗi file thành 3 zone bằng comment.
  - *Ví dụ:*
    ```go
    // ================= MODEL ZONE =================
    type CreateXCommand struct { ... } // DTO
    // ================= TYPE ZONE =================
    type ICreateXUseCase interface { ... }
    type createXUseCase struct { ... }
    // ================= EXECUTION ZONE =================
    func NewCreateXUseCase(...) ICreateXUseCase { ... }
    func (uc *createXUseCase) Execute(...) error { ... }
    ```
- **Rule 2.3 - DTO và Trả về**: 
  - Request DTO bắt buộc nhúng `appDto.CommonCommand` hoặc `appDto.CommonQuery`.
  - TUYỆT ĐỐI KHÔNG trả về thẳng Entity ra Controller, phải dùng Response DTO.
- **Rule 2.4 - Audit Fields**: Dùng `utils.SetCommonEntityData(entity, command)` để set tự động thông tin Audit khi Create/Update.
- **Rule 2.5 - Cấm lạm quyền**: TUYỆT ĐỐI KHÔNG gọi thẳng DB, Cache, ES ở layer này. Phải đi qua Interface của Repo. Xoá (Delete) thì gom list ID truyền xuống Repo.

## 3. Infrastructure Layer (`infrastructure/`)
- **Rule 3.1 - Naming Convention**: Tên file BẮT BUỘC là tên Database engine (Ví dụ: `mongodb_repository.go`, `redis_repository.go`).
- **Rule 3.2 - Phân Zone Repository**: File repository BẮT BUỘC chia 3 zone.
  - *Ví dụ:*
    ```go
    // ================= READ ZONE =================
    // ================= WRITE ZONE =================
    // ================= HELPERS ZONE =================
    ```
- **Rule 3.3 - Đóng gói**: Kế thừa `abstract_repository` nhưng TUYỆT ĐỐI KHÔNG public các hàm nguyên thuỷ ra ngoài.
- **Rule 3.4 - Build Query & Projection**: 
  - Hàm `buildQuery` của mỗi Repository CHỈ nhận duy nhất một tham số là struct Command Query của domain đó (ví dụ: `TenantQuery`, `EmployeeQuery` - struct này BẮT BUỘC kế thừa `appDto.CommonQuery`).
  - Mỗi Domain chỉ có duy nhất 1 struct Command Query định nghĩa tất cả các filter có thể có. Hàm `buildQuery` sẽ tự động parse các trường này thành BSON.
  - Tất cả các hàm Get/Find trong Repository có thể nhận tham số truyền vào tuỳ ý cho gọn (ví dụ: `email string`). Bên trong hàm, KHÔNG ĐƯỢC tự tạo BSON lẻ mà phải khởi tạo Command Query object và truyền vào `buildQuery`.
  - Mọi hàm GET/READ bắt buộc phải hỗ trợ Projection (chỉ lấy field cần thiết, cấm `SELECT *`).
- **Rule 3.5 - Master Function (Add/Update/Delete)**: 
  - `Add`: Chỉ insert DB và trigger `onChange()`, cấm build entity ở đây.
  - `Update/Delete`: Hàm nghiệp vụ lẻ phải gom data rồi gọi về hàm **Master Update** / **Master Delete** để thực thi DB và kích hoạt `onChange()`.
- **Rule 3.6 - Atlas Search Bulk Operations**:
  - Atlas Search (stage `$search`) CHỈ hoạt động với Aggregate Pipeline (được dùng trong hàm `List/Count`) và KHÔNG thể dùng trực tiếp làm filter cho các hàm UpdateMany / DeleteMany của MongoDB.
  - Mọi thao tác Bulk Update / Bulk Delete có điều kiện search phức tạp BẮT BUỘC thực hiện qua 2 bước: Bước 1 gọi `List()` (với projection chỉ lấy `_id`), Bước 2 truyền mảng `_id` đó vào hàm `UpdateManyIDs()` hoặc `DeleteManyIDs()`.

## 4. Presentation Layer (`presentation/`)
- **Rule 4.1 - Controller "Ngu ngốc"**: Tầng này CHỈ được làm: Nhận HTTP Request -> Parse JWT gán vào DTO -> Gọi Application Layer -> Trả về HTTP Response. KHÔNG chứa business logic.
- **Rule 4.2 - Chuẩn hoá Response**: Trả về đúng format `{ "data": ..., "error_code": ..., "error_detail": ... }`.
- **Rule 4.3 - Route & URL Prefix**: BẮT BUỘC dùng hàm `getRoutePrefix() string`. Tuyệt đối không dùng Dynamic Path Parameter (`/:id`), phải dùng Query Parameter.
- **Rule 4.4 - Tách biệt DTOs**: Các Request/Response struct (DTO) dùng cho API Endpoint hoặc Swagger Docs bắt buộc phải được đặt ở thư mục `presentation/dto/`, TUYỆT ĐỐI KHÔNG khai báo struct inline trong file Handler.
- **Rule 4.5 - DTO & BaseResponse**: Tất cả API trả về thành công đều phải bọc qua Generic `response.BaseResponse[T]`. Handler phải khởi tạo trực tiếp instance của DTO và truyền vào `response.Success(w, dto)`, KHÔNG dùng `map[string]string` hay anonymous struct để mock. Lỗi dùng `response.BaseResponse[any]`.

## 5. Dependency Injection & Infrastructure (Root Level)
- **Rule 5.1 - Shared Infra Khởi tạo 1 lần**: Tại `cmd/api/setup_xxx.go`. Hỗ trợ kết nối Multi-server (nhiều DB, Redis cluster), cấm hardcode 1 connection Singleton.
- **Rule 5.2 - Module Encapsulation**: Hạ tầng được truyền từ `main.go` vào qua hàm `RegisterXRoutes(mux, db)` của từng module. Khởi tạo Repo, UseCase ở trong đó thông qua Specific Injection (truyền interface qua Constructor).
