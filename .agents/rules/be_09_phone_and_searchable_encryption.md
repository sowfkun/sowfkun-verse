# 09. Phone Standards & Searchable Encryption (Value Object & Blind Indexing)

*Đây là tập hợp các quy tắc "Luật Thép" dành riêng cho Agent khi làm việc với Số Điện Thoại (PhoneNumber) và Tìm kiếm mã hoá an toàn (Searchable Encryption).*

---

## 1. Kiến trúc Value Object (`coreDomain.PhoneNumber`)
- **Định nghĩa**: Mọi trường số điện thoại trong hệ thống BẮT BUỘC sử dụng Value Object `coreDomain.PhoneNumber` tại `pkg/core/domain/phone.go`. Tuyệt đối **KHÔNG dùng kiểu `string` đơn lẻ** cho trường SĐT trong Entity hay DTO.
- **Cấu trúc struct**:
  ```go
  type PhoneNumber struct {
      CountryCode string `bson:"country_code" json:"country_code"` // VD: "+84"
      Number      string `bson:"number" json:"number"`             // VD: "0901234567"
  }
  ```
- **Quy ước lưu trữ (Storage Standard)**:
  - `CountryCode`: Luôn có tiền tố `+` (ví dụ: `"+84"`, `"+1"`).
  - `Number`: Luôn lưu ở định dạng nội địa bắt đầu bằng số `0` (nếu quốc gia đó sử dụng tiền tố nội địa trunk prefix, ví dụ: `"0901234567"`).
- **On-Premise & Country-Agnostic**:
  - Tuyệt đối **KHÔNG hardcode mã vùng mặc định** (như `"VN"` hay `"+84"`). Hệ thống hỗ trợ đa quốc gia và tự động phát hiện mã vùng qua `libphonenumber`.

---

## 2. Chuẩn Hóa Tự Động (Auto-Normalization & Parsing)
- **Cửa ngõ JSON (`UnmarshalJSON`)**:
  - `PhoneNumber` cài đặt sẵn `UnmarshalJSON(data []byte) error` và `Normalize()`.
  - Bất kỳ khi nào Client gửi JSON payload lên Controller (`json.NewDecoder(r.Body).Decode(&req)`), Go sẽ **tự động chuẩn hóa**:
    - Tự động bù tiền tố `+` nếu thiếu ở `CountryCode`.
    - Phân tích cú pháp qua Google `libphonenumber` (`nyaruka/phonenumbers`) để format chuẩn số nội địa, tự động bù số `0` đầu (nếu người dùng gõ thiếu, ví dụ: `981341899` $\rightarrow$ `0981341899`) và làm sạch khoảng trắng/dấu gạch nối.
- **Khởi tạo nội bộ**: Sử dụng `coreDomain.NewPhoneNumber(countryCode, number)` để tự động chạy hàm `Normalize()`.

---

## 3. Xác Thực Dữ Liệu (Validation)
- **Struct-Level Validation**:
  - Không validate rải rác từng trường con lẻ. Validator đăng ký cấp độ struct `ValidatePhoneNumberStruct` cho kiểu `coreDomain.PhoneNumber` trong `pkg/utils/validator/validator.go`.
  - Sử dụng tag `validate:"required"` (nếu bắt buộc) hoặc `validate:"omitempty"` (nếu tùy chọn).
  - Validator tự động gọi `phone.IsValid()` qua thư viện viễn thông quốc tế `libphonenumber` để xác minh số điện thoại có thực sự hợp lệ theo kế hoạch đánh số (dialing plan) của quốc gia đó.

---

## 4. So Sánh & Dirty Check (Value Equality)
- **So sánh bằng giá trị (Value Equality)**:
  - Khi thực hiện Dirty Check trong UseCase (kiểm tra SĐT có thay đổi hay không để cập nhật DB), BẮT BUỘC sử dụng method:
    ```go
    if cmd.Phone != nil && !cmd.Phone.IsEmpty() && !cmd.Phone.Equal(existing.PhoneNumber) {
        model.PhoneNumber = cmd.Phone
        effectivePhone = *cmd.Phone
        hasChange = true
    }
    ```

---

## 5. Tìm Kiếm & Mã Hóa An Toàn (Searchable Encryption & Blind Indexing)
- **Nguyên lý Blind Index**:
  - Để bảo mật dữ liệu nhạy cảm nhưng vẫn cho phép tìm kiếm nhanh qua Atlas Search, hệ thống sử dụng thuật toán HMAC-SHA256 Blind Indexing (`pkg/core/security/blind_index.go`) kết hợp với khóa bí mật `BLIND_INDEX_PEPPER`.
- **Phân tách Token Tìm kiếm SĐT**:
  - Khi tạo mới (`Add`) hoặc cập nhật (`UpdateInfo`) entity có chứa SĐT, tầng UseCase/Repository BẮT BUỘC gọi `text.BuildPhoneKeywords(phone)` nạp vào mảng từ khóa `kws` (Keywords):
    1. **Full National Number**: SĐT đầy đủ (VD: `"0901234567"` $\rightarrow$ hash).
    2. **Prefix 4 Digits**: 4 số đầu (VD: `"0901"` $\rightarrow$ hash).
    3. **Suffix 4 Digits**: 4 số cuối (VD: `"4567"` $\rightarrow$ hash).
- **Hỗ trợ tìm kiếm phía Client**:
  - Người dùng có thể tìm kiếm theo: toàn bộ số điện thoại, 4 số đầu, hoặc 4 số đuôi.
  - Phía Query Builder / UseCase sẽ băm từ khóa tìm kiếm (`ComputeBlindIndex(keyword)`) và đối chiếu khớp chính xác trên trường `kws` của Atlas Search MongoDB.
