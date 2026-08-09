# 05. Naming & Action Standards (UI / UX Conventions)

Tài liệu này quy định các "Luật Thép" về đặt tên nhãn (Labels), chuẩn hóa động từ hành động nút bấm (Button Actions), phân định màu sắc (Variant Mapping) và cấu trúc phân cấp Tab (Tab Architecture) trên toàn bộ hệ thống Frontend.

---

## 1. Chuẩn hóa Động từ & Hành động Nút (Button Action Standards)
Tuyệt đối **NGHIÊM CẤM** việc dùng từ ngữ tùy tiện, không nhất quán giữa các màn hình (ví dụ: chỗ dùng *Chỉnh sửa*, chỗ dùng *Cập nhật*, chỗ dùng *Sửa đổi* cho cùng một hành động).

### Nguyên tắc Phân định Trigger vs. Submit:
- **Trigger Button (Mở Modal / Form / Chuyển chế độ)**: BẮT BUỘC dùng **`Chỉnh sửa`** (`Edit`).
- **Submit Button (Lưu dữ liệu xuống Server)**: BẮT BUỘC dùng **`Lưu thay đổi`** (`Save Changes`) đối với form cài đặt / cập nhật, hoặc **`Lưu`** (`Save`) đối với form nhanh / inline.

### Bảng Chuẩn hóa Động từ & Mapping Variant:

| Nhóm hành động | Động từ chuẩn (VI) | Động từ chuẩn (EN) | Button Variant | Ý nghĩa & Vị trí dùng |
| :--- | :--- | :--- | :--- | :--- |
| **Submit Form** | `Lưu thay đổi` / `Lưu` | `Save Changes` / `Save` | `variant="primary"` | Nút submit hoàn tất biểu mẫu, cập nhật cài đặt. |
| **Create / Add** | `Thêm mới [X]` / `Tạo [X]` | `Create [X]` / `Add [X]` | `variant="primary"` | Tạo thực thể mới (VD: *Thêm mới khách hàng*, *Tạo vé hỗ trợ*). |
| **Trigger Edit** | `Chỉnh sửa` | `Edit` | `variant="secondary"` / `outline` | Bấm để mở form hoặc chuyển sang trạng thái edit. |
| **Destructive** | `Xóa` / `Xóa vĩnh viễn` | `Delete` | `variant="danger"` | Hành động nguy hiểm làm mất/xóa dữ liệu. |
| **Dismiss / Back** | `Hủy` / `Quay lại` | `Cancel` / `Back` | `variant="ghost"` / `outline` | Hủy bỏ thao tác, đóng modal hoặc lùi lại trang trước. |
| **Confirm / Done** | `Xác nhận` / `Hoàn tất` | `Confirm` / `Done` | `variant="success"` / `primary` | Xác nhận hành động tích cực (xác thực OTP, duyệt phiếu). |
| **Filter / Reset** | `Áp dụng` / `Đặt lại` | `Apply` / `Reset` | `variant="primary"` / `ghost` | Áp dụng bộ lọc tìm kiếm hoặc đặt lại giá trị ban đầu. |
| **Data I/O** | `Xuất dữ liệu` / `Nhập dữ liệu` | `Export` / `Import` | `variant="outline"` | Xuất file Excel/CSV hoặc nhập dữ liệu từ tệp ngoài. |

---

## 2. Chuẩn hóa Màu sắc & Button Variants (Color Semantic Mapping)
- **`primary`** (`var(--accent-primary)` - Tím / Indigo): Các hành động chính điều hướng luồng người dùng (*Lưu thay đổi, Thêm mới, Tiếp tục*).
- **`secondary` / `outline`** (`var(--border-color)` + Text sáng): Các hành động phụ trợ (*Chỉnh sửa, Xem chi tiết, Xuất dữ liệu*).
- **`danger`** (`var(--color-danger)` - Đỏ cảnh báo): Các hành động xóa bỏ, đình chỉ nguy hiểm (*Xóa, Thu hồi quyền*).
- **`success`** (`var(--color-success)` - Xanh lá): Xác nhận tích cực hoặc kích hoạt trạng thái (*Xác nhận, Kích hoạt*).
- **`ghost`** (Nền trong suốt, hover sáng nhẹ): Hành động hủy, đóng hoặc đặt lại (*Hủy, Đặt lại*).

---

## 3. Quy chuẩn Đặt tên & Cấu trúc Tab (Tab Architecture Standards)

### Rule 3.1 - Luật Danh từ hóa (Noun-Only):
- Tên Tab **BẮT BUỘC phải là Danh từ hoặc Cụm danh từ**.
- **TUYỆT ĐỐI KHÔNG** dùng Động từ làm tên Tab.
  - ✅ *Đúng:* `Doanh nghiệp`, `Tài khoản`, `Gói dịch vụ`, `Bảo mật`, `Cấu hình`.
  - ❌ *Sai:* *Cài đặt doanh nghiệp, Quản lý tài khoản, Xem gói cước, Đổi mật khẩu*.

### Rule 3.2 - Độ dài Tối ưu (Max 2 - 3 từ):
- Tên Tab tối đa 3 từ, luôn áp dụng `white-space: nowrap`, tuyệt đối không để chữ bị rớt dòng làm vỡ bố cục giao diện.

### Rule 3.3 - Phân cấp Tab 2 Tầng Chuẩn mực (2-Level Hierarchy):
- **Cấp 1 (Sub-Sidebar Navigation)**: Đại diện cho các mảng nghiệp vụ / phạm vi vĩ mô (VD: `Thông tin chung`, `Cấu hình hệ thống`, `Bảo mật`).
- **Cấp 2 (Segmented Sub-Tabs / `<Tabs />`)**: Đại diện cho các góc nhìn hoặc thực thể chi tiết bên trong nhóm đó (VD trong Thông tin chung: `Doanh nghiệp`, `Tài khoản`, `Gói dịch vụ`).

### Rule 3.4 - Sử dụng Core Component `<Tabs />`:
- Mọi nơi hiển thị Tabs chuyển đổi nội dung đều phải sử dụng component chuẩn `<Tabs />` được tạo sẵn trong `src/components/Tabs.tsx`, không tự code thủ công bằng thẻ `<button>` lẻ loi.
