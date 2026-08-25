# Tài Liệu Đặc Tả Toàn Diện MongoDB Atlas Search Pipeline & Query Builder (Nested Compound & Index Mapping)

Tài liệu này đặc tả toàn bộ quy trình nghiệp vụ (Business Rules), kiến trúc chuyển đổi truy vấn (Query Translation Flow), cấu trúc cây logic lồng nhau (**Nested Compound Tree**), các hàm tiện ích (`AppendOrClause`, `AppendAndClause`), và bảng ánh xạ kiểu dữ liệu Index của hệ thống **MongoDB Atlas Search** trên toàn bộ nền tảng Sowfkun-Verse.

---

## 1. Tổng Quan & Kiến Trúc Atlas Search (Overview & Architecture)

Hệ thống Sowfkun-Verse áp dụng mô hình tìm kiếm phân tách (**Search Engine First**):
- **Truy vấn Danh sách & Đếm (`List`, `Count`)**: Đi qua MongoDB Atlas Search Engine (stage `$search` dựa trên lõi Apache Lucene) để đạt tốc độ phản hồi tính bằng mili-giây trên tập dữ liệu lớn.
- **Truy vấn Đơn lẻ Realtime (`GetByID`, `GetOne`, CUD)**: Truy vấn trực tiếp vào Storage Engine WiredTiger của MongoDB Primary để đảm bảo tính nhất quán tức thì (**Strong Consistency**).

```mermaid
flowchart TD
    A[Client Request / Filter Payload] --> B[Application Layer: UseCase / Query DTO]
    B --> C[Repository Layer: buildQuery]
    C -->|BSON Base Query| D[pkg/database/mongodb: ConvertQueryToAtlasSearch]
    
    subgraph Engine Translation [Bộ Dịch Đệ Quy Atlas Search DSL]
        D --> E{Phân tích Cây Logic}
        E -->|Keywords| F[must: text search on 'kws']
        E -->|$or clause| G[compound.should with minimumShouldMatch: 1]
        E -->|$and clause| H[Gom phẳng vào filter cha]
        E -->|_id / $in / $eq| I[in / equals on 'objectId']
        E -->|Range / Ne / Nin / Exists| J[filter / mustNot clauses]
    end

    Engine Translation -->|Atlas Search DSL Payload| K[MongoDB Aggregation Pipeline: $search]
    K --> L[Lucene Inverted Index Engine]
    L -->|Filtered Documents| M[$sort -> $skip -> $limit -> $project]
    M --> N[Client Paged Response]
```

---

## 2. Quy Trình Chuyển Đổi & Cây Logic Lồng Nhau (Step-by-Step & Nested Compound)

### 2.1 Bảng Ánh Xạ Toán Tử (MQL sang Atlas Search DSL)

| Toán tử MQL (BSON) | Cú pháp Atlas Search DSL (`$search`) | Vị trí trong Compound | Ghi chú & Kiểu Index |
|---|---|---|---|
| `keywords` / `kws` | `{"text": {"path": "kws", "query": ...}}` | `must: [...]` | Field `kws` có `type: "string"` |
| `$or: [ branch1, branch2 ]` | `{"compound": {"should": [...], "minimumShouldMatch": 1}}` | `filter: [...]` | Hỗ trợ unwrap nếu nhánh chỉ có 1 clause đơn |
| `$and: [ clause1, clause2 ]` | Gom phẳng từng clause vào mảng cha | `filter: [...]` | Tính chất kết hợp của phép giao (Associative) |
| `_id: ObjectID` | `{"equals": {"path": "_id", "value": ObjectID}}` | `filter: [...]` | Field `_id` có `type: "objectId"` |
| `_id: {"$in": [OID1, OID2]}` | `{"in": {"path": "_id", "value": [OID1, OID2]}}` | `filter: [...]` | Field `_id` có `type: "objectId"` |
| `field: val` *(Equality)* | `{"equals": {"path": field, "value": val}}` | `filter: [...]` | Field có `type: "token"` hoặc `boolean` |
| `field: {"$in": [A, B]}` | `{"in": {"path": field, "value": [A, B]}}` | `filter: [...]` | Field có `type: "token"` |
| `field: {"$nin": [A, B]}` | `{"in": {"path": field, "value": [A, B]}}` | `mustNot: [...]` | Phủ định của toán tử `in` |
| `field: {"$ne": val}` | `{"equals": {"path": field, "value": val}}` | `mustNot: [...]` | Phủ định của toán tử `equals` |
| `field: {"$exists": true/false}` | `{"exists": {"path": field}}` | `filter` / `mustNot` | Kiểm tra sự tồn tại của trường |
| `field: {"$gte", "$lte", ...}` | `{"range": {"path": field, "gte": ..., "lte": ...}}` | `filter: [...]` | Field có `type: "number"` hoặc `date` |

---

### 2.2 Quy Chuẩn Query Builder Helpers (`AppendOrClause` & `AppendAndClause`)

Để tránh lỗi ghi đè dữ liệu hoặc xung đột giữa `$or` và `$and`, **BẮT BUỘC** sử dụng các helper tại `pkg/database/mongodb/query_builder.go`:

```go
// 1. Gán điều kiện AND thông thường ở Root Level:
baseQuery["status"] = cq.Status
baseQuery["tid"] = cq.TenantID

// 2. Nối mệnh đề OR phức tạp (Tự động gom vào $and nếu query đã có $or trước đó):
ownerOrClause := []bson.M{
    {"_id": bson.M{"$in": objIDs}},
    {"owner_id": bson.M{"$in": cq.CommonQuery.Role.OwnerIDs}},
}
mongodb.AppendOrClause(baseQuery, ownerOrClause)

// 3. Nối mệnh đề AND phức tạp:
mongodb.AppendAndClause(baseQuery, andClauses)

// 4. Xây dựng cây điều kiện con lồng nhau (Sub-Tree):
subBranch := bson.M{"dept": "IT"}
mongodb.AppendOrClause(subBranch, []bson.M{
    {"level": "SENIOR"},
    {"exp_years": bson.M{"$gte": 5}},
})
mongodb.AppendOrClause(baseQuery, []bson.M{subBranch, otherBranch})
```

---

## 3. Đặc Tả Định Nghĩa Search Index Mapping (Index Definitions)

Cấu hình Search Index được quản lý tập trung tại `cmd/indexer/mongo.go`. Mọi collection sử dụng Atlas Search phải tuân thủ chuẩn mapping sau:

```go
SearchIdxs: []mongo.SearchIndexModel{
    {
        Definition: bson.M{
            "mappings": bson.M{
                "dynamic": false, // Tối ưu dung lượng đĩa, chỉ index các trường cần thiết
                "fields": bson.M{
                    "_id":      bson.M{"type": "objectId"}, // Bắt buộc cho lọc _id, IncludeIDs, Scope
                    "kws":      bson.M{"type": "string"},   // Bắt buộc cho Full-Text Search
                    "tid":      bson.M{"type": "token"},    // Tenant ID
                    "status":   bson.M{"type": "token"},    // Enum status
                    "is_del":   bson.M{"type": "boolean"},  // Soft delete flag
                    "c_at":     bson.M{"type": "number"},   // Timestamp phục vụ Range Query
                    "role_ids": bson.M{"type": "token"},    // Mảng ID hoặc chuỗi ID
                    "owner_id": bson.M{"type": "token"},    // Phân quyền Owner
                    "e_hash":   bson.M{"type": "token"},    // Blind Index tìm kiếm Email/Phone
                },
            },
        },
        Options: options.SearchIndexes().SetName("default"),
    },
}
```

---

## 4. Kiểm Soát & Debugging (Logging & Verification)

Khi chạy ứng dụng, hàm `ConvertQueryToAtlasSearch` tự động in log câu query trước và sau khi convert dưới chuẩn **Extended JSON (ExtJSON)** để lập trình viên và Agent dễ dàng đối chiếu:

```text
==================== [ATLAS SEARCH CONVERT] ====================
▶ [1] BEFORE (MQL BSON):
{"tid":"6a7d87ac985cad43a972bf74","is_del":false,"$or":[{"_id":{"$in":[{"$oid":"6a8aa466da00168d9d3dc09c"}]}},{"owner_id":{"$in":["6a8aa466da00168d9d3dc09c"]}}]}

▶ [2] AFTER (ATLAS $SEARCH DSL):
{"index":"default","compound":{"filter":[{"equals":{"path":"tid","value":"6a7d87ac985cad43a972bf74"}},{"equals":{"path":"is_del","value":false}},{"compound":{"should":[{"in":{"path":"_id","value":[{"$oid":"6a8aa466da00168d9d3dc09c"}]}},{"in":{"path":"owner_id","value":["6a8aa466da00168d9d3dc09c"]}}],"minimumShouldMatch":{"$numberInt":"1"}}}]}}

▶ [3] POST MATCH: map[]
=================================================================
```

> **Tiêu chuẩn vàng (Golden Rule)**: `POST MATCH` phải luôn là `map[]` rỗng. Nếu `POST MATCH` có chứa dữ liệu, cần kiểm tra xem trường đó đã được hỗ trợ trong `ConvertQueryToAtlasSearch` và khai báo Index tương ứng hay chưa.
