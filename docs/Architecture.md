# Architecture & Design Standards

This document describes the architectural layout, core design decisions, and architectural patterns implemented in **ResQConnect**.

---

## 🏛 Clean Architecture Principles

We adhere strictly to Clean Architecture to separate software concerns, ensuring the code remains:
- **Independent of Frameworks**: The business logic is not bound to Flutter or FastAPI details.
- **Testable**: Core business rules (usecases/domain models) can be verified without external databases or UI widgets.
- **Independent of UI**: The UI can change without altering the core business engine.
- **Independent of Database**: SQL tables and query layers are separated from operational domain logic.

```
       ┌────────────────────────┐
       │      Presentation      │ (UI, Pages, Widgets, Providers)
       └───────────┬────────────┘
                   │  Depends On
       ┌───────────▼────────────┐
       │         Domain         │ (Models, Usecases, Repository Interfaces)
       └───────────▲────────────┘
                   │  Implemented By
       ┌───────────┴────────────┐
       │          Data          │ (Datasources, Repositories Implementation)
       └────────────────────────┘
```

---

## 📱 Mobile Architecture: Feature-First & MVVM

The Flutter app is structured **Feature-First**. Every feature package (e.g. `auth`, `feed`) is divided into three distinct Clean Architecture layers:

### 1. Data Layer
Contains all database models, server network calls (using Dio), local cached storage (using Flutter Secure Storage), and API repositories.
- `datasources/`: Raw network requests and file caching.
- `repositories/`: Implements the abstract Repository signatures defined in the Domain layer, converting database payloads to clean Domain models.

### 2. Domain Layer
The core business hub. Contains only pure Dart code without external framework dependencies.
- `models/`: Plain domain entities (e.g., `UserModel`).
- `repositories/`: Abstract interface definitions prescribing the features the Data layer must implement.
- `usecases/`: Isolated single-responsibility business workflows (e.g., `VerifyPhone`).

### 3. Presentation Layer
Defines user layout widgets and screen rendering controllers.
- `pages/`: Stateful/Stateless page layouts (Splash, Login, Home, etc.).
- `widgets/`: Small, reusable, presentation-scoped widgets.
- `providers/`: State management controllers (using Riverpod `StateNotifier`) acting as the ViewModels in MVVM to fetch, format, and push state changes to pages.

---

## 🔒 Enterprise Hardened Additions (Core)

1. **Dio Client Interceptor**: Located in `core/network/dio_client.dart`. It wraps connection options, automatically appends bearer authorization tokens, generates a unique client-side `X-Request-ID` transaction token for every call, and prints networking states to logs.
2. **Secure Keyring Storage**: Located in `core/storage/secure_storage.dart`. Wraps secure keychain data caching with detailed error catch flows.
3. **Reusable Form Validation & Extensions**: Located in `core/validators/` and `core/extensions/`. Handles format checking (phone formats, verification digits) and shorthand visual queries.

---

## 🐍 Backend Architecture: Modular FastAPI

The backend implements a Clean Architecture modular structure in Python:
- **`app/api/`**: Exposes versioned URL routes (under `/api/v1/` prefix). Handles request parsing and maps validation schemas (Pydantic).
- **`app/core/`**: Central configs (database engines, JWT algorithms, logging pipelines).
- **`app/models/`**: Declarative database tables (SQLAlchemy 2.0).
- **`app/schemas/`**: Pydantic v2 schemas validating request payloads and formatting JSON responses.
- **`app/services/`**: Coordinates complex business transactions.
- **`app/repositories/`**: Isolates direct SQL commands, keeping the rest of the application agnostic of DB drivers.

---

## 🛡 Enterprise Hardened Backend Components

1. **Request ID Contextvars Tracking**: Implemented in `app/middleware/request_id.py`. Sets a unique UUID for every incoming HTTP call, tracks execution time in milliseconds, and exposes `X-Request-ID` in headers.
2. **Centralized Exception Handling**: Implemented in `app/core/exceptions.py`. Converts validation, HTTP, database (SQLAlchemy connection failures), and unhandled server errors into standardized JSON payloads, masking raw stack traces from clients.
3. **Rotating Log Collection**: Implemented in `app/core/logging.py`. Saves rotating access logs (`access.log`), system operational logs (`app.log`), and error reports (`errors.log`) to a centralized `logs/` directory.

---

## 💾 Database & Geospatial Engineering

We use **PostgreSQL** with **PostGIS** spatial mapping:
1. **Migrations**: Managed by **Alembic** under the async database URL connection configuration. The initial migration version enables the spatial `postgis` extension.
2. **Asynchronous Connection**: FastAPI uses SQLAlchemy 2.0 async engines (`asyncpg`) for non-blocking I/O.
3. **Spatial Indexing**: Geotagged coordinates will be indexed to allow quick distance searches (e.g., locating active responders within a 5-mile radius of a flood report).
