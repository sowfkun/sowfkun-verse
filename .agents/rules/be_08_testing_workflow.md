# 08. Testing Workflow (Quy trình Test của Agent)

Để đảm bảo các tính năng và API do Agent phát triển hoạt động chính xác và an toàn, Agent BẮT BUỘC tuân thủ quy trình kiểm thử (Testing Workflow) theo hai trường hợp sau:

---

## TRƯỜNG HỢP 1: Debug cục bộ một Function/Logic
Dành riêng cho việc kiểm thử nhanh logic của một hàm hoặc thuật toán nội bộ:

1. **Hàm Test Tạm (`runAITest`)**:
   - Định nghĩa hàm rỗng `func runAITest(ctx context.Context, db *mongo.Database, redisClient *redis.Client) {}` ở cuối file `cmd/api/main.go`.
   - Gọi hàm này trước dòng `http.ListenAndServe`.
2. **Quản lý log & Dọn dẹp**:
   - Mọi log ghi nhận từ quá trình test phải xuất ra file trong thư mục `scratch/` ở thư mục gốc của project (ví dụ: `sowfkun-verse-api/scratch/`).
   - Khi test thành công, dọn dẹp sạch ruột của hàm `runAITest` và xóa toàn bộ file log trong thư mục `scratch/`.

---

## TRƯỜNG HỢP 2: Kiểm thử tích hợp luồng API (API Flow Testing)
Dành cho việc kiểm thử các API Endpoints hoàn chỉnh:

1. **Khởi chạy API Server**:
   - Thực hiện biên dịch và khởi chạy máy chủ API thật (không chèn code test debug vào `main.go`).
2. **Tạo Script Test bên ngoài**:
   - Tạo một script test độc lập bên ngoài thư mục src chính, lưu tại thư mục `scratch/` (Ví dụ: `scratch/api_test.go` hoặc `scratch/test.sh`).
   - Script này sử dụng HTTP Client gửi request trực tiếp lên API Server đang chạy (ví dụ: `http://localhost:8080/api/v1/...`).
3. **Thao tác & Khẳng định (Assert)**:
   - Viết các kịch bản kiểm thử luồng thực tế: từ gọi API `/register`, nhận OTP, gọi `/verify-otp`, `/login`, và `/refresh-token`.
   - Kiểm tra mã HTTP status, cấu trúc Response JSON, và các mã lỗi trả về.
4. **Dọn dẹp**:
   - Sau khi kiểm thử thành công và User xác nhận, Agent **bắt buộc** phải xóa hoàn toàn các file script test tạm nằm trong thư mục `scratch/`.
