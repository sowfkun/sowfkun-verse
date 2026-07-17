# 08. Testing Workflow (Quy trình Test của Agent)

Để đảm bảo mọi dòng code do Agent viết ra đều chạy đúng với luồng thực tế (đã được nạp đầy đủ Dependency Injection như Database, Redis, Kafka, OpenSearch...), Agent BẮT BUỘC tuân thủ quy trình kiểm thử (Testing Workflow) sau khi phát triển xong tính năng mới:

## 1. Môi trường Test (Directly on Main)
- KHÔNG tạo các file script độc lập (như `test_mail.go` hoặc `main_test.go` tạm bợ) để test vì chúng sẽ bị thiếu context hạ tầng.
- Bắt buộc phải test trực tiếp thông qua hàm `main()` của ứng dụng (`cmd/api/main.go`).

## 2. Hàm Test Tạm (Test Wrapper)
- Tạo một hàm rỗng với tên chung chung không phụ thuộc vào bất kỳ domain nào, ví dụ: `func runAITest(ctx context.Context, ...) {}`. 
- **Lưu ý quan trọng**: Phải note/comment rõ ràng trên hàm này đây là hàm dành riêng cho "AI test sau khi phát triển tính năng".
- Gọi hàm `runAITest` này ở ngay cuối hàm `main()` (sau khi đã setup xong toàn bộ hạ tầng).
- Chèn logic cần test vào bên trong hàm `runAITest`.

## 3. Quản lý Log Output
- Mọi kết quả output (fmt.Println, log.Printf...) hoặc file sinh ra từ quá trình test bắt buộc phải được lưu vào thư mục `scratch/` **nằm ngay trong thư mục gốc của project** (ví dụ: `sowfkun-verse-api/scratch/`).
- Điều này để đảm bảo rằng nếu Agent lỡ có quên xóa file thì file log cũng không bị Git track và đẩy lên repo (thư mục `scratch` đã được khai báo sẵn để ignore).

## 4. Báo cáo Kết quả (Full Log)
- Sau khi chạy test, Agent phải hiển thị **TOÀN BỘ LOG (Full Log)** cho User xem.
- TUYỆT ĐỐI KHÔNG được tóm tắt (summarize) kết quả test. User cần nhìn thấy raw data để tự đánh giá luồng code.

## 5. Dọn dẹp (Cleanup)
- CHỈ KHI NÀO User xác nhận (Confirm) test đã hoàn thành và thành công.
- Agent BẮT BUỘC phải thực hiện dọn dẹp:
  1. Xóa toàn bộ file log trong thư mục `scratch/` của project.
  2. Dọn sạch ruột của hàm `runAITest()` (chỉ để lại hàm rỗng `func runAITest() {}` hoặc xóa luôn lệnh gọi đi) để giữ cho file `main.go` sạch sẽ.
