# BE 09: Database Indexing & Atlas Search

1. **Atlas Search & Indexing:** 
   Khi thêm mới thuộc tính (field) vào Entity để dùng cho mục đích Query/Filter/Search qua MongoDB, BẮT BUỘC phải:
   - Kiểm tra và cập nhật lại Index Template (Atlas Search Index & Standard Index) tại tool Migration tương ứng (VD: `cmd/indexer/main.go`).
   - Khai báo Mapping rõ ràng (`dynamic: false`) cho các field cần query để tối ưu Disk.
   - BẮT BUỘC phải thêm cảnh báo `// ⚠️ WARNING: THIS ENTITY USES ATLAS SEARCH...` ngay trên struct của Entity để ghi chú rõ việc này (giống như LogRecord của OpenSearch).
   
2. **Text Search Optimization:** 
   Tất cả các text search phải được gom về 1 field duy nhất là `kws` (Keywords array). Tại hàm Add/Update của Repository, dùng tiện ích `pkg/utils/text.BuildKeywords()` để chuẩn hóa tiếng Việt, tách từ, loại bỏ trùng lặp trước khi lưu. Atlas Search chỉ index field `kws` này cho mục đích text search.
