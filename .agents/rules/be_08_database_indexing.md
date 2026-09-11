# BE 08: Database Indexing & Atlas Search

## 1. Atlas Search & Index Definition Mapping
Khi thêm mới thuộc tính (field) vào Entity để dùng cho mục đích Query/Filter/Search qua MongoDB Atlas Search, **BẮT BUỘC** phải:
- Kiểm tra và cập nhật lại Index Template (Atlas Search Index & Standard Index) tại tool Migration (`cmd/indexer/mongo.go`).
- Khai báo Mapping rõ ràng (`dynamic: false`) theo đúng kiểu dữ liệu của Atlas Search:
  - **`_id`**: BẮT BUỘC dùng `bson.M{"type": "objectId"}` nếu collection cần query/filter theo `_id`, `IncludeIDs` hoặc phân quyền Owner qua Search Engine.
  - **IDs / Enums / Hashes**: Dùng `bson.M{"type": "token"}` (ví dụ: `tid`, `owner_id`, `role_ids`, `status`, `e_hash`).
  - **Text Search (`kws`)**: Dùng `bson.M{"type": "string"}`.
  - **Boolean Flags**: Dùng `bson.M{"type": "boolean"}` (ví dụ: `is_del`, `is_owner`).
  - **Timestamps / Numbers**: Dùng `bson.M{"type": "number"}` (ví dụ: `c_at`, `u_at`, `amount`).
- Thêm cảnh báo `// ⚠️ WARNING: THIS ENTITY USES ATLAS SEARCH...` ngay trên struct của Entity để ghi chú.

---

## 2. Text Search Optimization
Tất cả các text search phải được gom về 1 field duy nhất là `kws` (Keywords array). Tại hàm Add/Update của Repository, dùng tiện ích `pkg/utils/text.BuildKeywords()` để chuẩn hóa tiếng Việt, tách từ, loại bỏ trùng lặp trước khi lưu. Atlas Search chỉ index field `kws` này cho mục đích text search.

---

## 3. Query Building Standards (AppendOrClause & AppendAndClause)
Khi xây dựng BSON query tại hàm `buildQuery` của Repository:
- **Điều kiện thông thường (AND ở Root)**: Gán trực tiếp vào map `baseQuery["field"] = val`.
- **Mệnh đề OR phức tạp**: **BẮT BUỘC** gọi `mongodb.AppendOrClause(baseQuery, orClauses)`.
- **Mệnh đề AND phức tạp**: **BẮT BUỘC** gọi `mongodb.AppendAndClause(baseQuery, andClauses)`.
- **Cây điều kiện con lồng nhau (Sub-tree)**: Tạo `subQuery := bson.M{...}` nội bộ, gọi `AppendOrClause` / `AppendAndClause` ngay trên `subQuery` đó, sau đó mới nạp vào danh sách nhánh của query cha.
- **TUYỆT ĐỐI KHÔNG** tự tay khởi tạo hoặc gán đè `baseQuery["$and"]` / `baseQuery["$or"]` thủ công nhằm tránh gây mất dữ liệu hoặc xung đột logic.

---

## 4. Cơ Chế Chuyển Đổi Tự Động (ConvertQueryToAtlasSearch & Nested Compound)
- Hàm `mongodb.ConvertQueryToAtlasSearch` tự động dịch cây BSON sang Atlas Search DSL:
  - `$or` $\rightarrow$ Tự động chuyển thành `compound: { should: [...], minimumShouldMatch: 1 }` và gắn vào `filter` của compound cha.
  - `$and` $\rightarrow$ Tự động gom phẳng (flatten) các điều kiện vào `filter` chung của compound cha.
  - `_id` / `$in` ObjectIDs $\rightarrow$ Chuyển thành toán tử `in` / `equals` trực tiếp trong `$search`.
  - `$nin`, `$ne`, `$exists`, range (`$gte`, `$lte`, `$gt`, `$lt`) $\rightarrow$ Chuyển thành các mệnh đề `filter` hoặc `mustNot` tương ứng.
- **Mục tiêu tối thượng (100% In-Engine Search)**: Tất cả các điều kiện lọc thông thường, phân quyền và text search phải được ăn trọn vẹn trong `$search` stage, giữ cho `postMatchFilter` luôn rỗng (`map[]`) để không tốn tài nguyên DB chính.

---

## 5. Standard TTL Expired Index (`exp_ref`) cho Soft Delete
- Mọi collection kế thừa `BaseEntity` đều được cấu hình Standard TTL Index trên trường `exp_ref` tại `cmd/indexer/mongo.go`:
  - **Index Name**: `exp_ref_ttl_idx`
  - **Options**: `SetExpireAfterSeconds(0)`, `SetPartialFilterExpression(bson.M{"is_del": true})`
- **Nguyên tắc an toàn**: Chỉ kích hoạt TTL khi document có `is_del = true` và trường `exp_ref` (kiểu BSON Date UTC) mang giá trị cụ thể (thường được sinh qua `coreDomain.NewDeleteModelWith3MonthsTTL(actor, trackingID)`). Các document đang hoạt động (`is_del = false` hoặc `exp_ref = nil`) hoàn toàn không bao giờ bị ảnh hưởng.
