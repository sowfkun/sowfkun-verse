# 07. Frontend Performance & Render Optimization (Quy chuẩn Hiệu Năng & Tối Ưu Re-render)

Tài liệu này định nghĩa toàn bộ "Luật Thép" về hiệu năng (Performance Standards) và danh sách kiểm tra (Checklist) bắt buộc khi viết và review code Frontend React/Next.js trong hệ thống Sowfkun-Verse.

---

## 1. Ổn Định Tham Chiếu (Reference Stability & Anti Re-render)

> **Luật**: Mỗi khi một Component cha re-render, toàn bộ các object literal, array literal và inline arrow functions khai báo bên trong thân hàm sẽ bị cấp phát bộ nhớ mới (New Reference). Điều này làm vô hiệu hóa `React.memo` và kích hoạt lại toàn bộ `useEffect` phụ thuộc, gây lãng phí CPU và giật lag giao diện.

### 1.1 Khai Báo Hằng Số Tĩnh Cấp Module (Static Constants)
- Đối với các cấu hình tĩnh, mảng options cố định, projection mặc định (như `DEFAULT_PROJECTION`, `DEFAULT_SORT`, `STATUS_OPTIONS`):
  - **BẮT BUỘC** khai báo bên ngoài thân Function Component (ở cấp Module level).
  - **NGHIÊM CẤM** viết inline: `projection={{ name: 1, desc: 1 }}` hoặc `options={['ACTIVE', 'INACTIVE']}` bên trong JSX hoặc hooks.

### 1.2 Bắt Buộc `useMemo` & `useCallback` Cho Props và Dependencies
- Mọi object/array động phụ thuộc vào state/props truyền xuống component con hoặc đưa vào dependency array của `useEffect` **BẮT BUỘC** phải bọc qua `useMemo`.
- Mọi hàm xử lý sự kiện (như `handleDelete`, `handleOpenModal`, `handleSuccess`) truyền xuống Component con **BẮT BUỘC** phải bọc qua `useCallback`.
- **Nghiêm cấm inline function trong vòng lặp `.map()`**:
  ```tsx
  // ❌ SAI: Tạo function mới ở mỗi phần tử trong mỗi lần render
  {items.map(item => <RowItem key={item.id} onDelete={() => handleDelete(item.id)} />)}

  // ✅ ĐÚNG: RowItem tự nhận id và truyền vào handler cố định, hoặc memoize callback
  {items.map(item => <RowItem key={item.id} id={item.id} onDelete={handleDelete} />)}
  ```

---

## 2. Tối Ưu Hóa Hook & Computed State (Hook Optimization)

### 2.1 Tuyệt Đối Không Dùng `useEffect` Để Đồng Bộ Computed State
- Nếu một giá trị có thể tính toán trực tiếp từ state/props hiện có (ví dụ: `totalSelected = items.filter(x => x.selected).length` hoặc `isDirty = currentVal !== initialVal`):
  - **BẮT BUỘC**: Tính toán trực tiếp inline hoặc bọc qua `useMemo` nếu phép tính nặng.
  - **NGHIÊM CẤM**: Tạo thêm `useState` kèm theo `useEffect` chỉ để tính toán và `setState` lại (gây render lặp 2 lần - Cascading Render).

### 2.2 Quản Lý Dependency Array Chặt Chẽ
- Không bỏ sót dependencies và không truyền các biến object không ổn định vào array dependencies của `useEffect`.
- Kiểm tra điều kiện trước khi thực thi side-effect (ví dụ: `if (searchQuery.trim() !== debouncedSearch)` trước khi cập nhật state tìm kiếm).

---

## 3. Tối Ưu State Cục Bộ & Mạng (Optimistic & Local State Updates)

### 3.1 Xóa Item Không Cần Refetch API (Zero Index Lag)
- Khi thực hiện xóa thành công và danh sách hiện tại **chưa đầy trang** (`items.length < size` hoặc `total <= size`):
  - **TUYỆT ĐỐI KHÔNG gọi lại API `fetchList()`** để tránh tốn request mạng và tránh bị ảnh hưởng bởi độ trễ index (500ms - 2s) của Search Engine bên Backend.
  - **BẮT BUỘC cập nhật Local State**: `setItems(prev => prev.filter(it => it.id !== deletedId))` và `setTotal(t => Math.max(0, t - 1))`.

### 3.2 Cập Nhật Cục Bộ & Dirty Check (Rule 9)
- Khi Update thành công: Cập nhật trực tiếp item trong state `setItems(prev => prev.map(it => it.id === updated.id ? updated : it))`.
- Modal Edit: Áp dụng Dirty Check so sánh với initial data, chỉ gửi các field thay đổi lên API và disable nút Submit khi `!isDirty`.

---

## 4. Debounce, Throttling & Resource Cleanups

### 4.1 Kiểm Soát Tìm Kiếm (Debounce & Enter-to-Search)
- Thanh tìm kiếm `<SearchBar />` **chỉ kích hoạt tìm kiếm khi người dùng nhập từ 3 ký tự trở lên và nhấn Enter** (`trimmed.length >= 3` on Enter), hoặc debounce tối thiểu 300ms có kiểm tra điều kiện giá trị thay đổi thực sự. Cấm gọi API theo từng ký tự gõ phím.

### 4.2 Dọn Dẹp Bộ Nhớ Bắt Buộc (Cleanup on Unmount)
- Mọi `useEffect` có đăng ký Event Listener (`window.addEventListener`), Timer (`setTimeout`, `setInterval`), WebSocket subscription hoặc AbortController **BẮT BUỘC** phải có cleanup function trong `return () => { ... }` để chống rò rỉ bộ nhớ (Memory Leak).

---

## 5. Tối Ưu Cây DOM & Lazy Loading (DOM Pruning)

### 5.1 Cắt Tỉa DOM Ẩn (Conditional Rendering vs Display None)
- Đối với các modal phức tạp, dropdowns, ma trận phân quyền, hoặc drawers:
  - **BẮT BUỘC** dùng Short-circuit Conditional Rendering: `{isOpen && <HeavyModal ... />}`.
  - **TRÁNH** việc luôn render toàn bộ cây DOM phức tạp rồi chỉ ẩn đi bằng CSS `display: none` hoặc `opacity: 0` làm phình to DOM tree của trình duyệt.

### 5.2 Dynamic Import Cho Components Nặng
- Các components hiếm khi mở hoặc nặng về thư viện (như biểu đồ Recharts, Rich Text Editor, Code Mirror, File Uploader lớn): Bắt buộc dùng `next/dynamic` với `ssr: false` để tách bundle.

---

## 6. Bảng Checklist Kiểm Tra Nhanh Cho Reviewer (Performance Review Checklist)

Khi Review code Frontend, Reviewer bắt buộc đối chiếu danh sách kiểm tra sau:

| STT | Hạng mục kiểm tra | Dấu hiệu vi phạm (Red Flags) | Chuẩn sửa chữa |
|:---|:---|:---|:---|
| 1 | **Object/Array References** | Khai báo object/array literal trực tiếp trong props hoặc hooks | Chuyển thành const ngoài module hoặc bọc `useMemo` |
| 2 | **Callback Functions** | Khai báo arrow function inline trong `.map()` hoặc truyền vào component con | Bọc `useCallback` hoặc chuyển id vào component con |
| 3 | **Cascading Render** | Dùng `useState` + `useEffect` để sync state từ props/state khác | Tính toán trực tiếp bằng `useMemo` hoặc biến cục bộ |
| 4 | **Search Spam** | Gọi API theo từng ký tự gõ phím | Áp dụng Enter-to-Search và debounce `>= 3` ký tự |
| 5 | **Delete Refetch Waste** | Gọi `fetchList()` sau khi xóa dù list chưa đầy trang | Dùng `filter` xóa trực tiếp trong local state |
| 6 | **DOM Bloat** | Render modal/drawer ẩn bằng CSS `display: none` | Dùng Conditional Rendering `{isOpen && <Modal />}` |
| 7 | **Memory Leak** | Thiếu return cleanup trong `useEffect` (timers/listeners) | Thêm `clearTimeout`, `removeEventListener` ở return |
| 8 | **Network Dirty Check** | Form Edit gửi toàn bộ payload dù không sửa gì | Áp dụng Dirty Check, chỉ gửi trường thay đổi |
