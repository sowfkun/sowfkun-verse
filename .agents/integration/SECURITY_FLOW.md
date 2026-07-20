# Security & Handshake Flow

This flow is required to establish End-to-End Encryption (E2EE) between the Frontend and the Backend for sensitive requests (e.g. login, payment).

## Concept
1. The Frontend requests the Backend's RSA Public Key.
2. The Frontend generates a random AES Key (16 or 32 bytes).
3. The Frontend encrypts this AES Key using the RSA Public Key.
4. The Frontend sends the encrypted AES Key to the Backend via Handshake API.
5. The Backend returns a `session_id`.
6. The Frontend uses the `session_id` in subsequent sensitive API requests (passed via HTTP Header `X-Session-ID`) and encrypts the payload using the AES Key.

## Endpoints

### 1. Get RSA Public Key
- **Endpoint:** `GET /security/public-key`
- **Requires Auth:** No
- **Response:**
```json
{
  "code": "MSG_SUCCESS",
  "data": {
    "public_key": "-----BEGIN PUBLIC KEY-----\n..."
  }
}
```

### 2. Client Handshake
- **Endpoint:** `POST /security/handshake`
- **Requires Auth:** No
- **Request Body:**
```typescript
interface HandshakeRequest {
  encrypted_aes_key: string; // Base64 string of RSA-encrypted AES Key
}
```
- **Response:**
```json
{
  "code": "MSG_SUCCESS",
  "data": {
    "session_id": "uuid-string-here"
  }
}
```
