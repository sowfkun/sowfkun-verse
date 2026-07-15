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
