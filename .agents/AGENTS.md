# Global Agent Rules

Mọi Agent khi hoạt động trong dự án này **bắt buộc** phải tuân thủ các quy tắc toàn cục dưới đây. 
*(Lưu ý: Các quy tắc chuyên sâu cho từng phân hệ như Backend, Frontend, Mobile đã được quản lý và tự động kích hoạt thông qua cơ chế **Skills** trong thư mục `.agents/skills/`. Agent sẽ tự động nạp chúng dựa theo ngữ cảnh của task).*

## Nguyên tắc Toàn cục (Global Principles)
Dù bạn là Agent làm ở phân hệ nào, bạn cũng phải tuân thủ:
1. **Hiểu Bối Cảnh:** Luôn nắm rõ stack công nghệ hiện tại thông qua file `.agents/project.md`.
2. **Không Hardcode:** Tuyệt đối không hardcode cấu hình, API key, Secret, hay connection URL vào trong code. Dùng biến môi trường (Environment Variables).
3. **Phản hồi đối với Câu Hỏi (Question Prompts):** Đối với các prompt mang tính chất đặt câu hỏi, tham khảo ý kiến, hoặc hỏi về cách giải quyết (ví dụ: "làm sao để...", "như thế nào...", "nên làm gì..."), **tuyệt đối không được tự động sinh mã nguồn (code) hay thực thi tool ghi file ngay lập tức**. Bạn chỉ được phép trả lời lý thuyết, giải thích hoặc đưa ra bản Kế hoạch (Planning) các bước sẽ làm. Chờ đến khi User chốt phương án và ra lệnh "Thực thi đi" thì mới được phép viết/sửa code.
4. **Plan First:** Khi nhận một yêu cầu phức tạp, hãy phân tích và trình bày hướng giải quyết trước khi ghi đè hoặc tạo hàng loạt file.
5. **Thảo Luận Trước Khi Code:** Khi người dùng đặt câu hỏi, yêu cầu phân tích, hoặc yêu cầu lập kế hoạch (planning), PHẢI trả lời và thảo luận trước. KHÔNG được ngay lập tức bắt tay vào viết code.
6. **Clean Up:** Tự động xóa bỏ mọi file/script tạm thời (scratch files) do Agent sinh ra sau khi hoàn thành mục đích sử dụng. Tự động thêm các file/thư mục không cần thiết (build folder, logs, temp files) vào `.gitignore` để tránh đẩy nhầm lên Git.

## Chỉ thị Tối cao (Critical System Directives)
1. **Tham chiếu chuẩn mực (Golden Standard)**: Khi nhận yêu cầu tạo Module/Tính năng mới, BẮT BUỘC phải dùng module mẫu (Reference Module) làm chuẩn mực để sao chép cấu trúc, cách đặt tên, và kiến trúc.
   - **Đối với Backend**: Module `sowfkun-verse-api/internal/tenant` là **Golden Standard**. Tuyệt đối phải sao chép chính xác cấu trúc thư mục (Domain, Application, Infra, Presentation), các vùng comment (`// ================= READ ZONE =================`), và cơ chế nhúng DTO (CommonCommand/CommonQuery) của nó.
2. **Nghiêm cấm sáng tạo kiến trúc (No Architecture Hallucination)**: KHÔNG tự ý đưa thêm các design pattern mới, thư viện bên ngoài mới, hoặc phá vỡ cấu trúc Layered/CQRS hiện tại mà không có sự cho phép rõ ràng từ User. Mọi dòng code sinh ra phải nhất quán 100% với form mẫu hiện có.
