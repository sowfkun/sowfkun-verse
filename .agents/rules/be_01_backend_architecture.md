---
trigger: always_on
---

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
    type AddXCommand struct { ... } // DTO
    // ================= TYPE ZONE =================
    type IAddXUseCase interface { ... }
    type addXUseCase struct { ... }
    // ================= EXECUTION ZONE =================
    func NewAddXUseCase(...) IAddXUseCase { ... }
    func (uc *addXUseCase) Execute(...) error { ... }
    ```
- **Rule 2.3 - DTO và Trả về**: 
  - Request DTO bắt buộc nhúng `appDto.CommonCommand` hoặc `appDto.CommonQuery`.
  - TUYỆT ĐỐI KHÔNG trả về thẳng Entity ra Controller, phải dùng Response DTO.
- **Rule 2.4 - Audit Fields**: Dùng `utils.SetCommonEntityData(entity, command)` để set tự động thông tin Audit khi Create/Update.
- **Rule 2.5 - Xử lí keyword nếu cần (text.BuildKeywords(cmd.Name)
- **Rule 2.6 - Delete Hỗ trợ Xóa 1 / Xóa Nhiều & Rào An Toàn (IsSelAll / IncludeIDs)**:
  - UseCase Delete nhúng `CommonQuery` để hỗ trợ xóa theo filter/danh sách ID.
  - **Rào an toàn bắt buộc tại Delete UseCase**: Bắt buộc kiểm tra `if !cmd.IsSelAll && len(cmd.IncludeIDs) == 0 { return errors.New(coreDomain.ErrBadRequest) }` để ngăn ngừa việc vô tình xóa toàn bộ danh sách khi Client truyền payload rỗng hoặc thiếu sót.
  - **Kiểm tra xung đột tại Presentation (`PopulateCommonQuery`)**: Nếu `query.IsSelAll == true` VÀ `len(query.IncludeIDs) > 0` thì lập tức trả về `errors.New(coreDomain.ErrBadRequest)` (không được vừa chọn tất cả vừa chỉ định danh sách ID cụ thể).
- **Rule 2.7 - Cấm lạm quyền**: TUYỆT ĐỐI KHÔNG gọi thẳng DB, Cache, ES ở layer này. Phải đi qua Interface của Repo. 
- **Rule 2.8 - Soft Delete Data Tracking**: Khi thực hiện xóa (Delete UseCase), bắt buộc chuẩn bị `updateData` chứa thông tin actor (`u_by`) và `tracking_id` (nếu có từ `cmd.TrackingID`) truyền vào `SoftDeleteManyIDs` của Repository để lưu vết dữ liệu thao tác.
- **Rule 2.9 - Multi-Tenant Data Isolation Check**: Mọi UseCase đọc hoặc ghi dữ liệu đơn lẻ theo ID/Code (`GetByID`, `GetByCode`, `GetOne`, `Update`, `Delete`): **BẮT BUỘC** kiểm tra quyền sở hữu Tenant: `if entity == nil || entity.TenantID != q.TenantID { return nil, errors.New(coreDomain.ErrNotFound) }` để ngăn chặn triệt để rủi ro rò rỉ hoặc can thiệp dữ liệu chéo giữa các Tenant.

## 3. Infrastructure Layer (`infrastructure/`)
- **Rule 3.1 - Naming Convention**: Tên file BẮT BUỘC là `repository.go` (Ví dụ: `internal/[domain]/infrastructure/repository.go`). Trong trường hợp có caching (Redis), caching logic sẽ được tích hợp trực tiếp vào trong file repository này để làm cổng Gateway dữ liệu hợp nhất.
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
  - Tất cả các hàm Get trong Repository có thể nhận tham số truyền vào tuỳ ý cho gọn (ví dụ: `email string`). Bên trong hàm, KHÔNG ĐƯỢC tự tạo BSON lẻ mà phải khởi tạo Command Query object và truyền vào `buildQuery`.
  - Mọi hàm GET/READ bắt buộc phải hỗ trợ Projection (chỉ lấy field cần thiết, cấm `SELECT *`).
  - **Quy tắc gán & truyền Projection:**
    - Đối với các hàm List nhận vào đối tượng Query (kế thừa từ `CommonQuery`), tham số `projection` sẽ được trích xuất trực tiếp từ trong `CommonQuery.Projection` (không cần tham số projection riêng biệt ở chữ ký hàm).
    - Đối với các hàm Get nhận đối số projection riêng biệt, bắt buộc phải truyền projection map cụ thể.
    - Khi gọi bất kỳ hàm Get/List nào, Agent/Reviewer bắt buộc phải đối chiếu và đánh giá xem projection đã được gán/truyền đi hay chưa. Nếu truyền `nil` để lấy đầy đủ document (Full Document), **BẮT BUỘC** phải có comment giải thích rõ lý do.
    - **Bảo toàn trường `tid` và `is_del` trong Projection:** `AbstractMongoRepository` (tại `GetByID`, `GetOne`) **BẮT BUỘC** luôn tự động gán thêm `"tid": 1` và `"is_del": 1` vào projection map gửi xuống MongoDB để tầng UseCase và Soft-delete filter luôn có đủ dữ liệu kiểm tra quyền sở hữu Tenant.
- **Rule 3.5 - Master Function (Add/Update/Delete)**: 
  - `Add`: Chỉ insert DB và trigger `onChange()`, cấm build entity ở đây.
  - `Update/Delete`: Hàm nghiệp vụ lẻ phải gom data rồi gọi về hàm **Master Update** / **Master Delete** để thực thi DB và kích hoạt `onChange()`. Các hàm update phải nhận model update đã được xử lí ở usecases. Chỉ check field giá trị để build data và gọi master update. được được xử lí logic gì trong này
- **Rule 3.6 - Atlas Search Bulk Operations**:
  - Atlas Search (stage `$search`) CHỈ hoạt động với Aggregate Pipeline (được dùng trong hàm `List/Count`) và KHÔNG thể dùng trực tiếp làm filter cho các hàm UpdateMany / DeleteMany của MongoDB.
  - Mọi thao tác Bulk Update / Bulk Delete có điều kiện search phức tạp BẮT BUỘC thực hiện qua 2 bước: Bước 1 gọi `List()` (với projection chỉ lấy `_id`), Bước 2 truyền mảng `_id` đó vào hàm `UpdateManyIDs()` hoặc `DeleteManyIDs()`.
- **Rule 3.7 - insert thì đặt tên là Add. danh sách thì là List.., lấy 1 thì là Get... KHÔNG đặt tên Create..., Find...
- **Rule 3.8 - Phân biệt Realtime Read (Strong) vs Search Engine (Eventual Consistency)**:
  - Các hàm `GetByID`, `GetOne` truy vấn trực tiếp vào Primary Database (WiredTiger Storage Engine) đảm bảo tính nhất quán tức thì (Strong Consistency - Realtime 100%).
  - Các hàm `List`, `Count` khi đi qua Search Engine (Atlas Search `$search`, OpenSearch) có độ trễ đồng bộ (Index Ingestion Lag từ 500ms - 2s).
  - Khi thực hiện các luồng nghiệp vụ ghi DB (Add/Update/Delete) mà cần query/get lại entity ngay sau đó: **BẮT BUỘC** dùng `GetByID` hoặc `Find()` trực tiếp từ DB chính để có dữ liệu Realtime, **TUYỆT ĐỐI KHÔNG** dùng search engine để tránh dữ liệu bị stale/bóng ma. Nếu bắt buộc dùng search engine thì phải có cơ chế Delay / Retry.
- **Rule 3.9 - Atlas Search & Query Builder (AppendOrClause / AppendAndClause)**:
  - Khi xây dựng BSON Query cho các điều kiện OR / AND phức tạp hoặc phân quyền Scope trong hàm `buildQuery`, **BẮT BUỘC** sử dụng `mongodb.AppendOrClause(query, orClauses)` và `mongodb.AppendAndClause(query, andClauses)`. TUYỆT ĐỐI KHÔNG tự tạo hoặc ghi đè `query["$or"]` / `query["$and"]` thủ công.
  - Khi cần tìm kiếm / lọc theo ID (`_id`, `IncludeIDs`, Scope `_id`), Search Index của collection tại `cmd/indexer/mongo.go` bắt buộc phải có mapping `"_id": bson.M{"type": "objectId"}` để Atlas Search có thể lọc trực tiếp 100% trong `$search` stage mà không cần fallback `$match`.

## 4. Presentation Layer (`presentation/`)
- **Rule 4.1 - Controller "Ngu ngốc"**: Tầng này CHỈ được làm: Nhận HTTP Request -> Parse JWT gán vào DTO -> Gọi Application Layer -> Trả về HTTP Response. KHÔNG chứa business logic.
- **Rule 4.2 - Chuẩn hoá Response**: Trả về đúng format `{ "data": ..., "error_code": ..., "error_detail": ... }`.
- **Rule 4.3 - Route & URL Prefix**: BẮT BUỘC dùng hàm `getRoutePrefix() string`. Tuyệt đối không dùng Dynamic Path Parameter (`/:id`), phải dùng Query Parameter.
- **Rule 4.4 - Tách biệt DTOs**: Các Request/Response struct (DTO) dùng cho API Endpoint hoặc Swagger Docs bắt buộc phải được đặt ở thư mục `presentation/dto/`, TUYỆT ĐỐI KHÔNG khai báo struct inline trong file Handler.
- **Rule 4.5 - DTO & BaseResponse**: Tất cả API trả về thành công đều phải bọc qua Generic `response.BaseResponse[T]`. Handler phải khởi tạo trực tiếp instance của DTO và truyền vào `response.Success(w, dto)`, KHÔNG dùng `map[string]string` hay anonymous struct để mock. Lỗi dùng `response.BaseResponse[any]`.
- **Rule 4.6 - RequestID / Tracking Middleware**: Đối với các API nhạy cảm / nguy hiểm (như Delete, Purge, Bulk Update), bắt buộc bọc `middleware.RequestIDMiddleware` tại từng route tương ứng để nhận/sinh `X-Request-ID` / `X-Tracking-ID`, đưa vào Context và tự động gắn `TrackingID` vào `CommonCommand`.

## 5. Dependency Injection & Infrastructure (Root Level)
- **Rule 5.1 - Shared Infra Khởi tạo 1 lần**: Tại `cmd/api/setup_xxx.go`. Hỗ trợ kết nối Multi-server (nhiều DB, Redis cluster), cấm hardcode 1 connection Singleton.
- **Rule 5.2 - Module Encapsulation**: Hạ tầng được truyền từ `main.go` vào qua hàm `RegisterXRoutes(...)` của từng module. Khởi tạo Repo, UseCase ở trong đó thông qua Specific Injection (truyền interface qua Constructor).
- **Rule 5.3 - Multi-Cluster Connection Explicit Naming (Định danh kết nối đa cụm tường minh)**:
  - Khi làm việc với các thành phần hạ tầng (Infrastructure) hỗ trợ đa cụm (Multi-server / Multi-cluster) như MongoDB (`dbTenant1`, `dbSystem1`, `dbConfig1`), Redis (`generalRedisClient`, `agentBusinessRedisClient`, `gatewayRedisClient`), Kafka Producers (`general1Producer`, `general2Producer`, `entitySyncProducer`), OpenSearch (`loggingClient`):
  - Tên biến, trường struct, tham số hàm (ở `main.go`, `setup_*.go`, `RegisterXRoutes`, `RegisterMQHandlers`, Repositories, UseCases, Services, Handlers, Jobs) **BẮT BUỘC** phải đặt tên rõ ràng, phản ánh chính xác cụm kết nối đang sử dụng (VD: `dbTenant1`, `generalRedisClient`, `agentBusinessRedisClient`, `general1Producer`, `general2Producer`, `loggingClient`).
  - **TUYỆT ĐỐI NGHIÊM CẤM** đặt tên mơ hồ, chung chung (như `db`, `redisClient`, `producer`, `client`, `opensearchClient`) gây nhầm lẫn luồng kết nối giữa các cụm độc lập.