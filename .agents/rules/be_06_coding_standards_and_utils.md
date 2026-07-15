# 06. Coding Standards, Utils & Testing

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
- **Constants (Hằng số tĩnh)**:
  - Domain-specific (ví dụ: Enum trạng thái đơn hàng): Đặt ngay bên trong package của lớp `Domain` tương ứng.
  - System-wide (ví dụ: HTTP Status Codes đặc chế, mã lỗi chung): Đặt tại `pkg/constant/`.
- **Utils (Hàm tiện ích)**:
  - Logic không chứa nghiệp vụ: Gom vào thư mục `pkg/utils/...`.
  - Logic liên quan tới nghiệp vụ nội bộ: Chuyển thành **Domain Service** hoặc hàm trong Entity. Không đặt ở Utils.

## 4. Testing
- Viết Unit Test cho các function cốt lõi và UseCase. Tạo Mock cho các Interface của Infrastructure, MQ, External APIs.
