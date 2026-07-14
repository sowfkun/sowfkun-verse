# 04. Pkg & Shared Libraries Standards

*Đây là bộ quy tắc kiểm soát tính "sạch" và "độc lập" của thư mục `pkg/`, đảm bảo thư mục này luôn là một thư viện dùng chung (Shared Library) hoàn hảo, có thể tái sử dụng ở bất kỳ dự án nào khác.*

## 1. Nguyên tắc "Agnostic" (Độc lập với nghiệp vụ)
Thư mục `pkg/` là nơi chứa các thư viện hạ tầng (Database, Cache, MQ, Security) và các tiện ích dùng chung. Vì vậy, **TUYỆT ĐỐI KHÔNG ĐƯỢC PHÉP** để lọt bất kỳ logic, Entity, hay Constant nào liên quan đến nghiệp vụ (Domain-specific) vào trong thư mục này (ví dụ: `Order`, `Product`, `Subscription`, v.v.).

## 2. Các ngoại lệ được chấp nhận (Platform Concepts)
Trong một kiến trúc hệ thống lớn (đặc biệt là Multi-Tenant SaaS), sẽ có một số khái niệm trông có vẻ giống Domain nhưng thực chất là **Khái niệm cốt lõi của nền tảng (Platform/System Concepts)**. Những khái niệm này **ĐƯỢC PHÉP** tồn tại trong `pkg/`:

1. **`TenantID` (Định danh doanh nghiệp)**: 
   - Xuất hiện trong `CommonCommand`, `CommonQuery`, hoặc `QueryBuilder`.
   - Lý do: Đây là cột sống của kiến trúc Data Isolation (Cách ly dữ liệu). Mọi truy vấn DB đều phải ép buộc gắn `TenantID` vào để đảm bảo Row-Level Security, do đó hạ tầng DB ở `pkg/` bắt buộc phải biết đến khái niệm này.

2. **`Actor` / `ActorType` (Định danh người thao tác)**:
   - Xuất hiện trong `BaseEntity` (dùng cho `CreatedBy`, `LastUpdatedBy`).
   - Lý do: Đây không phải là Domain User (người dùng thực tế với email, password), mà là khái niệm phục vụ cho **Audit Trail (Lưu vết hệ thống)**. Actor có thể là một `USER` hoặc một tiến trình ngầm `SYSTEM`. Hệ thống lưu vết ở `pkg/` cần biết khái niệm này để ghi log thay đổi dữ liệu.

## 3. Quy tắc kiểm tra (Checklist)
Bất cứ khi nào Agent tạo một file mới trong thư mục `pkg/`, bắt buộc phải tự hỏi:
> *"Nếu mình copy file này sang một dự án làm về ngành nghề hoàn toàn khác (ví dụ từ EdTech sang E-commerce), file này có bị báo lỗi compile vì dính dáng tới các Struct nghiệp vụ cũ hay không?"*
Nếu câu trả lời là CÓ, thì **cấm** đưa file đó vào `pkg/`. Phải đưa nó vào `internal/[domain_name]/`.
