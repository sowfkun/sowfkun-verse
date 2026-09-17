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

### Rule 3.1 - Chuẩn hóa Tiền tố theo Phân loại Chức năng (Prefix Taxonomy):
Mọi key đa ngôn ngữ trong `src/lib/i18n.ts` **BẮT BUỘC** phải có tiền tố (prefix) phản ánh chính xác mục đích và phân loại UI:

| Tiền tố (Prefix) | Phân loại chức năng | Ví dụ minh họa |
| :--- | :--- | :--- |
| **`col_`** | Tiêu đề cột dữ liệu bảng (Table Columns) | `col_name`, `col_status`, `col_phone`, `col_email`, `col_owner`, `col_created_at` |
| **`field_`** | Nhãn trường nhập liệu trong Form / Modal (Form Inputs) | `field_name`, `field_email`, `field_phone`, `field_status`, `field_owner`, `field_roles` |
| **`lbl_`** | Nhãn hiển thị thông tin, metadata tóm tắt (Display Labels) | `lbl_tenant_id`, `lbl_user_id`, `lbl_tier`, `lbl_system_language`, `lbl_timezone`, `lbl_results` |
| **`filter_`** | Nhãn và tùy chọn của bộ lọc bảng (Table Filters) | `filter_status`, `filter_status_all`, `filter_owner`, `filter_all_owners` |
| **`btn_`** | Động từ hành động nút bấm, trigger tương tác (Buttons & Actions) | `btn_add`, `btn_save`, `btn_cancel`, `btn_edit`, `btn_delete`, `btn_login`, `btn_logout` |
| **`place_`** | Gợi ý nhập liệu bên trong ô input (Placeholders) | `place_login_email`, `place_login_pwd`, `place_search`, `place_header_search` |
| **`msg_`** | Thông báo trạng thái, Toast, Alert, Notice (Feedback Messages) | `msg_create_success`, `msg_update_success`, `msg_delete_success`, `msg_no_data`, `msg_processing` |
| **`title_`** | Tiêu đề trang, tiêu đề thẻ Card, tiêu đề Modal (Titles) | `title_login`, `title_register`, `title_settings`, `title_table_settings`, `title_preview` |
| **`desc_`** | Đoạn văn bản mô tả chức năng / hướng dẫn (Descriptions) | `desc_settings`, `desc_table_settings`, `desc_activate_ready` |
| **`tab_`** | Tên Tab điều hướng (Danh từ theo Rule 5.1) | `tab_basic_info`, `tab_roles_permissions`, `tab_organization`, `tab_subscription` |
| **`nav_`** | Mục điều hướng Sidebar / Header Navigation | `nav_customers`, `nav_tickets`, `nav_users`, `nav_settings`, `nav_expand_sidebar` |
| **`opt_`** | Tùy chọn trong Select Dropdown, Radio, Checkbox | `opt_all`, `opt_basic_gender_male`, `opt_text_min_len`, `opt_dt_type_date_only` |
| **`notice_` / `hint_`** | Chú thích cố định, ghi chú chính sách, gợi ý thao tác | `notice_owner_only`, `notice_profile_view`, `notice_fixed_field`, `hint_locked_column` |
| **`role_`, `tier_`, `status_`** | Vai trò tài khoản, gói dịch vụ, trạng thái thực thể | `role_owner`, `role_member`, `tier_free`, `tier_pro`, `status_active`, `status_inactive` |
| **`perm_`, `scope_`, `group_`** | Quyền hạn, phạm vi truy cập, nhóm phân quyền | `perm_config_manage`, `scope_all`, `scope_owner`, `group_system_admin` |
| **`entity_`, `zone_`, `data_type_`** | Định danh thực thể, phân vùng, kiểu dữ liệu tùy biến | `entity_customer`, `zone_type_custom`, `data_type_text_plain` |
| **`err_`** | Thông báo lỗi validate form và lỗi logic hệ thống | `err_required`, `err_email`, `err_password`, `err_connection_failed` |

---

### Rule 3.2 - Tách biệt Code theo Phân loại khi trùng Giá trị (Disambiguation by Category):
Khi một khái niệm hoặc một từ ngữ có cùng giá trị hiển thị (ví dụ: *"Tên"*, *"Trạng thái"*, *"Số điện thoại"*, *"Email"*, *"Người phụ trách"*, *"Đăng nhập"*):
- **TUYỆT ĐỐI KHÔNG** dùng chung 1 key duy nhất cho nhiều mục đích khác nhau.
- **BẮT BUỘC** phải tạo các code riêng biệt với tiền tố tương ứng với từng phân loại:
  - *"Tên"*: Cột bảng dùng `col_name`, form nhập dùng `field_name`, thuộc tính cơ bản dùng `field_basic_name`.
  - *"Trạng thái"*: Cột bảng dùng `col_status`, form nhập dùng `field_status`, bộ lọc dùng `filter_status`, nhãn chi tiết dùng `lbl_status`.
  - *"Người phụ trách"*: Cột bảng dùng `col_owner`, form nhập dùng `field_owner`, bộ lọc dùng `filter_owner`.
  - *"Email"*: Cột bảng dùng `col_email`, form nhập dùng `field_email`.
  - *"Số điện thoại"*: Cột bảng dùng `col_phone`, form nhập dùng `field_phone`.
  - *"Đăng nhập"*: Tiêu đề trang dùng `title_login`, nút hành động submit dùng `btn_login`.
  - *"Đăng ký"*: Tiêu đề trang dùng `title_register`, nút hành động submit dùng `btn_register`.
  - *"Tìm kiếm"*: Ô placeholder dùng `place_search`, nhãn hiển thị dùng `lbl_search`.

---

### Rule 3.3 - Tái sử dụng Khóa Common Cùng Phân Loại (Same-Category Common Reuse):
- **Tối đa hóa tái sử dụng trong cùng một phân loại**: Khi các thành phần UI thuộc **CÙNG MỘT PHÂN LOẠI** (cùng là `btn_`, cùng là `field_`, cùng là `title_`, cùng là `msg_`, cùng là `nav_`) và có chung ngữ nghĩa hiển thị:
  - **BẮT BUỘC** phải tái sử dụng khóa common chung có sẵn.
  - **TUYỆT ĐỐI CẤM** tự ý sinh thêm các key biến thể dư thừa (Redundant Variant Keys) gây phân mảnh từ điển.
- **Các nhóm Common bắt buộc tái sử dụng:**
  1. **Nút bấm (`btn_`)**: Tái sử dụng `btn_add`, `btn_save`, `btn_cancel`, `btn_edit`, `btn_delete`, `btn_reset`, `btn_apply`, `btn_close`, `btn_login`, `btn_logout`, `btn_verify`. *Cấm tạo: `btn_save_changes`, `save_settings`, `btn_create`, `delete_item`.*
  2. **Trường Form/Modal (`field_`)**: Tái sử dụng `field_name`, `field_desc`, `field_phone`, `field_email`, `field_status`, `field_gender`, `field_owner`, `field_roles` xuyên suốt tất cả các modal và form nghiệp vụ (Customer, Ticket, User, Attribute Sets, Tags, Roles). *Cấm tạo: `field_basic_name`, `field_basic_phone`, `field_attr_status`.*
  3. **Tiêu đề (`title_`)**: Tái sử dụng `title_details` (*Chi tiết*) cho tất cả các phần tiêu đề xem thông tin / card header chi tiết. *Cấm tạo: `title_account_details`, `title_organization_details`.*
  4. **Điều hướng (`nav_`)**: Tái sử dụng `nav_users` (*Nhân viên*) cho cả mục menu và breadcrumb. *Cấm tạo: `nav_employees`.*
  5. **Thông báo (`msg_`)**: Tái sử dụng `msg_no_data`, `msg_processing`, `msg_create_success`, `msg_update_success`, `msg_save_success`, `msg_delete_success`.

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
