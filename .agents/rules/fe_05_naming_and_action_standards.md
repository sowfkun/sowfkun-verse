# 05. Naming & Action Standards (UI / UX Conventions)

Tài liệu này quy định các "Luật Thép" về đặt tên nhãn (Labels), chuẩn hóa động từ hành động nút bấm (Button Actions), phân định màu sắc (Variant Mapping), nguyên tắc Nút Thuần Chữ (Pure Text - No Icons) và cấu trúc phân cấp Tab (Tab Architecture) trên toàn bộ hệ thống Frontend.

---

## 1. Chuẩn hóa Động từ & Hành động Nút (Standard Action Buttons)

Tuyệt đối **NGHIÊM CẤM** việc dùng từ ngữ tùy tiện, không nhất quán giữa các màn hình (ví dụ: chỗ dùng *Chỉnh sửa*, chỗ dùng *Cập nhật*, chỗ dùng *Sửa đổi*; hoặc chỗ dùng *Lưu*, chỗ dùng *Lưu thay đổi*, chỗ dùng *Lưu cài đặt*).

### Bảng Chuẩn hóa Động từ & Specialized Components:

| Hành động | Động từ chuẩn (VI) | Động từ chuẩn (EN) | Component / Variant | Styling & Mục đích |
| :--- | :--- | :--- | :--- | :--- |
| **Thêm mới** | `Thêm mới` | `Add New` | `<AddButton />` (`variant="add"`) | Nút tạo bản ghi mới (Duy nhất từ *Thêm mới*, cấm dùng *Tạo mới*). |
| **Lưu dữ liệu** | `Lưu` | `Save` | `<SaveButton />` (`variant="save"`) | Nút submit form/modal (Duy nhất từ *Lưu*, hỗ trợ `isLoading` hiển thị *Đang xử lý...*). |
| **Hủy thao tác** | `Hủy` | `Cancel` | `<CancelButton />` (`variant="cancel"`) | Nút hủy thao tác, đóng modal hoặc thoát trạng thái chỉnh sửa. |
| **Chỉnh sửa** | `Chỉnh sửa` | `Edit` | `<EditButton />` (`variant="edit"`) | Nút mở form/chuyển trạng thái edit. |
| **Xóa dữ liệu** | `Xóa` | `Delete` | `<DeleteButton />` (`variant="delete"`) | Nút xóa bản ghi, thao tác nguy hiểm. |

---

## 2. Nguyên tắc Nút Thuần Chữ (Pure Text - No Icons Rule)

- **Mặc định Thuần Chữ**: Tất cả các Specialized Action Buttons (`<AddButton>`, `<SaveButton>`, `<CancelButton>`, `<EditButton>`, `<DeleteButton>`) **BẮT BUỘC LÀ DẠNG THUẦN CHỮ (PURE TEXT), TUYỆT ĐỐI KHÔNG CHÈN ICON MẶC ĐỊNH BÊN TRONG**.
- **Lý do**: Giữ cho giao diện tối giản, thanh lịch, đồng nhất nhịp điệu Typography và tránh việc các icon thừa thãi làm loãng trọng tâm chú ý của người dùng.

---

## 3. Phân Zone & Quản lý Key trong Từ điển Đa Ngôn Ngữ (`src/lib/i18n.ts`)

- **Tách Zone Riêng Biệt**: Tất cả các nhãn động từ hành động nút bấm **BẮT BUỘC** phải được khai báo tập trung trong zone:
  ```ts
  // ==========================================
  // UI - BUTTONS & COMMON ACTIONS
  // ==========================================
  btn_add: 'Thêm mới', // EN: 'Add New'
  btn_save: 'Lưu',      // EN: 'Save'
  btn_cancel: 'Hủy',    // EN: 'Cancel'
  btn_edit: 'Chỉnh sửa',// EN: 'Edit'
  btn_delete: 'Xóa',    // EN: 'Delete'
  btn_reset: 'Đặt lại', // EN: 'Reset'
  btn_apply: 'Áp dụng', // EN: 'Apply'
  btn_close: 'Đóng',    // EN: 'Close'
  btn_saved_success: 'Cập nhật thành công!',
  ```
- **Cấm Trùng Lặp Khóa (Zero Redundant Keys)**: Tuyệt đối không tạo thêm các key thừa như `btn_save_changes`, `save_settings`, `btn_create` khi đã có `btn_save`, `btn_add`.

---

## 4. Chuẩn hóa Màu sắc & Button Variants (Color Semantic Mapping)

- **`primary` / `save` / `add`** (`var(--gradient-brand)`): Các hành động chính điều hướng luồng người dùng (*Lưu, Thêm mới*).
- **`secondary` / `cancel`** (`var(--border-color)` + Text thứ cấp): Các hành động phụ trợ hoặc hủy bỏ (*Hủy, Quay lại*).
- **`edit`** (`var(--bg-tertiary)` + Viền): Chuyển chế độ xem sang chỉnh sửa.
- **`danger` / `delete`** (`var(--color-danger)`): Các hành động xóa bỏ, nguy hiểm.
- **`ghost`** (Nền trong suốt): Hành động phụ trợ nhẹ.

---

## 5. Cơ chế Chống Double-Click & Khóa Async (Double-Click & Concurrency Guard)

- **Cơ chế Cooldown mặc định (400ms)**: Toàn bộ nút bấm (`<Button>`, `<SaveButton>`, `<AddButton>`, `<CancelButton>`, `<EditButton>`, `<DeleteButton>`) đều được tích hợp sẵn cơ chế Debounce Cooldown `debounceMs = 400ms`. Mọi cú click liên tiếp trong khoảng thời gian này sẽ tự động bị chặn (`preventDefault()`, `stopPropagation()`), ngăn ngừa triệt để tình trạng spam request lên server.
- **Khóa tự động khi gọi hàm Async (Promise Locking)**: Khi `onClick` trả về một Promise (gọi API submit form, cập nhật DB), nút sẽ tự động kích hoạt cờ `isAsyncExecuting` và khóa nút (`disabled`) cho đến khi Promise hoàn tất (kể cả thành công hay lỗi), bảo vệ an toàn tuyệt đối cho các giao dịch mạng.

---

## 6. Quy chuẩn Đặt tên & Cấu trúc Tab (Tab Architecture Standards)

### Rule 5.1 - Luật Danh từ hóa (Noun-Only):
- Tên Tab **BẮT BUỘC phải là Danh từ hoặc Cụm danh từ**.
- **TUYỆT ĐỐI KHÔNG** dùng Động từ làm tên Tab.
  - ✅ *Đúng:* `Doanh nghiệp`, `Tài khoản`, `Gói dịch vụ`, `Bảo mật`, `Cấu hình`, `Bộ lọc`, `Sắp xếp thuộc tính`.
  - ❌ *Sai:* *Cài đặt doanh nghiệp, Quản lý tài khoản, Xem gói cước, Đổi mật khẩu*.

### Rule 5.2 - Độ dài Tối ưu (Max 2 - 3 từ):
- Tên Tab tối đa 3 từ, luôn áp dụng `white-space: nowrap`, tuyệt đối không để chữ bị rớt dòng làm vỡ bố cục giao diện.

### Rule 5.3 - Phân cấp Tab 2 Tầng Chuẩn mực (2-Level Hierarchy):
- **Cấp 1 (Sub-Sidebar Navigation)**: Đại diện cho các mảng nghiệp vụ / phạm vi vĩ mô (VD: `Thông tin chung`, `Cấu hình hệ thống`, `Bảo mật`).
- **Cấp 2 (Segmented Sub-Tabs / `<Tabs />`)**: Đại diện cho các góc nhìn hoặc thực thể chi tiết bên trong nhóm đó (VD trong Thông tin chung: `Doanh nghiệp`, `Tài khoản`, `Gói dịch vụ`).
