# API Reference - Authentication & User Management

This reference documents the Authentication REST API endpoints added in Phase 2 under the `/api/v1/auth/` namespace.

---

## 📌 Endpoint Summary

| Method | Endpoint | Auth Required | Description |
| :--- | :--- | :--- | :--- |
| `POST` | `/api/v1/auth/verify-firebase` | No | Verifies Firebase ID Token, signs in or registers user, issues JWTs |
| `POST` | `/api/v1/auth/refresh` | No | Rotates session refresh token and returns new JWT access/refresh tokens |
| `POST` | `/api/v1/auth/logout` | Bearer Token | Revokes the current device's refresh token |
| `POST` | `/api/v1/auth/logout-all` | Bearer Token | Revokes all active refresh tokens for the user across all devices |
| `GET` | `/api/v1/auth/me` | Bearer Token | Returns the current user's profile and roles |
| `POST` | `/api/v1/auth/profile-setup` | Bearer Token | Saves full name, photo, role selection, and issues updated JWT |

---

## 🔍 Detailed Endpoints

### 1. `POST /api/v1/auth/verify-firebase`

**Request Body**:
```json
{
  "id_token": "firebase_id_token_string_here"
}
```

**Success Response (200 OK)**:
```json
{
  "success": true,
  "message": "Authentication successful.",
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "token_type": "bearer",
    "is_new_user": false,
    "user": {
      "id": "11111111-1111-1111-1111-111111111111",
      "firebase_uid": "firebase-uid-123",
      "phone_number": "+15555555555",
      "full_name": "Jane Doe",
      "email": null,
      "profile_photo": null,
      "role": "citizen",
      "is_verified": true,
      "is_active": true,
      "last_login": "2026-07-21T23:30:00Z",
      "created_at": "2026-07-21T23:00:00Z",
      "roles": []
    }
  },
  "timestamp": "2026-07-21T23:30:00Z",
  "request_id": "82e77f41-9e60-4e10-a25b-edef8543c45c"
}
```

---

### 2. `POST /api/v1/auth/refresh`

**Request Body**:
```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Success Response (200 OK)**:
```json
{
  "success": true,
  "message": "Session tokens rotated successfully.",
  "data": {
    "access_token": "new_access_token_string",
    "refresh_token": "new_rotated_refresh_token_string",
    "token_type": "bearer"
  },
  "timestamp": "2026-07-21T23:35:00Z",
  "request_id": "93cbe450-17db-42b0-ab84-e9b8cd887d83"
}
```

---

### 3. `POST /api/v1/auth/logout`

**Headers**: `Authorization: Bearer <access_token>`

**Request Body**:
```json
{
  "refresh_token": "refresh_token_to_revoke"
}
```

**Success Response (200 OK)**:
```json
{
  "success": true,
  "message": "Logout successful.",
  "timestamp": "2026-07-21T23:40:00Z",
  "request_id": "1815ecfb-9b83-474e-b6ba-fa86b1697f37"
}
```

---

### 4. `POST /api/v1/auth/logout-all`

**Headers**: `Authorization: Bearer <access_token>`

**Success Response (200 OK)**:
```json
{
  "success": true,
  "message": "Logged out from all connected devices.",
  "timestamp": "2026-07-21T23:45:00Z",
  "request_id": "420f5830-a4cf-40a2-8029-a9eba259abc0"
}
```

---

### 5. `GET /api/v1/auth/me`

**Headers**: `Authorization: Bearer <access_token>`

**Success Response (200 OK)**:
```json
{
  "success": true,
  "message": "User profile retrieved successfully.",
  "data": {
    "id": "11111111-1111-1111-1111-111111111111",
    "firebase_uid": "firebase-uid-123",
    "phone_number": "+15555555555",
    "full_name": "Jane Doe",
    "email": null,
    "profile_photo": null,
    "role": "police",
    "is_verified": true,
    "is_active": true,
    "last_login": "2026-07-21T23:30:00Z",
    "created_at": "2026-07-21T23:00:00Z",
    "roles": []
  },
  "timestamp": "2026-07-21T23:50:00Z",
  "request_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

---

### 6. `POST /api/v1/auth/profile-setup`

**Headers**: `Authorization: Bearer <access_token>`

**Request Body**:
```json
{
  "full_name": "Officer John Smith",
  "profile_photo": "https://example.com/photo.jpg",
  "role": "police"
}
```

**Success Response (200 OK)**:
```json
{
  "success": true,
  "message": "Profile initialized successfully.",
  "data": {
    "access_token": "updated_access_token_with_police_role_claim",
    "user": {
      "id": "11111111-1111-1111-1111-111111111111",
      "firebase_uid": "firebase-uid-123",
      "phone_number": "+15555555555",
      "full_name": "Officer John Smith",
      "role": "police",
      "is_verified": true,
      "is_active": true,
      "created_at": "2026-07-21T23:00:00Z",
      "roles": [
        {
          "id": "22222222-2222-2222-2222-222222222222",
          "name": "police",
          "description": "Law enforcement responder"
        }
      ]
    }
  },
  "timestamp": "2026-07-21T23:55:00Z",
  "request_id": "660e8400-e29b-41d4-a716-446655440000"
}
```
