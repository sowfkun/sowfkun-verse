# Tenant Management Flow

This document outlines the APIs for managing a Tenant (business/organization) profile.

## 1. Update Tenant Information

Allows an authorized user (typically the Owner or Admin) to update the basic information of the Tenant they belong to.

- **Endpoint:** `POST /tenant/update-info`
- **Requires Auth:** Yes (Bearer Token)
- **Request Body:**

```typescript
interface UpdateTenantRequest {
  name: string; // The new name of the business/organization
}
```

- **Success Response (`MSG_SUCCESS`):**
```json
{
  "code": "MSG_SUCCESS",
  "message": "Cập nhật thành công",
  "data": null
}
```

*(More APIs such as retrieving tenant settings, billing info, etc., will be added here as they are developed).*
