# Environment Variables Guide

This document describes the environment configuration parameters used by the **ResQConnect** FastAPI server.

---

## 📂 Configuration Files

Settings are loaded by Pydantic Settings (`app/core/config.py`) from exactly two sources:

1. **Process environment variables** (highest priority) — how staging/production receive their configuration, e.g. docker-compose `env_file: ../backend/.env.production`.
2. **`.env`** in the working directory (`backend/`) — the local development file.

The `ENVIRONMENT` variable does **not** select a file: `.env.development` and `.env.production` are never read automatically.

| File | Committed? | Purpose |
|---|---|---|
| `.env.example` | **Yes** | Placeholder-only template. Copy it to `.env` and fill in real values. |
| `.env` | No (git-ignored) | Local development configuration with real local credentials. |
| `.env.development`, `.env.production`, any other `.env.*` | No (git-ignored) | Local copies / deployment-host files. Never commit them. |

### 🔐 Secrets

- **Required, no defaults:** `ENVIRONMENT`, `SECRET_KEY` (at least 32 random characters; the `.env.example` placeholder is rejected) and `POSTGRES_PASSWORD`. The application refuses to start if any is missing or invalid, and configuration errors never echo the configured values.
- Generate a `SECRET_KEY` with `python -c "import secrets; print(secrets.token_urlsafe(48))"`. Use a different key per environment.
- Staging/production secrets are supplied by the deployment (environment variables / container secrets), never committed.
- The Firebase Admin SDK service-account JSON (`FIREBASE_CREDENTIALS_PATH`) is a private key: never commit it (git-ignored patterns: `*firebase-adminsdk*.json`, `*-adminsdk-*.json`, `service-account*.json`) and never bake it into an image (excluded by `backend/.dockerignore`). Mount it at runtime.

---

## ⚙ Config Variable Mappings

| Variable | Type | Default (Dev) | Description |
|---|---|---|---|
| **`PROJECT_NAME`** | String | `ResQConnect API` | Display name of the application. |
| **`ENVIRONMENT`** | String | *Required (no default)* | Runtime environment: `development`, `staging` or `production` (trimmed, case-insensitive; any other value is rejected at startup). Development-only behaviour, such as unverified Firebase token decoding, is enabled only by `development`. |
| **`FIREBASE_CREDENTIALS_PATH`** | String | `firebase-adminsdk.json` | Path to the Firebase Admin SDK service account file. Required outside `development`: the server refuses to start in `staging`/`production` if it cannot be loaded. Provide it at runtime (mounted secret); it is excluded from the Docker build context. |
| **`DEBUG_MODE`** | Boolean | `true` | When `true`, logs remain verbose and stack trace detail is returned in error payloads. Set to `false` in production. |
| **`POSTGRES_SERVER`**| String | `localhost` | Database server address host. (Matches container name `db` in prod compose). |
| **`POSTGRES_USER`** | String | `postgres` | User account for database access. |
| **`POSTGRES_PASSWORD`**| String | *Required (no default)* | Password for database access. Must be non-empty; use a strong, environment-specific value. |
| **`POSTGRES_DB`** | String | `resqconnect` | Target PostgreSQL database name. |
| **`POSTGRES_PORT`** | Integer| `5432` | PostgreSQL database connection port. |
| **`DATABASE_URL`** | String | *Auto-Assembled* | Async database link URL (`postgresql+asyncpg://...`). |
| **`SECRET_KEY`** | String | *Required (no default)* | JWT signing key. At least 32 random characters, unique per environment; placeholder values are rejected at startup. Changing it invalidates all issued tokens. |
| **`JWT_ALGORITHM`** | String | `HS256` | Encryption algorithm to sign tokens. |
| **`ACCESS_TOKEN_EXPIRE_MINUTES`** | Integer | `10080` | Access token lifespan in minutes (10080 = 7 days). |
| **`FIREBASE_PROJECT_ID`** | String | `resqconnect-f1a23`| Target Google cloud project identifier for mobile authentication services. |
| **`LOG_LEVEL`** | String | `INFO` | Base logging threshold level (`DEBUG`, `INFO`, `WARNING`, `ERROR`). |
| **`BACKEND_CORS_ORIGINS`** | Array | `["*"]` | JSON formatted list of origins authorized to access backend APIs. |
