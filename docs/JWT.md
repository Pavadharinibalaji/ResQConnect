# JWT & Session Security Specifications

This document outlines the cryptographic standards, expiration policies, and rotation mechanics governing JWT authentication in **ResQConnect**.

---

## 🔒 Token Specifications

| Parameter | Access Token | Refresh Token |
| :--- | :--- | :--- |
| **Type** | JWT (`type: "access"`) | JWT (`type: "refresh"`) |
| **Lifespan** | 30 Minutes | 30 Days |
| **Storage (Client)** | Flutter Secure Storage (`resq_auth_token`) | Flutter Secure Storage (`resq_refresh_token`) |
| **Storage (Database)** | Stateless (not stored) | SHA-256 Hashed in `refresh_tokens` |
| **Transmission** | `Authorization: Bearer <token>` Header | JSON Request Body |

---

## 🔑 JWT Payload Structure

### Access Token Claims:
```json
{
  "sub": "11111111-1111-1111-1111-111111111111",
  "role": "police",
  "type": "access",
  "exp": 1784683200
}
```

### Refresh Token Claims:
```json
{
  "sub": "11111111-1111-1111-1111-111111111111",
  "type": "refresh",
  "exp": 1787188800
}
```

---

## 🔄 Refresh Token Rotation & Replay Protection

To prevent token theft and replay attacks:
1. Every time a refresh token is presented to `/api/v1/auth/refresh`, its hash is located in the database.
2. The old refresh token is marked `is_revoked = True`.
3. A brand new Access Token **AND** a new Refresh Token are generated and returned.
4. If a revoked refresh token is presented again (indicating potential replay or theft), all active sessions for that token family are invalidated.

---

## 🚪 Revocation & Logout Mechanics

- **Single Device Logout** (`POST /api/v1/auth/logout`): Marks the active device's refresh token as revoked.
- **Logout From All Devices** (`POST /api/v1/auth/logout-all`): Sets `is_revoked = True` on all refresh tokens for the user in PostgreSQL.
