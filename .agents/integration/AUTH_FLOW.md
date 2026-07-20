# Authentication & Onboarding Flow

This document outlines the flows related to creating new accounts and authenticating users.

## 1. Onboarding Flow (Registration)

To register a new tenant and an owner user, the system uses an OTP-based verification flow.

### Step 1: Initialize Registration (Send OTP)
Sends an OTP to the provided email to verify ownership.

- **Endpoint:** `POST /auth/register`
- **Requires Auth:** No
- **Request Body:**

```typescript
interface RegisterRequest {
  business_name: string; // Tên doanh nghiệp/tổ chức
  owner_name: string;    // Tên chủ doanh nghiệp / Tên người đại diện
  phone: string;         // Số điện thoại liên hệ
  email: string;         // Email đăng nhập
  password: string;      // Mật khẩu
  language?: string;     // Ngôn ngữ nhận email (mặc định "vi")
}
```

- **Success Response (`MSG_OTP_SENT`):**
```json
{
  "code": "MSG_OTP_SENT",
  "message": "OTP đã được gửi đến email",
  "data": null
}
```

### Step 2: Verify OTP & Complete Registration
Validates the OTP. If valid, the system officially provisions the `Tenant` and `User` records in the database and returns a JWT access token.

- **Endpoint:** `POST /auth/verify-otp`
- **Requires Auth:** No
- **Request Body:**

```typescript
interface VerifyOTPRequest {
  email: string;
  otp: string;
}
```

- **Success Response (`MSG_SUCCESS`):**
```typescript
interface AuthSuccessResponse {
  access_token: string;
  refresh_token: string;
  user_info: {
    id: string;
    name: string;
    email: string;
    is_owner: boolean;
    tenant_id: string;
  }
}
```

## 2. Login Flow
*(Status: Pending Implementation)*

Once a user is registered, they can acquire a token using their email and password.
*(Will be updated once `/auth/login` is fully developed).*
