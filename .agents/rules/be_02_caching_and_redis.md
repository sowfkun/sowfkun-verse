---
trigger: always_on
---

# 02. Caching and Redis Standards

*Đây là tập hợp các quy tắc "Luật Thép" dành riêng cho Agent về quản lý bộ nhớ đệm (Caching) và thao tác với Redis.*

## 1. Quản lý Redis Keys (Registry Pattern)
Tuyệt đối **NGHIÊM CẤM** hành vi nối chuỗi cứng (hardcode string concatenation) như `key := "session:" + id` rải rác ở khắp các file Handler hay Middleware. Bắt buộc phải sử dụng **Key Builder / Key Registry**:
- **Cấp độ Hệ thống (Cross-Cutting Concerns)**: Các Key dùng chung cho toàn bộ App (như Session, Rate Limit) **BẮT BUỘC** phải được định nghĩa trong `pkg/cache/redis/keys.go`.
- **Cấp độ Domain (Nghiệp vụ)**: Các Key liên quan trực tiếp đến một Domain cụ thể (như `tenant:profile:123`) BẮT BUỘC phải được định nghĩa trong thư mục hạ tầng của Domain đó: `internal/[domain_name]/infrastructure/cache/` (đặt trong package `cache` độc lập để tránh lỗi vòng lặp import (import cycle) trong Go).
  - Đối với cache của entity thì định nghĩa trong `entity_cache.go` (ví dụ: `tenant/infrastructure/cache/entity_cache.go`).
  - Đối với cache về nghiệp vụ của domain không liên quan đến entity thì định nghĩa trong `business_cache.go` (ví dụ: `auth/infrastructure/cache/business_cache.go`).

## 2. Rate Limiting
- **Cơ chế**: Sử dụng thuật toán **Token Bucket** được thực thi nguyên tử (Atomic) qua Lua Script trên Redis.
- **Connection**: Dùng một instance Redis độc lập hoặc một Pool riêng cho Rate Limit (thông qua `redisManager.GetClient("rate_limit")`), không dùng chung lẫn lộn với General Cache nhằm tránh việc tắc nghẽn (bottleneck) làm nghẽn toàn bộ hệ thống.

## 3. Kháng lỗi Cache (Cache Miss & Volatility)
- **Redis KHÔNG phải là Source of Truth**: Dự án đang sử dụng gói Redis Free (có giới hạn dung lượng và tự động eviction/xóa key cũ). Vì vậy, **TUYỆT ĐỐI KHÔNG** được coi Redis là nơi lưu trữ dữ liệu vĩnh viễn (Persistent Storage).
- **Cơ chế Fallback**: Bất kỳ logic nghiệp vụ nào đọc dữ liệu từ Redis đều **BẮT BUỘC** phải có cơ chế Fallback (tự động truy vấn xuống Database (MongoDB) nếu Cache bị miss hoặc Redis chết ngang). Sự cố mất dữ liệu trên Redis tuyệt đối không được phép làm sập (Crash) hoặc gián đoạn chức năng của App.

## 4. Thiết kế Cache Model / Cache DTO & Đồng bộ Trường (Field Synchronization)
Khi sử dụng Cache Model/DTO (ví dụ: `TenantCacheModel`) thay vì lưu trực tiếp Entity gốc để giảm dung lượng Redis:
- **Bắt buộc viết Comment cảnh báo** tại định nghĩa hàm trong Repo (ví dụ: `GetCachedByID`): Nhắc nhở rõ ràng rằng hàm này trả về thực thể dựng lại từ Cache DTO (có thể bị khuyết một số trường không được cache).
- **Quy tắc Kiểm tra tại nơi gọi:** Lập trình viên hoặc Agent khi gọi các hàm Get Cached **BẮT BUỘC** phải kiểm tra xem các trường dữ liệu mình chuẩn bị sử dụng đã được map trong Cache DTO hay chưa. Nếu thiếu:
  1. Tiến hành cập nhật Cache DTO để bổ sung trường đó.
  2. Hoặc sử dụng hàm Get trực tiếp từ Database (`GetByID`, `GetByEmail`) kèm theo Projection phù hợp nếu trường đó quá lớn và không phù hợp để cache.

