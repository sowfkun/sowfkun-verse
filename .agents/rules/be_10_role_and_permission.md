---
trigger: always_on
---

# 10. Role & Permission Standards

*Đây là tập hợp các quy tắc "Luật Thép" dành riêng cho Agent về hệ thống phân quyền (Roles & Permissions) trong Backend.*

## 1. Sử dụng Constant Quyền (Permission Constants)
Tuyệt đối **NGHIÊM CẤM** hành vi hardcode chuỗi định danh quyền (như `"CONFIG_MANAGE"`) trong các layer Presentation, Application hay Infrastructure. 
- Mọi định danh quyền bắt buộc phải được khai báo dưới dạng kiểu dữ liệu `PermissionKey` trong `internal/role/domain/permission_keys.go`.
- Khi cấu hình router tại Presentation Layer, bắt buộc phải truyền constant đã được ép kiểu về chuỗi: `string(domain.PermConfigManage)`.

## 2. Quản lý Route & Phân Quyền API
- **API Ghi dữ liệu (CUD - Create/Update/Delete)**: Bắt buộc phải được bọc qua cả hai lớp Middleware bảo vệ: `middleware.RequireAuth(middleware.RequirePermission(string(domain.PermX))(handler.Y))`.
- **API Đọc dữ liệu (R - Read/Get/View/List)**: Đối với các API truy vấn thông tin để hiển thị ở Client, **TUYỆT ĐỐI KHÔNG** dùng `RequirePermission` nếu không có yêu cầu bảo mật đặc biệt nâng cao. Chỉ cần sử dụng `middleware.RequireAuth` để xác thực người dùng đăng nhập là đủ. điều này cho phép hệ thống "Get để Show" nhanh chóng.

## 3. Quy trình Phân giải Quyền hạn (Permission Scopes Resolution)
- **Quyền hạn của Chủ doanh nghiệp (Owner)**: Khi `isOwner = true`, tài khoản luôn được mặc định gán toàn quyền cao nhất với phạm vi `ALL` (Scope `ALL`) đối với mọi tính năng.
- **Quyền hạn Domain cấu hình**: Các phân hệ quản trị lõi như cấu hình hệ thống (Tag, Role, Tenant, Attribute) sử dụng quyền `CONFIG_MANAGE`. Các tài khoản thông thường nếu được gán vai trò (Role) có chứa quyền này thì vẫn được phép thao tác bình thường.
- **Phân giải Scope**: Đối với người dùng thông thường, Middleware/Service phải truy vấn danh sách Role của người dùng để phân giải ra danh sách `PermissionScope` tương ứng của họ. Nếu người dùng sở hữu nhiều Role chứa các Scope khác nhau cho cùng một quyền, các Scope này sẽ được gộp lại (nếu có Scope `ALL` thì tối giản chỉ giữ `ALL`).
