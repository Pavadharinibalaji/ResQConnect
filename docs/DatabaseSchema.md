# Database Schema Architecture

This document documents the PostgreSQL relational schema created for Phase 2 Authentication & User Management.

---

## 🗄 Entity Relationship Overview

```
[users] (1) <---> (*) [devices]
[users] (1) <---> (*) [refresh_tokens]
[users] (1) <---> (*) [audit_logs]
[users] (*) <---> (*) [roles] (via [user_roles])
```

---

## 📋 Table Specifications

### 1. `users`
Primary store for system users.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | Primary Key, Index | Unique internal user ID |
| `firebase_uid` | `VARCHAR(255)` | Unique, Index, NOT NULL | Firebase Authentication UID |
| `phone_number` | `VARCHAR(50)` | Unique, Index, NOT NULL | E.164 formatted phone number |
| `full_name` | `VARCHAR(255)` | NULL | User's display name |
| `email` | `VARCHAR(255)` | Unique, Index, NULL | Optional email address |
| `profile_photo` | `VARCHAR(1024)`| NULL | Profile picture URL |
| `role` | `VARCHAR(50)` | NOT NULL, Default: `citizen` | Quick role reference |
| `is_verified` | `BOOLEAN` | NOT NULL, Default: `true` | Phone verification status |
| `is_active` | `BOOLEAN` | NOT NULL, Default: `true` | Account active toggle |
| `last_login` | `TIMESTAMPTZ` | NULL | Last successful authentication |
| `created_at` | `TIMESTAMPTZ` | NOT NULL, Default: `now()` | Record creation timestamp |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL, Default: `now()` | Record modification timestamp |
| `deleted_at` | `TIMESTAMPTZ` | NULL | Soft delete timestamp |

---

### 2. `roles`
System access roles.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | Primary Key, Index | Role ID |
| `name` | `VARCHAR(50)` | Unique, Index, NOT NULL | Role identifier (e.g., `citizen`, `police`) |
| `description` | `VARCHAR(255)` | NULL | Human-readable role description |

---

### 3. `user_roles`
Junction table mapping users to roles.

| Column | Type | Constraints |
| :--- | :--- | :--- |
| `user_id` | `UUID` | Foreign Key (`users.id` ON DELETE CASCADE), Primary Key |
| `role_id` | `UUID` | Foreign Key (`roles.id` ON DELETE CASCADE), Primary Key |

---

### 4. `devices`
User registered devices for push notifications.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | Primary Key, Index | Device record ID |
| `user_id` | `UUID` | Foreign Key (`users.id` ON DELETE CASCADE), Index | Owner user ID |
| `device_token` | `VARCHAR(512)` | NOT NULL | FCM Push notification token |
| `device_type` | `VARCHAR(50)` | NOT NULL | `ios`, `android`, or `web` |
| `os_version` | `VARCHAR(50)` | NULL | Operating system version |
| `ip_address` | `VARCHAR(50)` | NULL | Client IP address |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | Registration timestamp |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL | Update timestamp |
| `deleted_at` | `TIMESTAMPTZ` | NULL | Soft delete timestamp |

---

### 5. `refresh_tokens`
Hashed refresh session store.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | Primary Key, Index | Record ID |
| `user_id` | `UUID` | Foreign Key (`users.id` ON DELETE CASCADE), Index | Owner user ID |
| `token_hash` | `VARCHAR(255)` | Unique, Index, NOT NULL | SHA-256 hex digest of refresh token |
| `expires_at` | `TIMESTAMPTZ` | NOT NULL | Token expiration date |
| `is_revoked` | `BOOLEAN` | NOT NULL, Default: `false` | Revocation status |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | Creation timestamp |

---

### 6. `audit_logs`
Security and audit event trail.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | Primary Key, Index | Log ID |
| `user_id` | `UUID` | Foreign Key (`users.id` ON DELETE SET NULL), Index | Subject user ID |
| `action` | `VARCHAR(100)` | Index, NOT NULL | Event name (`login`, `logout`, `refresh`, etc.) |
| `ip_address` | `VARCHAR(50)` | NULL | Client IP address |
| `user_agent` | `VARCHAR(512)` | NULL | Client HTTP User-Agent |
| `details` | `JSON` | NULL | Additional metadata payload |
| `timestamp` | `TIMESTAMPTZ` | NOT NULL, Default: `now()` | Log timestamp |
