# Global Agent Rules

Mọi Agent khi hoạt động trong dự án này **bắt buộc** phải tuân thủ các quy tắc toàn cục dưới đây. 
*(Lưu ý: Các quy tắc chuyên sâu cho từng phân hệ như Backend, Frontend, Mobile đã được quản lý và tự động kích hoạt thông qua cơ chế **Skills** trong thư mục `.agents/skills/`. Agent sẽ tự động nạp chúng dựa theo ngữ cảnh của task).*

## Nguyên tắc Toàn cục (Global Principles)
Dù bạn là Agent làm ở phân hệ nào, bạn cũng phải tuyệt đối tuân thủ các nguyên tắc sau:

1. **Hiểu Bối Cảnh & Cần Xác Nhận:** Phải hiểu bối cảnh dự án rõ ràng trước khi thực thi. Luôn lập kế hoạch/phân tích và **phải có sự confirm (xác nhận) của người dùng** thì mới được phép bắt đầu viết code. *(Ngoại lệ: Đối với những chỉnh sửa thực sự rất dễ hoặc chỉ cần thay đổi 1-2 dòng code thì được phép sửa đổi trực tiếp mà không cần viết plan).*
2. **On-Premise First (Không Hardcode):** Toàn bộ code FE và BE đều theo hướng On-Premise. Tuyệt đối KHÔNG được phép hardcode (logo, màu sắc thương hiệu, external URLs, database, v.v.). Mọi thứ phải cấu hình qua biến môi trường hoặc biến CSS.
3. **Multi-tenant System:** Toàn bộ hệ thống phải tuân thủ kiến trúc Multi-tenant (hỗ trợ nhiều khách hàng độc lập).
4. **Chuẩn hóa Thời Gian (UTC):** Tất cả khi làm việc với thời gian (lưu trữ, xử lý, payload) đều bắt buộc phải quy về chuẩn **UTC**.
5. **Tuân thủ Kiến trúc Chuẩn:** Phải làm theo quy tắc chung của toàn hệ thống (Golden Standard). Không tự ý sáng tạo kiến trúc, design pattern mới hay sử dụng thư viện lạ nếu không có sự cho phép.
6. **Trả lời Câu hỏi Ngắn gọn:** Đối với những prompt dạng câu hỏi hoặc cần tham khảo, **phải trả lời/thảo luận chứ không được nhảy vào code ngay**. Câu trả lời cần ngắn gọn, súc tích, vừa đủ hiểu để không làm tốn token.
7. **Sử dụng Codegraph:** Sử dụng tool codegraph để hiểu bối cảnh và luồng code khi cần thiết trước khi thực thi.
8. **Tối ưu Token & Ngắn gọn (Zero-Waste):** Khi đọc file phải dùng StartLine và EndLine chính xác, KHÔNG đọc toàn bộ file. Trong quá trình lên kế hoạch (implementation_plan.md), CHỈ mô tả high-level logic hoặc hướng giải quyết bằng văn bản (text), TUYỆT ĐỐI KHÔNG viết mã nguồn (raw code) vào file plan để tránh lãng phí token. Các câu trả lời sau khi xong một việc thì báo cáo ngắn gọn đã làm gì, kết quả là gì, không cần giải thích. Chỉ những câu hỏi mới cần trả lời chi tiết
9. **Cơ chế Cập nhật Tối ưu (Dirty Check & Optional Update):** Khi thực hiện các API cập nhật dữ liệu (Update/Patch):
   - **Phía Frontend (Client):** Chỉ gửi lên API các trường dữ liệu thực sự có sự thay đổi (dirty check) và hợp lệ. Không gửi các trường rỗng/null/không đổi lên API để tiết kiệm tài nguyên mạng và tránh ghi đè dữ liệu cũ ngoài ý muốn. Nếu không có thay đổi nào hiệu dụng, nút Lưu/Submit bắt buộc phải bị vô hiệu hóa (disabled).
   - **Phía Backend (Server):** Tầng Presentation (DTO) định nghĩa các trường dữ liệu dưới dạng con trỏ (pointer) hoặc struct tùy biến để phân biệt giữa việc "trường có truyền dữ liệu lên nhưng rỗng" và "không truyền trường đó lên" (bằng `nil`). Tầng Application (UseCase) chỉ cập nhật DB với các trường khác `nil` và khác với giá trị hiện tại của DB. Nếu không có thay đổi hiệu dụng nào, bỏ qua việc cập nhật DB để tối ưu hóa hiệu suất (Skip DB write).
10. **Không tự ý Commit Code:** Tuyệt đối KHÔNG tự ý thực hiện commit code lên Git trừ khi nhận được yêu cầu xác nhận rõ ràng của người dùng (ví dụ: "commit đi").
