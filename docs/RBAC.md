# Role-Based Access Control (RBAC) Architecture

This document defines the Role-Based Access Control (RBAC) system implemented in **ResQConnect**.

---

## 👥 System Roles

ResQConnect has seven roles, seeded into the `roles` table by migration. They fall into three categories (defined once in `backend/app/core/roles.py`):

| Category | Roles | How a user gets it |
| :--- | :--- | :--- |
| **Self-service** | `citizen`, `volunteer` | Chosen by the user (`POST /api/v1/auth/profile-setup`, `PUT /api/v1/profile`). New users start as `citizen`. |
| **Admin-granted (organizational)** | `ngo`, `police`, `fire`, `ambulance` | Only an admin can grant or revoke them (`/api/v1/admin/users/{user_id}/roles`). |
| **Admin** | `admin` | Only an existing admin can grant or revoke it. There is no self-service or signup path. |

> **Authorization, not identity verification.** An admin grant records that an administrator vouched for the user. ResQConnect does **not** verify real-world credentials (badges, licences, organizations).

---

## 🗄 Where roles are stored

- `user_roles` (many-to-many with `roles`) is the **trusted** record of what a user holds. Privileged roles (`ngo`, `police`, `fire`, `ambulance`, `admin`) are written there **only** by the admin role endpoints. Self-service records only `citizen`/`volunteer`.
- `users.role` is the primary/display role (also placed in the JWT `role` claim, which is **never** used for authorization). Self-service may set it to `citizen`, `volunteer`, or an organizational role the user already holds in `user_roles`.
- `profiles.emergency_role` mirrors the primary role for the profile screen, under the same rule.

Unknown names (`administrator`, `superadmin`, `police_officer`, `firefighter`, …) never map onto a real role. Self-service trims and lower-cases input; the admin endpoints require exact role names.

---

## 🛡 Backend Authorization

The backend is authoritative; UI choices are never trusted.

### Admin
`is_admin(user)` in `app/core/roles.py` is the **only** admin check (used by incident authorization, evidence authorization, `RoleChecker` and the admin API):

- `users.role == "admin"`, or
- `admin` present in `user_roles`.

`police`, `fire`, `ambulance`, `ngo`, `volunteer` and `citizen` never imply admin.

### Role management API (admin only)

| Method | Path | Body | Result |
| :--- | :--- | :--- | :--- |
| `POST` | `/api/v1/admin/users/{user_id}/roles` | `{"role": "police"}` | Grants `ngo`/`police`/`fire`/`ambulance`/`admin` (idempotent). |
| `DELETE` | `/api/v1/admin/users/{user_id}/roles/{role}` | – | Revokes the role; a primary/profile role that relied on it falls back to `citizen`. |

Rules: non-admins get `403`; admins cannot change **their own** roles (`403`), which also guarantees the acting admin keeps admin rights, so the last admin can never be removed through the API; `citizen`/`volunteer`/unknown roles get `400`; unknown users `404`; revoking a role the user does not hold `404`. Grants and revocations are written to the audit log.

**Bootstrapping the first admin** has no API path by design: insert the `admin` role for that user into `user_roles` directly in the database.

### Incident-scoped permissions
A profile role is **not** proof of incident participation. Incident responder status is a separate relationship (`incident_responders`): evidence access requires being the reporter, a non-withdrawn responder of that incident, or an admin; incident status changes require being the reporter or an admin.

### `RoleChecker`
`RoleChecker(allowed_roles=[...])` (`app/middleware/rbac.py`) remains available for future role-gated endpoints: admins bypass it; others need a matching role in `user_roles` or their primary role. Because privileged roles can only be admin-granted, such checks cannot be satisfied by self-selection.

---

## 📱 Frontend Route Guarding

In the Flutter application, route protection is managed via `GoRouter` in `lib/routes/app_router.dart`:

- **Unauthenticated Users**: Blocked from accessing protected routes (`/home`, `/feed`, `/profile`) and redirected to `/welcome`.
- **Incomplete Profiles**: Users who signed in for the first time are directed to `/profile-setup` until full name and role are selected.
- **Role Guards**: Restricted sections inspect `authState.user?.role` to ensure appropriate permissions before building views.

UI guards are presentation only; the backend enforces every permission. The profile-setup screen still lists `ngo`/`police`/`fire`/`ambulance`: selecting one without an admin grant is rejected by the API (`403`).
