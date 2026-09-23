# Installation & Local Setup

Follow these steps to set up **ResQConnect** locally.

---

## 📋 Prerequisites

Before running the application, make sure you have the following installed:
- **Flutter SDK** (3.47.5 stable, as used by CI; `pubspec.lock` needs Dart 3.11 or newer) & Dart SDK
- **Python** (3.13 or newer)
- **Docker & Docker Compose** (optional, recommended for database support)

---

## 📱 Mobile Setup (Flutter)

1. Navigate to the mobile directory:
   ```bash
   cd mobile
   ```

2. Download package dependencies:
   ```bash
   flutter pub get
   ```

3. Launch the application:
   ```bash
   flutter run
   ```

### Build configuration (`--dart-define`)

The mobile environment is chosen at build time (`lib/config/env.dart`); there is no runtime or UI switch.

| Define | Values | Default |
| :--- | :--- | :--- |
| `APP_ENV` | `development`, `staging`, `production` | `development` in **debug** builds only. **Required** for profile/release builds. |
| `DEV_AUTH_BYPASS` | `true`, `false` | `false`. `true` is accepted only with `APP_ENV=development` in a **debug** build. |
| `API_BASE_URL` | Backend origin, e.g. `http://192.168.1.20:8000` | Per environment (development: the LAN address in `env.dart`). |

The development auth bypass skips the backend JWT exchange after Firebase OTP (for devices that cannot reach the local backend). It is opt-in and never available in staging, production or release builds.

**Fail closed:** a missing `APP_ENV` in a profile/release build, an unknown `APP_ENV`, a `DEV_AUTH_BYPASS` value other than `true`/`false`, or `DEV_AUTH_BYPASS=true` outside a development debug build makes the app show a "not configured correctly" screen and stop: Firebase, authentication and API calls never start, and the bypass stays off. A bypass session stored by an earlier development build is discarded when the bypass is off.

```bash
# Development (debug, real Firebase + local backend)
flutter run --dart-define=APP_ENV=development --dart-define=API_BASE_URL=http://<LAN-IP>:8000

# Development with the auth bypass (debug only, opt-in)
flutter run --dart-define=APP_ENV=development --dart-define=DEV_AUTH_BYPASS=true

# Staging
flutter run --release --dart-define=APP_ENV=staging
flutter build apk --release --dart-define=APP_ENV=staging

# Production / release
flutter build apk --release --dart-define=APP_ENV=production
flutter build appbundle --release --dart-define=APP_ENV=production
flutter build ipa --release --dart-define=APP_ENV=production
```

Staging and production use `https://staging-api.resqconnect.com` / `https://api.resqconnect.com` unless `API_BASE_URL` is given. Phone sign-in always uses real Firebase Authentication (`lib/firebase_options.dart`).

Tests: `flutter test` runs with the bypass off (the default); `flutter test --dart-define=APP_ENV=development --dart-define=DEV_AUTH_BYPASS=true` exercises the bypass paths.

---

## 🐍 Backend Setup (FastAPI & PostgreSQL)

### Configuration Sources
The FastAPI backend reads settings from process environment variables and from `backend/.env` (environment variables win). The `ENVIRONMENT` variable does not select a file: `.env.development` / `.env.production` are never loaded automatically. `ENVIRONMENT`, `SECRET_KEY` and `POSTGRES_PASSWORD` are required and have no defaults. All `.env*` files except `.env.example` are git-ignored and must never be committed. See [EnvironmentVariables.md](EnvironmentVariables.md).

---

### Option A: Run via Docker (Recommended)

To run the entire server stack (FastAPI app + PostGIS database) in isolated containers:

1. Navigate to the deployment folder:
   ```bash
   cd deployment
   ```

2. Spin up containers in the background:
   ```bash
   docker compose up --build -d
   ```

3. Verify service health:
   - FastAPI server: [http://localhost:8000/api/v1/](http://localhost:8000/api/v1/)
   - API Docs (Swagger): [http://localhost:8000/docs](http://localhost:8000/docs)
   - Healthcheck endpoint: [http://localhost:8000/api/v1/health](http://localhost:8000/api/v1/health)

---

### Option B: Local Manual Setup

If you prefer to run the FastAPI app directly on your host machine:

1. Navigate to the backend folder:
   ```bash
   cd backend
   ```

2. Create a virtual environment:
   ```bash
   python -m venv venv
   ```

3. Activate the environment:
   - **Windows**: `venv\Scripts\activate`
   - **macOS/Linux**: `source venv/bin/activate`

4. Install the requirements:
   ```bash
   pip install -r requirements.txt
   ```

5. Configure environmental parameters:
   Create your local `.env` from the placeholder template, then fill in real local values
   (`ENVIRONMENT="development"`, your local `POSTGRES_PASSWORD`, and a generated `SECRET_KEY`):
   ```bash
   cp .env.example .env
   # Generate a SECRET_KEY:
   python -c "import secrets; print(secrets.token_urlsafe(48))"
   ```
   `.env` is git-ignored; never commit it.

6. Start the FastAPI development server:
   ```bash
   # Set ENVIRONMENT variable to load the desired config file
   # Windows PowerShell:
   $env:ENVIRONMENT="development"; uvicorn app.main:app --reload
   
   # Command Prompt / Linux:
   set ENVIRONMENT=development && uvicorn app.main:app --reload
   ```

---

## 📝 Inspecting Local Logs

Once the API starts running, logs are automatically collected inside the `backend/logs/` directory:
- **`logs/app.log`**: Standard operational logs.
- **`logs/access.log`**: Detailed HTTP log lines tracking transaction Request ID, API path, HTTP status, and response latency.
- **`logs/errors.log`**: Captures stack traces of caught exceptions and failures.
