# Tài Liệu Đặc Tả Quy Trình Phân Trang & Lọc Dữ Liệu Nâng Cao (Pagination & Advanced Filtering Specification)

Tài liệu này mô tả chi tiết cơ chế phân trang kết hợp (Hybrid Pagination), cấu trúc dữ liệu API của Backend, danh sách các thành phần giao diện Frontend của List, cùng các dữ liệu mẫu props đi kèm để đảm bảo tính đồng bộ trên toàn dự án.

---

## 1. Tổng Quan & Sơ Đồ Sequence (Overview & Sequence Diagram)

Hệ thống áp dụng cơ chế phân trang kết hợp (Offset-based cho các trang đầu và Cursor-based cho Deep Paging) để bảo vệ tài nguyên cơ sở dữ liệu khi truy vấn sâu (vượt quá 10,000 bản ghi), kết hợp với bộ lọc thuộc tính Capsule Pill.

```mermaid
sequenceDiagram
    autonumber
    actor Client as Frontend (DataTable)
    participant BE as Backend Server
    participant DB as MongoDB

    alt Trang dữ liệu nhỏ / Shallow Paging (Page * Size <= 10000)
        Client->>BE: GET /api/v1/resource?page=5&size=10&status=ACTIVE
        BE->>DB: Query với Skip(40) & Limit(10) + CountDocuments()
        DB-->>BE: Trả về 10 Items & Total = 100
        BE-->>Client: Response: BaseResponse { Data: PagedResponse { Total: 100, Items: [...], NextCursor: "eyJmaWVsZCI...", PrevCursor: "...", HasMore: true, HasPrev: true } }
        Note over Client: Hiển thị bộ phân trang số (1, 2, 3... 10) và ô nhảy trang nhanh
    else Deep Paging hoặc Duyệt Cursor (search_after / search_before)
        Client->>BE: GET /api/v1/resource?search_after=eyJmaWVsZCI6ImNfYXQiLCJ2YWwiOjE3ODU1NDI0MDAwMDAsImlkIjoiNjZiNDVhN2IxYzQzIn0&size=10
        Note over BE: Decode token Base64 -> CursorData {Field: "c_at", Val: 1785542400000, ID: "66b45a7b1c43"}
        Note over BE: Kiểm tra Whitelist Sort & Range Conflict Check
        BE->>DB: Query compound cursor: $or: [{c_at: {$lt: 1785542400000}}, {c_at: 1785542400000, _id: {$lt: ID}}] & Limit(11) (Không Count)
        DB-->>BE: Trả về 11 Items
        Note over BE: Trim items về 10, gán Total = -1, HasMore = true, HasPrev = true, sinh NextCursor & PrevCursor mới
        BE-->>Client: Response: BaseResponse { Data: PagedResponse { Total: -1, Items: [10 items], NextCursor: "eyJmaWVsZCI...", HasMore: true, HasPrev: true } }
        Note over Client: Total = -1 -> Chuyển sang thanh điều hướng [⬅ Trước] và [Tiếp ➡]
    end
```

---

## 2. Phân Vùng Trách Nhiệm Của Frontend (Frontend Responsibilities & UI/UX Layout)

Frontend đảm nhiệm việc dựng giao diện, xử lý state cục bộ, thực hiện kiểm tra biên Client-side và định hình các cấu phần giao diện (UI Components) của List.

### 2.1 Các Thành Phần Của Một Giao Diện List Phía Frontend
Một trang danh sách dữ liệu (List page) hoàn chỉnh bao gồm 4 cấu phần chính:
1. **Thanh tìm kiếm (SearchBar):** Ô input rộng tối đa `320px` với biểu tượng kính lúp, hỗ trợ debounce tìm kiếm text.
2. **Hàng bộ lọc (FilterRow):** Nằm ngay dưới SearchBar, chứa các nút lọc dạng capsule nhỏ gọn (`Filter Pill Badge` cao `38px`):
   * **MultiSelect (Lọc mảng - Query IN):** Click hiển thị checkbox popover phủ đè lên UI, hỗ trợ cập nhật nhãn động (ví dụ: `Vai trò: Admin, Owner`) và nút clear `x` nhanh.
   * **DateRangePicker (Lọc khoảng ngày):** Click mở popover chứa datetime pickers, hỗ trợ lưu trữ giờ UTC dưới dạng timestamp.
3. **Bảng dữ liệu (DataTable):** Grid hiển thị thông tin gồm:
   * Trình quản lý ẩn hiện cột (⚙️ Settings SVG Icon).
   * Co giãn kích thước cột (Resize) bù trừ tỷ lệ zoom `scaleRef`.
   * Tràn chữ bảo vệ (`truncate` và `min-w-0`).
4. **Phần phân trang (Pagination Footer):** Bộ điều hướng cuối bảng:
   * Bộ chevron chuyển trang trước/sau.
   * Dropdown chọn kích thước trang (`Select` size: 10, 30, 50).
   * Ô nhảy trang nhanh (Page Jump Input) kiểm tra biên chặn cứng `page * size <= 10000`.

### 2.2 Đặc Tả TypeScript Props Chuẩn Của Các Thành Phần Frontend

```typescript
// 1. SearchBar Component Props
export interface SearchBarProps {
  placeholder?: string;
  onChange: (value: string) => void;
  debounceMs?: number; // Mặc định: 300ms
}

// 2. MultiSelect (Filter Pill) Component Props
export interface MultiSelectOption {
  value: string; // Raw ID hoặc Enum (VD: "ACTIVE", "usr-admin-01")
  label: string; // Tên hiển thị (VD: "Hoạt động", "Quản trị viên")
}

export interface MultiSelectProps {
  label: string;                  // Tên thuộc tính hiển thị ở Pill (VD: "Trạng thái")
  options: MultiSelectOption[];
  value: string[];                // Danh sách ID/Enum đang chọn
  onChange: (newValue: string[]) => void;
  containerClassName?: string;
  allowSelectAll?: boolean;       // Tự động có tùy chọn "Tất cả" - Mặc định: true
}

// 3. DateRangePicker (Filter Pill) Component Props
export interface DateRangeValue {
  from: number; // Unix timestamp bằng mili-giây chuẩn UTC (VD: 1785542400000)
  to: number;   // Unix timestamp bằng mili-giây chuẩn UTC
}

export interface DateRangePickerProps {
  label: string;
  value: DateRangeValue;
  onChange: (val: DateRangeValue) => void;
}

// 4. Cấu hình Filter Item trong DataTable
export interface AvailableFilterItem {
  id: string;        // Khớp với Column.key (VD: 'c_at', 'status', 'owner_id')
  label?: string;    // Tùy chọn: Tự động kế thừa column.header nếu để trống
  visible?: boolean; // Trạng thái hiển thị mặc định
  component: React.ReactNode;
}

// 5. Cấu hình Column Schema trong DataTable
export interface Column<T> {
  key: string;
  header: string;
  initialWidth?: number;
  type?: 'text' | 'title-subtitle' | 'double-text' | 'badge';
  visible?: boolean;
  isPrimary?: boolean;
  getSubtitle?: (item: T) => string | undefined;
  getIndex?: (item: T) => string | number | undefined;
  getLine2?: (item: T) => string | undefined;
  getBadgeVariant?: (val: any) => BadgeVariant;
  render?: (item: T) => React.ReactNode;
}

// 6. DataTable Component Props (Tích hợp trọn bộ Toolbar, Settings, Grid & Pagination)
export interface DataTableProps<T> {
  columns: Column<T>[];
  data: T[];
  total: number;
  page: number;
  size: number;
  hasMore?: boolean;
  onPageChange?: (newPage: number) => void;
  onSizeChange?: (newSize: number) => void;
  onSearchChange?: (val: string) => void;
  searchPlaceholder?: string;
  
  // Bộ lọc tương tác (Capsule Filter Pills)
  availableFilters?: AvailableFilterItem[];
  filterComponent?: React.ReactNode;
  
  // Nút hành động chính (Dùng <AddButton />)
  actionComponent?: React.ReactNode;
  
  // Tùy chọn ẩn/hiện thành phần
  hideSearch?: boolean;          // Ẩn thanh tìm kiếm (SearchBar)
  hidePagination?: boolean;      // Ẩn thanh phân trang (Pagination Footer)
  hideColumnSettings?: boolean;  // Ẩn nút cài đặt hiển thị (⚙️ Settings)
  hideFilterRow?: boolean;       // Ẩn hàng bộ lọc (FilterRow)
  hideAction?: boolean;          // Ẩn nút hành động (actionComponent)

  // Callback nhận kết quả cấu hình từ TableSettingsModal
  onSettingsChange?: (settings: TableSettingsResult) => void;
}
```

### 2.3 Cấu Hình Ẩn Hiện Các Thành Phần (Component Visibility Options)

Để tối ưu không gian hiển thị và đáp ứng linh hoạt các nghiệp vụ khác nhau (ví dụ: màn hình mini-list, xem nhanh không phân trang, hoặc danh sách tĩnh không tìm kiếm), `DataTable` hỗ trợ các props tuỳ chọn ẩn hiện sau:

* **`hideSearch` (boolean):** Khi nhận giá trị `true`, thanh tìm kiếm (`SearchBar`) sẽ bị ẩn khỏi giao diện.
* **`hidePagination` (boolean):** Khi nhận giá trị `true`, phần phân trang cuối bảng (`Pagination Footer`) bao gồm cả dropdown size và ô page jump sẽ bị ẩn hoàn toàn.
* **`hideColumnSettings` (boolean):** Khi nhận giá trị `true`, biểu tượng cài đặt hiển thị bảng (Sliders Icon) sẽ không hiển thị.
* **`hideFilterRow` (boolean):** Khi nhận giá trị `true`, hàng chứa `availableFilters` (hoặc `filterComponent`) sẽ bị ẩn.
* **`hideAction` (boolean):** Khi nhận giá trị `true`, nút hành động (`actionComponent`) sẽ bị ẩn khỏi giao diện.


---

## 3. Phân Vùng Trách Nhiệm Của Backend (Backend Responsibilities & API Model)

Backend **chỉ cần chịu trách nhiệm trả về đúng mô hình dữ liệu (Model)** theo đặc tả JSON đã chuẩn hóa. Backend không cần quan tâm đến cách thức render giao diện hay vị trí hiển thị của các nút bấm trên Frontend.

### 3.1 Cấu Trúc Model JSON Trả Về Chuẩn (Unified API Response Model)
Mọi API danh sách phía Backend bắt buộc phải trả về dữ liệu thành công (`SUCCESS`) bọc trong Generic BaseResponse dưới định dạng JSON sau:

```json
{
  "data": {
    "items": [
      {
        "id": "emp-1",
        "name": "Nhân viên số 1",
        "email": "employee.1@verse.com",
        "role": "OWNER",
        "c_at": 1785542400000,
        "u_at": 1785542400000,
        "is_del": false
      }
    ],
    "total": 100,      // Trả về -1 nếu là chế độ Cursor (Deep Paging)
    "page": 1,         // Trang hiện tại
    "size": 10,        // Số lượng item trên một trang
    "has_more": true,  // Cờ báo hiệu còn dữ liệu trang sau không
    "has_prev": false, // Cờ báo hiệu còn dữ liệu trang trước không
    "next_cursor": "eyJmaWVsZCI6ImNfYXQiLCJ2YWwiOjE3ODU1NDI0MDAwMDAsImlkIjoiNjZiNDVhN2IxYzQzIn0", // Base64 URL-safe token
    "prev_cursor": ""  // Base64 URL-safe token
  },
  "error_code": "SUCCESS",
  "error_detail": ""
}
```

### 3.2 Đặc Tả Tầng Go DTOs & Cursor Engine (Backend Core DTOs)

#### 1. Model PagedResponse
```go
package dto

// PagedResponse là model phân trang dùng chung cho mọi API List trong hệ thống
type PagedResponse[T any] struct {
	Total      int64  `json:"total" example:"100"`       // Tổng số bản ghi (Trả về -1 nếu dùng cursor)
	Page       int    `json:"page" example:"1"`          // Trang hiện tại
	Size       int    `json:"size" example:"10"`         // Số lượng bản ghi trên một trang
	Items      []T    `json:"items"`                     // Danh sách dữ liệu trang
	NextCursor string `json:"next_cursor,omitempty"`     // Con trỏ Base64 lấy trang tiếp theo
	PrevCursor string `json:"prev_cursor,omitempty"`     // Con trỏ Base64 lấy trang trước đó
	HasMore    bool   `json:"has_more"`                  // Cờ báo hiệu còn trang kế tiếp không
	HasPrev    bool   `json:"has_prev"`                  // Cờ báo hiệu còn trang trước đó không
}
```

#### 2. Cấu Trúc Con Trỏ Cursor (CursorData Token)
Con trỏ phân trang được mã hóa Base64 URL-safe từ struct `CursorData`:
```go
type CursorData struct {
	Field string `json:"field"` // Trường sort (VD: "c_at", "u_at")
	Value any    `json:"val"`   // Giá trị phân trang (timestamp mili-giây int64 hoặc chuỗi)
	ID    string `json:"id"`    // Hex ObjectID của bản ghi tie-breaker (_id)
}
```

#### 3. Cấu Trúc CommonQuery DTO
```go
type CommonQuery struct {
	TenantID     string               `json:"-"`
	SkipIsDel    bool                 `json:"skip_is_del,omitempty"`
	IncludeIDs   []string             `json:"include_ids,omitempty"`
	ExcludeIDs   []string             `json:"exclude_ids,omitempty"`
	Ranges       map[string]TimeRange `json:"ranges,omitempty"`
	Keyword      string               `json:"keyword,omitempty" validate:"omitempty,min=3,max=100"`
	Page         int                  `json:"page"`
	Size         int                  `json:"size"`
	SearchAfter  string               `json:"search_after,omitempty"`  // Token con trỏ duyệt tới
	SearchBefore string               `json:"search_before,omitempty"` // Token con trỏ duyệt lùi
	Projection   map[string]any       `json:"projection,omitempty"`
	Sort         map[string]any       `json:"sort,omitempty"`          // Map từ client VD: {"c_at": -1}
	Role         QueryRole            `json:"role,omitempty"`

	ParsedCursor *CursorData          `json:"-"` // Con trỏ đã giải mã và kiểm tra hợp lệ
}
```

#### 4. Phân Quyền Sắp Xếp Whitelist Sort (`ISortableQuery`)
Mọi Request DTO của từng module có thể giới hạn danh sách trường được phép Sort bằng cách implement interface:
```go
type ISortableQuery interface {
	GetAllowedSortFields() []string
}

// Ví dụ User Request:
func (r ListUsersRequest) GetAllowedSortFields() []string {
	return []string{"c_at"} // Chỉ cho phép sort theo ngày tạo
}
```

#### 5. Công Thức Truy Vấn Keyset Compound Cursor (MongoDB)
Khi Client truyền `search_after` hoặc `search_before`, Backend tự động tạo điều kiện BSON `$or` kết hợp tie-breaker `_id`:
- **Sort DESC (`sortDir = -1`):**
  - **`SearchAfter`:** `$or: [{ Field: { $lt: Value } }, { Field: Value, _id: { $lt: ID } }]`
  - **`SearchBefore`:** `$or: [{ Field: { $gt: Value } }, { Field: Value, _id: { $gt: ID } }]`, DB sort đảo ngược thành `{ Field: 1, _id: 1 }` và Backend đảo ngược mảng kết quả sau khi fetch.
- **Sort ASC (`sortDir = 1`):**
  - **`SearchAfter`:** `$or: [{ Field: { $gt: Value } }, { Field: Value, _id: { $gt: ID } }]`
  - **`SearchBefore`:** `$or: [{ Field: { $lt: Value } }, { Field: Value, _id: { $lt: ID } }]`, DB sort đảo ngược thành `{ Field: -1, _id: -1 }` và Backend đảo ngược mảng kết quả sau khi fetch.

---

## 4. Quy Tắc & Logic Đặc Biệt Khi Phối Hợp Trọn Bộ List (Global List Integration Logic)

Khi tích hợp đầy đủ các thành phần, lập trình viên cả hai đội FE và BE bắt buộc tuân thủ các logic đặc biệt:

1. **Tự động reset trang về 1 khi lọc (Reset Page on Filter Change - FE):** 
   Khi người dùng đổi tiêu chí lọc (search key, multi-select roles, date range), Frontend bắt buộc reset `page = 1`, xóa `search_after`/`search_before` trước khi gửi request API mới.
2. **Tìm kiếm Tối thiểu 3 Ký tự & Nhấn Enter (Min 3 Chars & Enter-to-Search - FE):** 
   Spam request trên từng phím gõ bị cấm. Tìm kiếm chỉ được kích hoạt khi người dùng nhập từ 3 ký tự trở lên (`trimmed.length >= 3`) và nhấn phím **ENTER**. Khi xóa rỗng ô tìm kiếm (`""`), tự động reset tìm kiếm để tải lại danh sách đầy đủ.
3. **Range Conflict Check (BE):**
   Nếu Client truyền Cursor (`search_after` / `search_before`) nhưng giá trị mốc thời gian của cursor nằm ngoài khoảng `ranges[field]` đã chọn (ví dụ: filter từ ngày 1 đến ngày 10 nhưng cursor gửi mốc ngày 15), Backend lập tức trả về lỗi `ERR_CURSOR_OUT_OF_RANGE`.
4. **Safe `$or` Merger (BE):**
   Khi Repository kết hợp thêm các điều kiện `$or` riêng (như phân cấp quyền Owner), bắt buộc dùng `mongodb.AppendOrClause(baseQuery, clauses)` để tự động gom vào `$and` mà không ghi đè điều kiện Cursor của hệ thống.
5. **Lọc ẩn hệ thống phía Backend (Invisible System Filters - BE):** 
   Frontend không tự gửi các điều kiện bảo mật/hệ thống. Backend tự động tiêm filter cô lập Multi-tenant (`tid`) và loại bỏ xóa mềm (`is_del: false`) trực tiếp ở tầng Repository của Go.

---

## 5. Các Mã lỗi Thường gặp & Payload ví dụ (Error Codes & Payload Examples)

| HTTP Status | error_code | Ý nghĩa & Hướng xử lý |
| :--- | :--- | :--- |
| `400` | `ERR_INVALID_CURSOR` | Token cursor Base64 không hợp lệ, sai cấu trúc JSON, sai ObjectID hex, hoặc field sort không khớp với cursor. |
| `400` | `ERR_CURSOR_OUT_OF_RANGE` | Giá trị con trỏ cursor vượt ra ngoài biên của bộ lọc khoảng thời gian `ranges[field]`. |
| `400` | `ERR_PAGING_LIMIT_EXCEEDED` | Client cố tình offset sâu (`page * size > 10000`) mà không dùng con trỏ cursor. |

---

## 6. Quy Trình Tích Hợp Chuẩn 1 Module Danh Sách (Step-by-Step List Integration Standard)

Để xây dựng một màn hình danh sách mới (VD: Khách hàng, Đơn hàng, Phiếu hỗ trợ, Nhân viên,...) tuân thủ 100% Golden Standard và tái sử dụng toàn bộ hệ sinh thái List, lập trình viên thực hiện theo **quy trình 5 bước chuẩn hóa** dưới đây:

### Bước 1: Khai báo Entity Model kế thừa `BaseAuditEntity`
Mọi interface entity ở Frontend bắt buộc phải kế thừa `BaseAuditEntity` (phản chiếu trực tiếp từ `BaseEntity` của Backend Go):
```typescript
import { BaseAuditEntity } from '@/types/baseEntity';

export interface Customer extends BaseAuditEntity {
  id: string;          // _id hoặc UID
  name: string;        // Tên khách hàng (Primary)
  email: string;       // Email
  phone: string;       // Số điện thoại
  status: 'ACTIVE' | 'INACTIVE'; // Trạng thái
  owner_id?: string;   // Người phụ trách
  // ...các trường đặc thù khác của module
}
```

---

### Bước 2: Khai báo Schema Cột với `commonColumns`
Sử dụng các hàm builder có sẵn từ `@/components` để khởi tạo cột chỉ trong 1 dòng code, tự động liên kết đa ngôn ngữ và tối ưu hiệu năng:
```typescript
import {
  Column,
  getNameColumn,
  getEmailColumn,
  getPhoneColumn,
  getStatusColumn,
  getOwnerColumn,
  getBaseAuditColumns,
} from '@/components';

const allColumns: Column<Customer>[] = useMemo(() => [
  // 1. Cột định danh chính (Tên + ID Subtitle) - Cố định vị trí đầu
  getNameColumn<Customer>(t, { header: t('col_customer_name') }),

  // 2. Các cột thông dụng (Tự động Alias Resolution & Zero-Allocation)
  getEmailColumn<Customer>(t),
  getPhoneColumn<Customer>(t),
  getStatusColumn<Customer>(t),
  getOwnerColumn<Customer>(t),

  // 3. Cột đặc thù riêng của module (nếu có)
  {
    key: 'loyalty_points',
    header: 'Điểm tích lũy',
    initialWidth: 140,
    render: (item) => <Typo variant="body" className="font-mono">{item.loyalty_points || 0}</Typo>,
  },

  // 4. Trọn bộ 4 cột Audit hệ thống (c_at, u_at, c_by, u_by)
  ...getBaseAuditColumns<Customer>(t),
], [t, language]);
```

---

### Bước 3: Khai báo Bộ Lọc `availableFilters` (Tuân thủ Filter Priority Order)
* **Quy tắc thứ tự**: Bộ lọc khoảng thời gian (`c_at` / `DateRangePicker`) **BẮT BUỘC LUÔN NẰM Ở VỊ TRÍ ĐẦU TIÊN (INDEX 0)**.
* **Tự động đồng bộ**: Bỏ trống `label` để `<DataTable />` tự động kế thừa `column.header` từ mảng cột.
```typescript
import { AvailableFilterItem, MultiSelect, DateRangePicker } from '@/components';

const availableFilters: AvailableFilterItem[] = useMemo(() => [
  // Vị trí 1 (BẮT BUỘC): Bộ lọc thời gian tạo
  {
    id: 'c_at',
    visible: true,
    component: (
      <DateRangePicker
        label={t('col_created_at')}
        value={dateRange}
        onChange={(val) => { setDateRange(val); setPage(1); }}
      />
    ),
  },
  // Vị trí 2: Bộ lọc Trạng thái (Tự động có nút "Tất cả")
  {
    id: 'status',
    visible: true,
    component: (
      <MultiSelect
        label={t('col_status')}
        options={statusOptions}
        value={selectedStatuses}
        onChange={(val) => { setSelectedStatuses(val); setPage(1); }}
      />
    ),
  },
  // Vị trí 3: Bộ lọc Người phụ trách
  {
    id: 'owner_id',
    visible: true,
    component: (
      <MultiSelect
        label={t('col_owner')}
        options={ownerOptions}
        value={selectedOwners}
        onChange={(val) => { setSelectedOwners(val); setPage(1); }}
      />
    ),
  },
], [t, dateRange, selectedStatuses, selectedOwners, statusOptions, ownerOptions]);
```

---

### Bước 4: Xây dựng Payload Gọi API (Zero-Waste Payload Rule)
Tuân thủ nguyên tắc bỏ qua (omit) các trường không lọc hoặc chọn tất cả:
```typescript
// Chỉ gửi các trường thực sự có lọc tập con lên API
const queryParams: Record<string, any> = {
  page,
  size,
};

if (searchQuery.trim()) {
  queryParams.search = searchQuery.trim();
}

// Bỏ qua nếu là 0 hoặc chọn tất cả options
if (selectedStatuses.length > 0 && selectedStatuses.length < statusOptions.length) {
  queryParams.status = selectedStatuses;
}

if (selectedOwners.length > 0 && selectedOwners.length < ownerOptions.length) {
  queryParams.owner_id = selectedOwners;
}

if (dateRange.from > 0 && dateRange.to > 0) {
  queryParams.from_date = dateRange.from;
  queryParams.to_date = dateRange.to;
}
```

---

### Bước 5: Render Component `<DataTable />`
Lắp ráp các thành phần lại với Action Button chuẩn thuần chữ (`<AddButton />`):
```tsx
import { DataTable, AddButton } from '@/components';

<DataTable
  columns={allColumns}
  data={customers}
  total={totalCount}
  page={page}
  size={size}
  hasMore={hasMore}
  onPageChange={setPage}
  onSizeChange={(newSize) => { setSize(newSize); setPage(1); }}
  onSearchChange={(val) => { setSearchQuery(val); setPage(1); }}
  searchPlaceholder={t('header_search_placeholder')}
  availableFilters={availableFilters}
  actionComponent={<AddButton onClick={handleOpenCreateModal} />}
  onSettingsChange={(settings) => {
    // Lưu projection fields hoặc tùy biến hiển thị
    setProjectionFields(settings.visibleColumnKeys);
  }}
/>
```

---

## 7. Quy Trình Vòng Đời Từ Danh Sách Đến Modal Chi Tiết (List-to-Modal Lifecycle & Interaction Flow)

Mọi phân hệ hiển thị bảng dữ liệu (Bảng Roles, Users, Customers, Tags...) trên hệ thống đều phải tuân thủ chuẩn tương tác 2 chiều giữa **Danh sách (`DataTable`)** và **Hộp thoại Chi tiết (`ItemModal`)** theo đặc tả dưới đây:

```mermaid
flowchart TD
    A[Bảng Danh Sách - DataTable] -->|1. Bấm nút Thêm mới| B[Mở Modal: Chế độ 'create']
    A -->|2. Click vào Row / Chỉnh sửa| C{Kiểm tra Quyền?}
    C -->|Có quyền MANAGE| D[Mở Modal: Chế độ 'edit']
    C -->|Chỉ có quyền VIEW| E[Mở Modal: Chế độ 'view' - ReadOnly]
    
    B -->|Tạo thành công| F[Callback: onSuccess(item, 'create')]
    D -->|Lưu thành công| G[Callback: onSuccess(item, 'update')]
    D -->|Xóa thành công| H[Callback: onSuccess(item, 'delete')]
    
    F -->|Cập nhật List| I[Thêm vào đầu danh sách & Total + 1]
    G -->|Cập nhật List| J[Cập nhật trực tiếp bản ghi trong Local State]
    H -->|Cập nhật List| K[Lọc bỏ bản ghi trong Local State & Total - 1]
```

---

### 7.1 Quy Trình Call API List & Parse Model Phía Frontend
1. **Khởi tạo Request**:
   * Gọi `listX(payload)` kèm `projection: DEFAULT_[ENTITY]_PROJECTION`, `page`, `size`, `sort: { c_at: -1 }`.
   * Đối tượng `projection` và `sort` **bắt buộc phải là hằng số tĩnh** hoặc bọc `useMemo` ngoài component để tránh duplicate fetch.
2. **Nhận & Parse Response Model**:
   * Backend trả về `BaseResponse<PagedResponse<T>>`.
   * Frontend bóc tách:
     * `items: res.data.items` $\rightarrow$ gán vào state danh sách (`setItems`).
     * `total: res.data.total` $\rightarrow$ gán vào state tổng số bản ghi (`setTotal`).
     * `has_more: res.data.has_more` $\rightarrow$ phục vụ chuyển trang cursor nếu có.
3. **Mapping vào DataTable Schema**:
   * Sử dụng các Column Builder chuẩn (`getNameColumn`, `getStatusColumn`, `...getBaseAuditColumns(t)`).
   * Cấu hình sự kiện click dòng: `onRowClick={(row) => handleOpenModal(hasManagePerm ? 'edit' : 'view', row)}`.

---

### 7.2 Đặc Tả 3 Chế Độ Xem Của Modal (Modal Modes Specification)

Mỗi form chi tiết (`ItemModal`) hỗ trợ đúng **3 chế độ xem (Mode)**:

| Chế độ (`mode`) | Điều kiện kích hoạt | Trạng thái Form & Inputs | Nút Hành Động (Action Buttons) |
|---|---|---|---|
| **`create`** *(Thêm mới)* | Người dùng bấm nút `<AddButton />` ở góc trên bảng | Form rỗng, các trường editable | • **Nút Tạo mới (Primary CTA)**: Gọi API `addX`<br>• **Nút Hủy (Secondary)**: Đóng modal<br>❌ *Không có nút Xóa* |
| **`edit`** *(Chỉnh sửa)* | Người dùng click vào dòng trên bảng và **có quyền `*_MANAGE`** | Form nạp dữ liệu từ row được chọn, các trường editable | • **Nút Lưu thay đổi (Primary CTA)**: Áp dụng **Dirty Check (Rule 9)**, bị `disabled` nếu chưa có thay đổi nào hiệu dụng<br>• **Nút Xóa (Danger)**: Nằm góc trái modal, click mở Mini Confirm Dialog xác nhận trước khi xóa<br>• **Nút Hủy**: Đóng modal |
| **`view`** *(Chỉ xem / Read-only)* | Người dùng click vào dòng trên bảng nhưng **chỉ có quyền `*_VIEW`** (hoặc item hệ thống bị khóa) | Toàn bộ inputs/checkboxes bị `disabled` hoặc `readOnly` | • **Nút Đóng (Secondary CTA)**: Đóng modal<br>❌ *Ẩn toàn bộ nút Lưu và nút Xóa* |

---

### 7.3 Quy Trình Đồng Bộ State Ngược Lại List Sau Thao Tác (`onSuccess Callback`)

Khi Modal thực hiện thành công một thao tác CUD, Modal sẽ gọi callback `onSuccess(item, actionType)` truyền ngược về List View để cập nhật giao diện mà **không cần reload toàn bộ trang**:

```typescript
const handleModalSuccess = (item: RoleResponse, action: 'create' | 'update' | 'delete') => {
  if (action === 'create') {
    // 1. Thêm mới: Đưa lên đầu danh sách và tăng total
    setRoles((prev) => [item, ...prev]);
    setTotal((prev) => prev + 1);
  } else if (action === 'update') {
    // 2. Cập nhật: Map trực tiếp vào bản ghi tương ứng (Zero Network Re-fetch)
    setRoles((prev) => prev.map((r) => (r.id === item.id ? { ...r, ...item } : r)));
  } else if (action === 'delete') {
    // 3. Xóa: Nếu danh sách chưa đầy trang -> xóa trực tiếp trong state
    if (roles.length < size || total <= size) {
      setRoles((prev) => prev.filter((r) => r.id !== item.id));
      setTotal((prev) => Math.max(0, prev - 1));
    } else {
      // Đang ở trang đầy đủ -> gọi lại API fetch để kéo bản ghi trang kế tiếp lên
      fetchRoles();
    }
  }
};
```

---

### 7.4 Các Tips Kỹ Thuật Tối Ưu Bảng & API Dữ Liệu
1. **Chống Duplicate Fetch khi Mount**:
   * Khai báo `DEFAULT_PROJECTION` hằng số ngoài Module.
   * Debounce search chỉ trigger khi `searchQuery.trim() !== debouncedSearch` và độ dài `>= 3` ký tự hoặc rỗng.
   * Chặn không gọi các API lấy quyền trùng lặp ở Layout cha nếu component con đã tự quản lý.
2. **Khắc Phục Độ Trễ Index Lag Của Search Engine Khi Xóa**:
   * Atlas Search (`$search`) và OpenSearch có độ trễ đồng bộ từ 500ms - 2s.
   * Khi xóa item trên UI: Bắt buộc dùng cơ chế **Local State Filter** ở Mục 7.3 thay vì gọi lại `fetchList()` ngay để tránh hiện tượng bản ghi vừa xóa vẫn xuất hiện lại trên bảng.
3. **Xử Lý Lọc `_id` với MongoDB Atlas Search**:
   * Atlas Search `$search` không hỗ trợ filter `_id: { $in: [...] }`.
   * Phía Backend bắt buộc tách `_id` filter ra `$match` stage riêng biệt đặt ngay sau `$search` stage trong Aggregate Pipeline.



