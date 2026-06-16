# Global Agent Rules & Router

Mọi Agent khi hoạt động trong dự án này **bắt buộc** phải đọc file này đầu tiên. Tùy thuộc vào phạm vi của Task được giao, Agent phải tự động nạp (read) thêm các tài liệu quy tắc chuyên sâu dưới đây trước khi bắt tay vào code.

## Bản đồ Điều hướng Quy tắc (Rule Router)

### 1. Backend Team (Golang, MongoDB, Redis, Kafka)
Nếu Task liên quan đến việc viết logic, xử lý Database, thiết kế Domain Logic, hoặc Message Queue:
👉 **HÀNH ĐỘNG BẮT BUỘC:** Đọc ngay file `01_backend_architecture.md` tại đường dẫn: `.gemini/rules/01_backend_architecture.md`

### 2. Frontend / Admin Web Team (Next.js)
Nếu Task liên quan đến xây dựng giao diện Web, SSR, Admin Panel, hoặc tương tác API phía Browser:
👉 **HÀNH ĐỘNG BẮT BUỘC:** Đọc ngay file `frontend.md` tại đường dẫn: `.gemini/rules/frontend.md` *(Sẽ được định nghĩa chi tiết sau)*

### 3. Mobile App Team (Flutter)
Nếu Task liên quan đến làm app Mobile (iOS/Android), UI Cross-platform, State Management trên App:
👉 **HÀNH ĐỘNG BẮT BUỘC:** Đọc ngay file `mobile.md` tại đường dẫn: `.gemini/rules/mobile.md` *(Sẽ được định nghĩa chi tiết sau)*

---

## Nguyên tắc Toàn cục (Global Principles)
Dù bạn là Agent làm ở phân hệ nào, bạn cũng phải tuân thủ:
1. **Hiểu Bối Cảnh:** Luôn nắm rõ stack công nghệ hiện tại thông qua file `.gemini/project.md`.
2. **Không Hardcode:** Tuyệt đối không hardcode cấu hình, API key, Secret, hay connection URL vào trong code. Dùng biến môi trường (Environment Variables).
3. **Phản hồi đối với Câu Hỏi (Question Prompts):** Đối với các prompt mang tính chất đặt câu hỏi, tham khảo ý kiến, hoặc hỏi về cách giải quyết (ví dụ: "làm sao để...", "như thế nào...", "nên làm gì..."), **tuyệt đối không được tự động sinh mã nguồn (code) hay thực thi tool ghi file ngay lập tức**. Bạn chỉ được phép trả lời lý thuyết, giải thích hoặc đưa ra bản Kế hoạch (Planning) các bước sẽ làm. Chờ đến khi User chốt phương án và ra lệnh "Thực thi đi" thì mới được phép viết/sửa code.
4. **Plan First:** Khi nhận một yêu cầu phức tạp, hãy phân tích và trình bày hướng giải quyết trước khi ghi đè hoặc tạo hàng loạt file.
