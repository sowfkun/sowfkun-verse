# 03. Security & E2EE Standards

*Đây là tập hợp các quy tắc "Luật Thép" dành riêng cho Agent về kiến trúc bảo mật và luồng mã hoá đầu cuối (End-to-End Encryption - E2EE).*

## 1. Kiến trúc Bảo mật & Mã hoá đầu cuối (E2EE)
- **Vị trí Module**: Security là một Cross-Cutting Domain (Khái niệm cắt ngang toàn hệ thống). Các Handler liên quan (như `/handshake`) **BẮT BUỘC** phải được đặt tại `internal/security/presentation/http`. **TUYỆT ĐỐI KHÔNG** được gộp chung module Security vào bên trong các Domain nghiệp vụ (như `tenant`, `user`, `order`).

## 2. Hybrid Encryption Flow (Quy trình mã hoá kết hợp RSA + AES)
Mọi kết nối API (ngoại trừ GET) đều phải được bảo vệ bằng luồng Hybrid Encryption:
1. **Xin Public Key**: Frontend gọi `GET /api/v1/security/public-key` lấy RSA-2048 Public Key của Server.
2. **Tạo Session Key**: Frontend tự sinh ngẫu nhiên một mã khóa AES-256-GCM (Bí mật). Kế tiếp, Frontend dùng RSA Public Key của Server để bọc (mã hoá) AES Key này lại.
3. **Handshake (Bắt tay)**: Frontend gửi chuỗi AES Key đã mã hóa lên `POST /api/v1/security/handshake`. Server sẽ lấy RSA Private Key của mình ra để giải mã, thu được AES Key gốc. Sau đó Server lưu AES Key vào Redis dưới dạng `session:[ID]` và trả về một `Session-ID` cho Frontend.
4. **Bảo vệ Payload (Giao tiếp an toàn)**: Từ thời điểm này, mọi Request (Post/Put/Delete) Frontend gửi lên bắt buộc phải đính kèm `X-Session-ID` trong Header. Đồng thời, toàn bộ Request Body (chứa data JSON thật) phải bị mã hoá thành một chuỗi duy nhất bằng thuật toán AES. 
5. **Middleware xử lý**: Ở phía Server, `PayloadCryptoMiddleware` sẽ chặn các Request này, đọc `X-Session-ID`, lấy AES Key từ Redis ra để giải mã Request. Sau khi các Handler xử lý xong nghiệp vụ, Middleware lại bọc Response bằng AES để trả về một cách an toàn cho Frontend. Không một ai (kể cả Hacker hay các công cụ bắt gói tin) có thể đọc được nội dung JSON thực sự.

## 3. Quản lý RSA Keys an toàn
- **Không dùng file `.pem` tĩnh**: Key RSA **TUYỆT ĐỐI KHÔNG ĐƯỢC** đọc từ file `.pem` vật lý lưu cứng ở ổ đĩa (để tránh rủi ro bảo mật lộ Key qua hệ thống Git).
- **Biến môi trường**: Cặp khóa bắt buộc phải nạp từ biến môi trường (Environment Variables) dưới định dạng Base64 (`RSA_PRIVATE_KEY_BASE64`, `RSA_PUBLIC_KEY_BASE64`).
- **RAM Fallback (Dự phòng)**: Nếu hệ thống không tìm thấy 2 biến môi trường này lúc khởi động, Server phải có cơ chế tự động sinh ra một cặp Key mới lưu tạm trên RAM. Điều này đảm bảo Server luôn khởi động thành công và Dev dễ dàng test mà không cần cung cấp Key thật.

## 4. Debug Mode (Chế độ hỗ trợ phát triển)
- **Cờ Bypass E2EE**: Luồng mã hoá E2EE rất an toàn trên Production nhưng lại gây khó khăn khi Test bằng Postman/Curl. Do đó, `PayloadCryptoMiddleware` bắt buộc phải kiểm tra biến cờ `ENABLE_PAYLOAD_ENCRYPTION` trong file `.env`. 
- Nếu `ENABLE_PAYLOAD_ENCRYPTION=false`, toàn bộ luồng E2EE phải được bypass (bỏ qua), hệ thống sẽ hoạt động theo chuẩn RESTful JSON bình thường.
