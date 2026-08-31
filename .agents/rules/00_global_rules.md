---
trigger: always_on
---

# Global Agent Rules (Nguyên Tắc Toàn Cục)

Mọi Agent khi hoạt động trong dự án này **bắt buộc** phải tuân thủ các quy tắc toàn cục dưới đây. 

---

## Nguyên tắc Toàn cục (Global Principles)

1. **Hiểu Bối Cảnh & Cần Xác Nhận:** Phải hiểu bối cảnh dự án rõ ràng trước khi thực thi. Luôn lập kế hoạch/phân tích và **phải có sự confirm (xác nhận) của người dùng** thì mới được phép bắt đầu viết code. *(Ngoại lệ: Đối với những chỉnh sửa thực sự rất dễ hoặc chỉ cần thay đổi 1-2 dòng code thì được phép sửa đổi trực tiếp mà không cần viết plan).*
2. **On-Premise First (Không Hardcode):** Toàn bộ code FE và BE đều theo hướng On-Premise. Tuyệt đối KHÔNG được phép hardcode (logo, màu sắc thương hiệu, external URLs, database, v.v.). Mọi thứ phải cấu hình qua biến môi trường hoặc biến CSS.
3. **Multi-tenant System:** Toàn bộ hệ thống phải tuân thủ kiến trúc Multi-tenant (hỗ trợ nhiều khách hàng độc lập).
4. **Chuẩn hóa Thời Gian (UTC):** Tất cả khi làm việc với thời gian (lưu trữ, xử lý, payload) đều bắt buộc phải quy về chuẩn **UTC**.
5. **Tuân thủ Kiến trúc Chuẩn:** Phải làm theo quy tắc chung của toàn hệ thống (Golden Standard). Không tự ý sáng tạo kiến trúc, design pattern mới hay sử dụng thư viện lạ nếu không có sự cho phép.
6. **Trả lời Câu hỏi Ngắn gọn:** Đối với những prompt dạng câu hỏi hoặc cần tham khảo, **phải trả lời/thảo luận chứ không được nhảy vào code ngay**. Câu trả lời cần ngắn gọn, súc tích, vừa đủ hiểu để không làm tốn token.
7. **CodeGraph First (Bắt buộc khi Bắt đầu Task / Phiên mới):** Tuyệt đối KHÔNG được grep mò hay đọc file đoán mò khi tìm hiểu luồng code hoặc tìm kiếm symbols/hàm/struct. Hành động đầu tiên khi nhận bất kỳ task nào là **BẮT BUỘC phải chạy `codegraph explore "<symbol/tính năng>"`** để nạp verbatim source và call-graph chính xác trước khi lập plan hoặc viết code.
8. **Tối ưu Token & Ngắn gọn (Zero-Waste):** Khi đọc file phải dùng StartLine và EndLine chính xác, KHÔNG đọc toàn bộ file. Trong quá trình lên kế hoạch (implementation_plan.md), CHỈ mô tả high-level logic hoặc hướng giải quyết bằng văn bản (text), TUYỆT ĐỐI KHÔNG viết mã nguồn (raw code) vào file plan để tránh lãng phí token. Các câu trả lời sau khi xong một việc thì báo cáo ngắn gọn đã làm gì, kết quả là gì, không cần giải thích. Chỉ những câu hỏi mới cần trả lời chi tiết.
9. **Cơ chế Cập nhật Tối ưu (Dirty Check & Optional Update):** Khi thực hiện các API cập nhật dữ liệu (Update/Patch):
   - **Phía Frontend (Client):** Chỉ gửi lên API các trường dữ liệu thực sự có sự thay đổi (dirty check) và hợp lệ. Không gửi các trường rỗng/null/không đổi lên API để tiết kiệm tài nguyên mạng và tránh ghi đè dữ liệu cũ ngoài ý muốn. Nếu không có thay đổi nào hiệu dụng, nút Lưu/Submit bắt buộc phải bị vô hiệu hóa (disabled).
   - **Phía Backend (Server):** Tầng Presentation (DTO) định nghĩa các trường dữ liệu dưới dạng con trỏ (pointer) hoặc struct tùy biến để phân biệt giữa việc "trường có truyền dữ liệu lên nhưng rỗng" và "không truyền trường đó lên" (bằng `nil`). Tầng Application (UseCase) chỉ cập nhật DB với các trường khác `nil` và khác với giá trị hiện tại của DB. Nếu không có thay đổi hiệu dụng nào, bỏ qua việc cập nhật DB để tối ưu hóa hiệu suất (Skip DB write).
10. **Không tự ý Commit Code:** Tuyệt đối KHÔNG tự ý thực hiện commit code lên Git trừ khi nhận được yêu cầu xác nhận rõ ràng của người dùng (ví dụ: "commit đi").
11. **Không chạy `go test`:** Tuyệt đối KHÔNG chạy lệnh `go test` hoặc `go test ./...` trong toàn bộ dự án. Để kiểm tra tính đúng đắn và tính toàn vẹn của mã nguồn sau khi sửa đổi, CHỈ sử dụng lệnh biên dịch `go build ./...`.
12. **Kiểm Soát Sở Hữu Multi-Tenant (Tenant Data Ownership & Projection Safety):**
    - **Tầng Application (UseCase/Query):** Khi truy vấn đọc 1 bản ghi hoặc thực hiện thao tác CUD (Create/Update/Delete) theo ID (`GetByID`, `GetByCode`, `GetOne`, `Update`, `Delete`), **BẮT BUỘC** phải kiểm tra quyền sở hữu Tenant: `if entity == nil || entity.TenantID != q.TenantID { return nil, errors.New(coreDomain.ErrNotFound) }` để ngăn ngừa tuyệt đối việc rò rỉ hoặc can thiệp dữ liệu chéo giữa các Tenant độc lập.
    - **Tầng Infrastructure (Repository/Projection):** Khi thực thi câu lệnh có `projection` xuống Database, Repository **BẮT BUỘC** phải luôn tự động gán kèm `"tid": 1` và `"is_del": 1` vào projection map để các tầng UseCase và Soft-delete checker luôn có đủ dữ liệu xác thực, tránh việc `entity.TenantID` bị rỗng dẫn tới phán đoán sai.
13. **Kỹ năng Phản biện & Bảo vệ Quy chuẩn (Critical Thinking & Rule Defense):** Khi nhận thấy yêu cầu của người dùng chưa hợp lý (về mặt logic, kiến trúc, bảo mật, hiệu năng) hoặc vi phạm bất kỳ nguyên tắc/quy chuẩn nào của dự án:
    - **TUYỆT ĐỐI KHÔNG** thực hiện ngay một cách mù quáng.
    - **BẮT BUỘC** phải dừng lại, chỉ ra điểm bất hợp lý/vi phạm và phản biện rõ ràng lý do, đồng thời đề xuất giải pháp thay thế tối ưu hơn.
    - **CHỈ ĐƯỢC PHÉP** thực hiện sau khi người dùng đã xem xét và xác nhận (confirm) lại rõ ràng.
14. **Zero-Trust Egress & Outbound Communication Protection:** Mọi thao tác gửi HTTP/HTTPS request ra ngoài Internet (gửi Email Resend/SMTP, Webhook Dispatcher, SMS OTP, Telegram Bot Alerts, Third-party APIs) **TUYỆT ĐỐI KHÔNG** được gọi trực tiếp bằng `http.DefaultClient` hay các thư viện HTTP thuần tự do từ Data/App Server. **BẮT BUỘC** phải định tuyến qua Egress Gateway Server (Server 3) thông qua `pkg/egress.Client` hoặc `egress.NewHTTPClient()` nhằm đảm bảo phòng chống tấn công SSRF, bảo vệ máy chủ cô lập Zero-Trust, và tập trung quản lý hạn mức/retry/logging an toàn.
