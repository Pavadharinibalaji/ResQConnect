# Authentication Flow Documentation

This document explains the end-to-end authentication workflow for **ResQConnect**, covering Firebase Phone OTP verification, backend JWT creation, token refresh rotation, and session management.

---

## 🔄 Authentication Sequence Diagram

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant Mobile as Flutter App
    participant Firebase as Firebase Auth
    participant Backend as FastAPI Server
    participant DB as PostgreSQL DB

    User->>Mobile: Input Phone Number (+15555555555)
    Mobile->>Firebase: Request Phone OTP
    Firebase-->>User: Send SMS Verification Code
    User->>Mobile: Input 6-Digit OTP Code
    Mobile->>Firebase: Verify OTP Code
    Firebase-->>Mobile: Return Firebase ID Token
    Mobile->>Backend: POST /api/v1/auth/verify-firebase { id_token }
    Backend->>Firebase: Verify ID Token via Firebase Admin SDK
    Firebase-->>Backend: Token Valid (UID & Phone Number)
    Backend->>DB: Query or Create User (Soft-delete aware)
    Backend->>Backend: Generate JWT Access & Refresh Tokens
    Backend->>DB: Store SHA-256 Hashed Refresh Token
    Backend->>DB: Log Audit Event (action='login')
    Backend-->>Mobile: Return Access Token, Refresh Token, and User Profile
    Mobile->>Mobile: Save Tokens securely in Flutter Secure Storage
    Mobile-->>User: Navigate to /home (or /profile-setup if new user)
```

---

## 🔑 Key Authentication Phases

### 1. Phone OTP Verification
- The Flutter client initiates phone authentication via Firebase Authentication.
- Once verified, the client receives a short-lived **Firebase ID Token**.

### 2. Backend Verification & User Provisioning
- The client passes the Firebase ID token to `POST /api/v1/auth/verify-firebase`.
- The FastAPI backend validates the token using the `firebase-admin` SDK.
- If valid:
  - If the user exists in PostgreSQL, their `last_login` timestamp is updated.
  - If it is a new user, a user record is created with the default `citizen` role, and `is_new_user: true` is returned.

### 3. Session Token Issuance
- The backend generates:
  - **Access Token**: Short-lived (e.g., 30 minutes), containing `sub` (User ID) and `role`.
  - **Refresh Token**: Long-lived (e.g., 30 days), stored as a SHA-256 hash in `refresh_tokens`.
- Both tokens are sent in a standard response wrapper and saved in `FlutterSecureStorage`.

### 4. Automatic Token Refresh & Rotation
- When an API request returns `401 Unauthorized`, the client's `DioClient` interceptor catches the response.
- It posts the stored refresh token to `POST /api/v1/auth/refresh`.
- The backend verifies the token hash, revokes the old refresh token (rotation), issues a new pair of access and refresh tokens, and returns them.
- If refresh fails or token is revoked/expired, all tokens are cleared from secure storage and the user is redirected to `/welcome`.
