# Deployment & Production Containers

This guide details how to build, run, and scale **ResQConnect** services using Docker container configurations.

---

## 🛠 Docker Architecture

We use a modular, containerized layout to run the FastAPI app and the PostGIS spatial database.

### 📦 Multi-Stage Builds (FastAPI)
The backend uses a multi-stage [Dockerfile](file:///c:/Users/Admin/AI-ML/ResQConnect/backend/Dockerfile) structure:
1. **Builder Stage**: Uses `python:3.13-slim` base, installs compilation components (`build-essential`, `libpq-dev`), and compiles python packages into a local path.
2. **Runner Stage**: Uses a fresh, minimal `python:3.13-slim` image, copies over only the compiled libraries, copies app source files, and exposes port `8000`. This reduces the final image size and eliminates build-time security vectors.

---

## 🚀 Docker Compose Setup

Services are orchestrated using the [docker-compose.yml](file:///c:/Users/Admin/AI-ML/ResQConnect/deployment/docker-compose.yml) container map in `deployment/`:

- **Database (`db`)**:
  - Image: `postgis/postgis:15-3.3` (adds PostGIS geographical functions).
  - Volumes: Maps `postgres_data` volume to `/var/lib/postgresql/data` for file system persistence.
  - Restart: `unless-stopped` (reboots on crashes unless explicitly shut down).
  - Healthcheck: Runs `pg_isready -U postgres -d resqconnect` to query database availability.

- **Backend (`backend`)**:
  - Build context: References the local `backend/` directory.
  - Environment: Injects `../backend/.env.production` as environment variables (Task 10). This file holds production secrets: it is git-ignored and excluded from the image, so create it on the deployment host (never commit it). The Firebase service-account JSON must also be provided at runtime (e.g. a mounted secret referenced by `FIREBASE_CREDENTIALS_PATH`); the server refuses to start in production without it.
  - Depends On: Wait condition set to wait for `db` to pass its `service_healthy` check before starting.
  - Healthcheck: Queries `/api/v1/health` using `curl` every 15s to confirm server health.

---

## ⚙ Production Commands

### Start Services
Navigate to `deployment/` and run:
```bash
docker compose up --build -d
```

### Stop Services
```bash
docker compose down
```

### Inspect Container Logs
```bash
docker compose logs -f backend
```

---

## 📱 Mobile Release Builds

Release builds must name their environment explicitly; without it the app refuses to start rather than falling back to development behaviour:

```bash
flutter build appbundle --release --dart-define=APP_ENV=production
flutter build apk --release --dart-define=APP_ENV=staging
```

Never pass `DEV_AUTH_BYPASS=true` to a staging/production or release build: the app treats it as a configuration error. See [Installation.md](Installation.md#build-configuration---dart-define) for all mobile build settings.

Toolchain: Flutter 3.47.5 (stable) with JDK 17 and the Android SDK; `pubspec.lock` requires Dart ≥ 3.11. The APK is written to `mobile/build/app/outputs/flutter-apk/app-release.apk` and the bundle to `mobile/build/app/outputs/bundle/release/app-release.aab`. `mobile/android/app/google-services.json` (Firebase client configuration, not a secret) must be present for the Android build.

CI (`.github/workflows/flutter.yml`) runs `flutter analyze`, `flutter test` in the default, production and explicit development-bypass configurations, and builds the production release APK. It uses no secrets and publishes nothing.

### Android release signing (deployment prerequisite)

Release builds are currently signed with the **debug key** (`android/app/build.gradle.kts`: `release { signingConfig = signingConfigs.getByName("debug") }`). That is enough to build and side-load test APKs, but Google Play rejects debug-signed uploads and the debug key is not a stable identity for updates. Before publishing:

1. The release owner creates an upload keystore **outside the repository**, e.g. `keytool -genkeypair -v -keystore ~/resqconnect-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`, and enrols in Play App Signing.
2. Create `mobile/android/key.properties` (git-ignored, never committed) on the build machine:
   ```properties
   storePassword=<from your secret store>
   keyPassword=<from your secret store>
   keyAlias=upload
   storeFile=<absolute path to the .jks>
   ```
3. In `android/app/build.gradle.kts`, load `key.properties`, add a `signingConfigs.create("release")` from it, use it for `buildTypes.release`, and make release builds fail when it is missing instead of falling back to the debug key.
4. In CI, provide the keystore and passwords only as encrypted CI secrets (for example a base64-encoded keystore decoded at build time); never commit them.

`key.properties`, `*.jks` and `*.keystore` are already git-ignored in `mobile/android/.gitignore`.
