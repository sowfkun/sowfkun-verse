---
trigger: always_on
---

# 03. Security, Authentication & Authorization Standards

*Đây là tập hợp các quy tắc "Luật Thép" dành riêng cho Agent về xác thực (Authentication), phân quyền (Authorization), và cơ chế E2EE.*

## 1. Xác thực (Authentication)
- **Cơ chế:** Sử dụng JWT token được truyền qua header `Authorization: Bearer <token>`.
- **Middleware phân hệ:**
  - `RequireUserAuth`: Dành riêng cho người dùng Web.
  - `RequireAdminAuth`: Dành riêng cho Admin hệ thống.
  - `RequireMobileAuth`: Dành riêng cho Mobile App.
  - `RequireAuth`: Bản chất là alias trỏ về `RequireUserAuth` để tương thích ngược.
- **Context Injection:** Claims của token sau khi validate thành công bắt buộc phải được inject vào Request Context, truy xuất qua `auth.GetClaimsFromContext(r.Context())`.

## 2. Phân quyền & Quản lý Quyền hạn (Authorization & Permissions)
- **Sử dụng Constant Quyền (Permission Constants):** Tuyệt đối **NGHIÊM CẤM** hardcode chuỗi định danh quyền (như `"CONFIG_MANAGE"`) trong code. Mọi quyền phải khai báo dưới dạng kiểu dữ liệu `PermissionKey` trong `internal/role/domain/permission_keys.go`. Khi cấu hình router, bắt buộc ép kiểu: `string(domain.PermX)`.
- **Quản lý Route & Phân Quyền API (CUD vs R):**
  - **API Ghi dữ liệu (CUD - Create/Update/Delete):** Bắt buộc đi qua cả 2 lớp middleware: `middleware.RequireAuth(middleware.RequirePermission(string(domain.PermX))(handler.Y))`.
  - **API Đọc dữ liệu (R - Read/Get/View/List):** Chỉ cần `middleware.RequireAuth` để xác thực người dùng đăng nhập nhằm hiển thị nhanh (Get to Show), trừ trường hợp yêu cầu bảo mật đặc biệt nâng cao.
- **Cơ chế:** Phân quyền theo vai trò (RBAC) kết hợp phạm vi truy cập (Scopes: `ALL`, `SUBORDINATES`, `SAME_DEPT`, `OWN_ONLY`, `NONE`).
- **Quy trình phân giải Scope:**
  - `GlobalPermissionChecker.ResolveScopes` quét danh sách `RoleIDs` của user từ cache/DB, lấy danh sách `scopes` của mã quyền tương ứng để gộp lại.
  - **Đặc quyền Owner:** Nếu `isOwner = true`, tài khoản luôn được mặc định gán toàn quyền cao nhất với phạm vi `ALL` (Scope `ALL`) đối với mọi tính năng.
  - **Context Injection:** Danh sách scopes giải mã được lưu vào context dưới key `PermissionScopesKey`, truy xuất qua `middleware.GetPermissionScopesFromContext(r.Context())`.

## 3. Mã hoá đầu cuối (E2EE) - Cơ chế rút gọn
- **Vị trí Module:** Các API handshake/security bắt buộc đặt riêng tại `internal/security/`. Không gộp chung vào module khác.
- **Luồng Hybrid Encryption (RSA + AES):**
  - **Handshake:** Client dùng RSA Public Key của Server để mã hoá Session Key AES-256-GCM ngẫu nhiên gửi lên `/handshake`. Server giải mã bằng RSA Private Key và lưu Session Key vào Redis.
  - **Mã hoá payload:** Client gửi request đính kèm `X-Session-ID` trong Header. Request Body (JSON) được mã hoá hoàn toàn bằng AES.
  - **Mã hoá cục bộ Response:** Server chỉ mã hoá trường `data` trong JSON response, giữ nguyên `error_code` và `error_detail` ở dạng Plain Text để Client hiển thị lỗi nhanh.
- **Quản lý Key an toàn:** Không dùng file `.pem` tĩnh. Private/Public key nạp từ Env (`RSA_PRIVATE_KEY_BASE64`, v.v.), nếu thiếu sẽ tự động sinh cặp key ngẫu nhiên lưu trên RAM để test (RAM Fallback).
- **Cờ Bypass:** Debug/Test có thể tắt mã hóa bằng cách cấu hình `ENABLE_PAYLOAD_ENCRYPTION=false` trong `.env`.
