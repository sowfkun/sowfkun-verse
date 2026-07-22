# Global Agent Rules

Mọi Agent khi hoạt động trong dự án này **bắt buộc** phải tuân thủ các quy tắc toàn cục dưới đây. 
*(Lưu ý: Các quy tắc chuyên sâu cho từng phân hệ như Backend, Frontend, Mobile đã được quản lý và tự động kích hoạt thông qua cơ chế **Skills** trong thư mục `.agents/skills/`. Agent sẽ tự động nạp chúng dựa theo ngữ cảnh của task).*

## Nguyên tắc Toàn cục (Global Principles)
Dù bạn là Agent làm ở phân hệ nào, bạn cũng phải tuyệt đối tuân thủ các nguyên tắc sau:

1. **Hiểu Bối Cảnh & Cần Xác Nhận:** Phải hiểu bối cảnh dự án rõ ràng trước khi thực thi. Luôn lập kế hoạch/phân tích và **phải có sự confirm (xác nhận) của người dùng** thì mới được phép bắt đầu viết code.
2. **On-Premise First (Không Hardcode):** Toàn bộ code FE và BE đều theo hướng On-Premise. Tuyệt đối KHÔNG được phép hardcode (logo, màu sắc thương hiệu, external URLs, database, v.v.). Mọi thứ phải cấu hình qua biến môi trường hoặc biến CSS.
3. **Multi-tenant System:** Toàn bộ hệ thống phải tuân thủ kiến trúc Multi-tenant (hỗ trợ nhiều khách hàng độc lập).
4. **Chuẩn hóa Thời Gian (UTC):** Tất cả khi làm việc với thời gian (lưu trữ, xử lý, payload) đều bắt buộc phải quy về chuẩn **UTC**.
5. **Tuân thủ Kiến trúc Chuẩn:** Phải làm theo quy tắc chung của toàn hệ thống (Golden Standard). Không tự ý sáng tạo kiến trúc, design pattern mới hay sử dụng thư viện lạ nếu không có sự cho phép.
6. **Trả lời Câu hỏi Ngắn gọn:** Đối với những prompt dạng câu hỏi hoặc cần tham khảo, **phải trả lời/thảo luận chứ không được nhảy vào code ngay**. Câu trả lời cần ngắn gọn, súc tích, vừa đủ hiểu để không làm tốn token.
7. **Sử dụng Codegraph:** Sử dụng tool codegraph để hiểu bối cảnh và luồng code khi cần thiết trước khi thực thi.