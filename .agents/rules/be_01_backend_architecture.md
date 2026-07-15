# 01. Backend Architecture & Coding Standards (Golang)

*Đây là tập hợp các quy tắc "Luật Thép" dành riêng cho Agent chuyên xử lý Backend.*



## 1. Kiến trúc (Architecture) & Layer Boundaries
- Sử dụng kiến trúc **Domain-Driven Design (DDD)** làm kim chỉ nam.
- **Cấu trúc Thư mục (Domain-First / Package by Feature):** Bắt buộc tổ chức source code theo từng module/Domain riêng biệt (Bounded Context). Ví dụ: `internal/user/`, `internal/order/`.

- **Domain Layer** (BẮT BUỘC tách thành các file riêng biệt: `entity.go` và `repository.go`): 
  - **Entity (`entity.go`)**: Chứa định nghĩa các Entity. Mọi Entity **BẮT BUỘC** phải kế thừa `BaseEntity`.
  - **Repository Interface (`repository.go`)**: **CHỈ** định nghĩa Interface cho Repository tại đây. Thường thêm tiền tố `I` (VD: `ITenantRepository`). Interface này đại diện cho các hành động (contract) mà Application có thể gọi. **TUYỆT ĐỐI KHÔNG** chứa logic thực thi DB (Mongo, SQL) ở layer này.

- **Application Layer**: 
  - **Phân tách Command & Query (CQRS)**: BẮT BUỘC chia rạch ròi các Use Case thành 2 nhóm thư mục: `commands/` (chứa logic Create, Update, Delete làm thay đổi dữ liệu) và `queries/` (chứa logic Read, List lấy dữ liệu). Mỗi nghiệp vụ phải nằm trong 1 file riêng biệt (VD: `create_template.go`).
  - **Tổ chức DTOs (Request/Response)**: Mỗi Use Case nên đi kèm với cặp Request/Response DTO riêng biệt.
    - **Read (Query)**: Các DTO dùng cho việc lấy dữ liệu bắt buộc phải kế thừa/nhúng (embed) `appDto.CommonQuery`.
    - **Write (Command)**: Các DTO dùng cho việc tạo/sửa/xoá bắt buộc phải kế thừa/nhúng (embed) `appDto.CommonCommand` (chứa các thông tin định danh bóc từ Token như `TenantID`, `ByID`, `IsOwner`...). Tầng Presentation sẽ đảm nhận việc giải mã Token và điền dữ liệu vào `CommonCommand` trước khi truyền xuống Application.
    - **BẮT BUỘC** trả về DTO cho layer Presentation, **TUYỆT ĐỐI KHÔNG** return thẳng Entity của Domain ra ngoài để tránh rò rỉ dữ liệu nhạy cảm.
  - **Nhiệm vụ chính**: 
    - Nhận DTO đầu vào, Validate business rules (nếu có).
    - Triển khai logic khởi tạo Entity (Tạo ID mới, gán `CreatedDate`, `CreatedBy`, set default values) đối với luồng Insert/Add.
    - Gọi qua Interface của Repository (tầng Domain) để tương tác DB.
  - **Độc lập Framework**: Tầng này **TUYỆT ĐỐI KHÔNG** được chứa bất kỳ object nào liên quan đến HTTP/Web framework (như `http.Request`, `http.ResponseWriter` hay `gin.Context`). Nó chỉ nhận tham số là Go struct (DTO) và `context.Context`.
  - **Phân Zone trong Application**: Tương tự như Repository, trong các file Application/Use Case cũng **BẮT BUỘC** phải dùng comment để chia file thành các vùng chức năng: `// ================= READ ZONE =================`, `// ================= WRITE ZONE =================`, và `// ================= HELPERS ZONE =================`.
  - **Cấm truy cập DB/Cache/ES trực tiếp**: Tại tầng này, **TUYỆT ĐỐI KHÔNG** được tự ý khởi tạo kết nối hay viết code gọi trực tiếp xuống Database, Cache (Redis), hay ElasticSearch. Mọi luồng đọc/ghi dữ liệu **BẮT BUỘC** phải thông qua Interface của Repository.
  - **Quy tắc đặt tên hàm**: Tên hàm Use Case phải rõ ý nghĩa và phản ánh đúng nghiệp vụ thực hiện (Ubiquitous Language). Dù thực chất là thao tác CRUD, nhưng thay vì đặt tên chung chung như `Update`, hãy đặt tên mô tả hành động cụ thể (Ví dụ: `ChangeTenantTier`, `DeactivateTenant`).
  - **Khởi tạo Common Data (Audit Fields) bằng Utils**: Khi thực hiện luồng `CREATE` hoặc `UPDATE`, **BẮT BUỘC** phải sử dụng một hàm tiện ích dùng chung (Ví dụ: `utils.SetCommonEntityData(entity, command)`) để tự động gán các trường cơ sở của `BaseEntity` (như `CreatedBy`, `CreatedDate`, `LastUpdatedBy`, `LastUpdatedDate`, `ExpiredRef`). **TUYỆT ĐỐI KHÔNG** tự gán tay thủ công từng trường này rải rác ở các Use Case để tránh sai sót và trùng lặp code.
  - **Logic Xoá (Delete) Phức Tạp**: tuỳ thuộc vào độ phức tạp, có thể xoá trực tiếp hoặc query để lấy danh sách các ID trước (để lấy được id định danh thực hiện onchange), sau đó mới truyền trực tiếp danh sách ID này xuống hàm Delete của Repository.
  
- **Infrastructure Layer**: 
  - **Repository Implementation**: Đây là nơi chứa các file code thực thi cụ thể cho Repository (Ví dụ: `MongoTenantRepository`). **BẮT BUỘC** kế thừa `abstract_repository` (nơi đã định nghĩa sẵn các hàm tương tác DB). 
  - **Nhiệm vụ của Repository**: Chỉ làm nhiệm vụ build query cụ thể theo nghiệp vụ và gọi xuống `abstract_repository`.
  - **Encapsulation (Đóng gói)**: **TUYỆT ĐỐI KHÔNG** được public các hàm nguyên thuỷ của `abstract_repository` ra cho các layer khác gọi trực tiếp. Repository phải cung cấp các hàm đã được build sẵn thông qua Interface đã định nghĩa ở Domain Layer.
  - **Phân Zone trong Repository**: Trong file source code của Repository, **BẮT BUỘC** phải dùng comment nổi bật để chia file thành các zone chức năng rạch ròi bao gồm: `// ================= READ ZONE =================`, `// ================= WRITE ZONE =================`, và `// ================= HELPERS ZONE =================`. Khi thêm hàm mới, phải đặt đúng vào zone chức năng tương ứng.
  - **Quy tắc Build Query**: **BẮT BUỘC** phải có một hàm `buildQuery` dùng chung (thường đặt ở Helpers Zone). Hàm này phải gọi `BuildCommonQuery` (để xử lý các điều kiện chung như `tenant_id`, `is_deleted`...) trước, sau đó mới merge với các điều kiện query riêng của domain. Mọi hàm `READ` hoặc `UPDATE` bằng query trong Repository đều **BẮT BUỘC** phải thông qua hàm `buildQuery` này để tạo query DB, tuyệt đối không tự tạo object query rời rạc.
  - **Quy tắc Data Projection (Tối ưu truy vấn)**: Tất cả các hàm lấy dữ liệu (`READ`, `GET`) trong Repository **BẮT BUỘC** phải hỗ trợ tham số cho phép Application truyền vào danh sách các field cần lấy (Projection). Tuyệt đối cấm hành vi luôn luôn lấy toàn bộ Document (`SELECT *`) từ DB lên bộ nhớ nếu tầng trên chỉ cần sử dụng 1-2 trường cụ thể. Việc sử dụng Projection là bắt buộc để tối ưu hiệu năng.
  - **Quy tắc Master Update**: **BẮT BUỘC** phải có một hàm **Master Update** (ví dụ: `update(...)`) dùng chung trong Repository. Các hàm update cụ thể (theo từng use-case) sẽ nhận vào một command/DTO, tiến hành build mảng data (chỉ chứa các field thực sự thay đổi), và sau đó gọi đến hàm Master Update này. Master Update sẽ chịu trách nhiệm gọi phương thức `onChange()` (dùng để trigger event, xoá cache, sync ES...). **TUYỆT ĐỐI KHÔNG** được bỏ qua Master Update để gọi trực tiếp DB, nhằm đảm bảo mọi luồng update đều kích hoạt cơ chế `onChange()`.
  - **Quy tắc hàm Add/Insert**: Hàm `Add` trong Repository **CHỈ** làm duy nhất nhiệm vụ: nhận vào một Entity hoàn chỉnh (đã được tạo), insert xuống Database và sau đó gọi hàm `onChange()`. **TUYỆT ĐỐI KHÔNG** được thực hiện logic khởi tạo (build) Entity bên trong hàm này. Toàn bộ logic khởi tạo Entity (gán ID, set default values, gán ngày tạo...) phải được thực hiện ở **Application Layer** trước khi đẩy xuống Repository.
  - **Quy tắc Master Delete**: Tương tự như Update, **BẮT BUỘC** chỉ viết một hàm **Master Delete** (xóa 1 ID hoặc xóa nhiều theo danh sách ID) trong Repository. Trách nhiệm của hàm này chỉ đơn thuần là gọi lệnh xoá ở DB và kích hoạt `onChange()` cho danh sách ID đó. Mọi danh sách ID cần xoá đều phải được Application Layer chuẩn bị và truyền xuống.

- **Presentation Layer**: 
  - **Trách nhiệm duy nhất**: Tầng này là cửa ngõ giao tiếp (HTTP/gRPC) với client. Trách nhiệm của nó CẦN ĐƯỢC GIỚI HẠN ở việc: Nhận Request -> Validate data format (JSON/Form) -> Bóc tách JWT -> Gọi Application Layer -> Trả về HTTP Response. **TUYỆT ĐỐI KHÔNG** được phép chứa bất kỳ logic nghiệp vụ (business rules) nào tại đây.
  - **Bóc tách Token & DTOs**: Đây là nơi duy nhất được phép tương tác trực tiếp với JWT/Token. Đối với các API thay đổi dữ liệu (Write), Handler phải giải mã Token, trích xuất `TenantID`, `ByID`, `IsOwner`... và **BẮT BUỘC** phải tự động điền vào struct `CommonCommand` trước khi truyền xuống tầng Application. Tương tự với `CommonQuery` cho luồng Read.
  - **Cách ly Framework**: Các object đặc thù của Web Framework (như `*http.Request`, `http.ResponseWriter`, `gin.Context`, `fiber.Ctx`) **BẮT BUỘC** chỉ được tồn tại ở tầng này. Tuyệt đối cấm truyền chúng xuống Application Layer.
  - **Chuẩn hoá Response**: Mọi kết quả trả về cho Client (bao gồm cả lỗi từ Handler và Middleware) **BẮT BUỘC** phải tuân theo một Unified Model chuẩn duy nhất của toàn hệ thống: `{ "data": ..., "error_code": ..., "error_detail": ... }`. Việc dịch đa ngôn ngữ cho `error_detail` phải được xử lý ở Backend, Frontend chỉ việc hiển thị.
  - **Phân chia Route & Handler**: Không viết logic xử lý request cùng một chỗ với code đăng ký API URL. Cần tách bạch rõ ràng giữa file Route (định nghĩa endpoint) và file Handler (chứa logic HTTP). **BẮT BUỘC**: 
    1. Khi khai báo Route path, không được hardcode toàn bộ chuỗi URL. Thay vào đó, phải có một cơ chế lấy prefix bao gồm cả tên domain (Ví dụ: gọi hàm `getRoutePrefix("tenant")` để trả về `/api/v1/tenant`).
    2. **Tuyệt đối không dùng Dynamic Path Parameter** (như `/:id`, `/:userId`) trong việc định nghĩa URL nhằm mục đích thân thiện với các hệ thống phân tích metrics và Rate Limit ở tầng API Gateway/WAF. Để truyền ID hoặc tham số động, bắt buộc phải dùng **Query Parameter** (Ví dụ: `/detail?id=123`) hoặc truyền qua **Request Body**.

- **Dependency Injection & Bootstrapping**:
  - **Module Encapsulation (Đóng gói khởi tạo)**: Hàm `main()` **TUYỆT ĐỐI KHÔNG** được chứa logic khởi tạo lắt nhắt của từng Repo, UseCase, Handler. Trách nhiệm khởi tạo (Dependency Injection) phải được **đẩy vào bên trong từng Module** (ví dụ thông qua hàm `RegisterTenantRoutes(mux, db)`). Hàm `main()` chỉ làm nhiệm vụ kết nối Database và gọi các hàm Register của các module.
  - **Specific Injection**: Khi một UseCase cần tương tác với nhiều Repositories khác nhau, phải sử dụng phương pháp **Tiêm trực tiếp (Specific Injection)** thông qua tham số của constructor (Ví dụ: `NewUseCase(tenantRepo, userRepo)`). Khuyến cáo một UseCase không nên thao tác với quá 3 Repositories để đảm bảo nguyên lý Single Responsibility.

## 2. Tiêu chuẩn Code & Đặt tên (Coding Standards & Naming Conventions)
- **Idiomatic Go**: Tuân thủ chuẩn định dạng `gofmt`. Sử dụng `camelCase` cho biến/hàm nội bộ, `PascalCase` cho public.
- **Ubiquitous Language**: Tên biến, tên hàm, tên struct phải phản ánh đúng thuật ngữ nghiệp vụ (Ubiquitous Language) của DDD. Tên hàm nên bắt đầu bằng động từ hành động (VD: `PlaceOrder`, `CancelSubscription`).
- **Error Handling**: Xử lý lỗi tường minh, gói lỗi (wrap errors). Tuyệt đối không lạm dụng `panic()`.
- **Concurrency**: Sử dụng goroutines/channels an toàn, có cơ chế timeout/cancellation qua `context.Context`.

## 3. Quy chuẩn Kafka Topics & Events
- **Tên Topic**: Đặt theo định dạng `[domain].[entity].[event]` (toàn bộ chữ thường, cách nhau bởi dấu chấm). VD: `orders.payment.succeeded`.
- **Payload Schema Chung (Common Event Model)**: Mọi message push lên queue bắt buộc phải bọc bởi một Model chuẩn, bao gồm:
  - `source`: Định danh nguồn phát ra message (service/module nào push message này).
  - `type`: Loại sự kiện (Ví dụ: `UserCreated`, `ProductPriceUpdated`), dùng để consumer nhận diện.
  - `data`: Nội dung payload thực sự (thường dạng JSON). Tại phía Consumer, `data` sẽ được parse/Unmarshal thành Struct/Model tương ứng dựa trên `type` của message.

## 4. Quản lý Constants, Cấu hình & Utils
- **Cấu hình & Biến môi trường (Environment Variables)**: Tuyệt đối **không được hardcode** các thông tin kết nối (Connection URLs, Port), thông tin nhạy cảm (API Keys, Secrets, Passwords) trong source code. Bắt buộc phải inject thông qua biến môi trường (`.env`, env vars) hoặc các trình quản lý config (VD: `Viper`).
- **Constants (Hằng số tĩnh)**:
  - Domain-specific (ví dụ: Enum trạng thái đơn hàng): Đặt ngay bên trong package của lớp `Domain` tương ứng.
  - System-wide (ví dụ: HTTP Status Codes đặc chế, mã lỗi chung): Đặt tại `pkg/constant/`.
- **Utils (Hàm tiện ích)**:
  - Logic không chứa nghiệp vụ: Gom vào thư mục `pkg/utils/...`.
  - Logic liên quan tới nghiệp vụ nội bộ: Chuyển thành **Domain Service** hoặc hàm trong Entity. Không đặt ở Utils.

## 5. Infrastructure Connections (Database, Cache, MQ)
- **Tính Abstract & Đa kết nối (Multi-server)**: Tất cả kết nối hạ tầng phải được trừu tượng hóa (Abstracted) thông qua Interface hoặc Connection Factory. Hệ thống phải hỗ trợ khả năng khởi tạo và duy trì kết nối tới nhiều server/cụm (cluster) khác nhau cùng lúc (ví dụ: kết nối nhiều cụm Kafka, Master-Slave DB, nhiều cụm Redis). **Tuyệt đối không dùng biến Singleton hardcode 1 connection duy nhất** áp đặt cho toàn hệ thống.
- **MongoDB**: Đảm bảo khai báo index, tối ưu truy vấn. Hỗ trợ pool kết nối đa dạng.
- **Redis**: Quản lý TTL chặt chẽ, tối ưu kích thước dữ liệu.

## 6. Testing
- Viết Unit Test cho các function cốt lõi và UseCase. Tạo Mock cho các Interface của Infrastructure, MQ, External APIs.

## 7. Phân chia Use Case & Tách Hàm (Application Layer)
- **Thiết kế Use Case (Application)**: Không dồn tất cả nghiệp vụ phức tạp vào một Application/UseCase khổng lồ.
  - Ở giai đoạn đầu, nếu chỉ là các thao tác CRUD cơ bản, hệ thống cho phép gom chung vào một Application Service cho gọn.
  - Tuy nhiên, đối với các nghiệp vụ phức tạp hoặc có ngữ cảnh khác nhau (Ví dụ: Việc tạo User có thể đến từ `Register`, `AdminCreate`, hoặc `PublicAPI`), **phải tách riêng** thành các Application/UseCase riêng biệt thay vì dồn chung và dùng `if/else` để kiểm tra role/ngữ cảnh.
- **Quy tắc tách hàm (Function Splitting)**: Không lạm dụng việc tách hàm (over-engineering). **Hạn chế việc tách hàm** đối với những đoạn code chỉ có vài dòng và chỉ được sử dụng duy nhất ở một nơi. Hãy giữ code liền mạch (inline) để tăng tính dễ đọc (readability) và dễ theo dõi luồng thực thi từ trên xuống dưới.

---

# [CRITICAL SYSTEM DIRECTIVE FOR AI AGENTS]
**To any AI Agent or Coding Assistant operating in this workspace:**

1. **MANDATORY READING**: Before generating ANY code for a new module or feature, you MUST read this entire `01_backend_architecture.md` document and strictly apply all Clean Architecture & CQRS rules defined above.
2. **REFERENCE MODULE (`tenant`)**: The module `sowfkun-verse-api/internal/tenant` is the **Golden Standard**. When tasked with creating a new module (e.g., `product`, `order`), you MUST first analyze the structure, naming conventions, and commenting style of the `tenant` module.
3. **EXACT REPLICATION**: 
   - Replicate the exact folder structure (`domain`, `infrastructure`, `application/commands`, `presentation/http`).
   - Replicate the comment zones (`// ================= READ ZONE =================`).
   - Replicate the DTO embedding (`appDto.CommonCommand`, `appDto.CommonQuery`).
   - Replicate the `onChange` event publishing rule in `Master Update/Delete`.
   - Never use dynamic path parameters (`/:id`).
4. Do NOT introduce new architectural patterns or deviate from this guide without explicit USER approval.
