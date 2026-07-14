# 02. Caching and Redis Standards

*Đây là tập hợp các quy tắc "Luật Thép" dành riêng cho Agent về quản lý bộ nhớ đệm (Caching) và thao tác với Redis.*

## 1. Quản lý Redis Keys (Registry Pattern)
Tuyệt đối **NGHIÊM CẤM** hành vi nối chuỗi cứng (hardcode string concatenation) như `key := "session:" + id` rải rác ở khắp các file Handler hay Middleware. Bắt buộc phải sử dụng **Key Builder / Key Registry**:
- **Cấp độ Hệ thống (Cross-Cutting Concerns)**: Các Key dùng chung cho toàn bộ App (như Session, Rate Limit) **BẮT BUỘC** phải được định nghĩa trong `pkg/cache/redis/keys.go`.
- **Cấp độ Domain (Nghiệp vụ)**: Các Key liên quan trực tiếp đến một Domain cụ thể (như `tenant:profile:123`) **BẮT BUỘC** phải được định nghĩa trong thư mục hạ tầng của Domain đó: `internal/[domain_name]/infrastructure/cache/keys.go`.

## 2. Rate Limiting
- **Cơ chế**: Sử dụng thuật toán **Token Bucket** được thực thi nguyên tử (Atomic) qua Lua Script trên Redis.
- **Connection**: Dùng một instance Redis độc lập hoặc một Pool riêng cho Rate Limit (thông qua `redisManager.GetClient("rate_limit")`), không dùng chung lẫn lộn với General Cache nhằm tránh việc tắc nghẽn (bottleneck) làm nghẽn toàn bộ hệ thống.
