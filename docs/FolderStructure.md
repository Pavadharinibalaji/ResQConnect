# Folder Structure Map

This is a comprehensive map of the **ResQConnect** project repository, showing where components are located and their architectural purpose.

---

## 📂 Codebase Directory Layout

```
ResQConnect/
├── .github/
│   └── workflows/               # CI/CD workflows (GitHub Actions)
│       ├── flutter.yml          # Flutter test and analyzer build pipeline
│       └── backend.yml          # Backend test and compile build pipeline
│
├── mobile/                      # Flutter mobile client app
│   ├── lib/
│   │   ├── config/              # App environment properties & constants
│   │   ├── core/
│   │   │   ├── theme/           # FlexColorScheme and typography settings
│   │   │   ├── constants/       # Secure storage keys and visual dimensions
│   │   │   ├── network/         # Dio Client and request-id interceptor
│   │   │   ├── storage/         # Secure keychain storage driver wrapper
│   │   │   ├── logger/          # Console developer logging helpers
│   │   │   ├── errors/          # Custom failures entities (ServerFailure, etc.)
│   │   │   ├── validators/      # Text input validators (phone, code)
│   │   │   ├── extensions/      # BuildContext and layout shorthand helper properties
│   │   │   └── utils/           # Time and date formatting tools
│   │   ├── routes/              # GoRouter configuration & routes path names
│   │   ├── services/            # Low-level service adapters (Secure Storage, etc.)
│   │   ├── shared/
│   │   │   └── widgets/         # Reusable global widgets (Buttons, Cards, Layouts, etc.)
│   │   ├── features/            # Feature modules (Feature-First Architecture)
│   │   │   ├── auth/            # Authentication feature module
│   │   │   │   ├── data/        # Api calls and auth implementation repositories
│   │   │   │   ├── domain/      # Domain entity models and usecases
│   │   │   │   └── presentation/# UI components (Pages, Widgets, Riverpod providers)
│   │   │   └── feed/            # Emergency incidents feed feature module
│   │   └── main.dart            # Flutter application entry file
│   └── pubspec.yaml             # Dart packages and assets registry
│
├── backend/                     # FastAPI python server app
│   ├── app/
│   │   ├── api/                 # Versioned router endpoints
│   │   │   ├── router.py        # Central Router resolving v1 and fallbacks
│   │   │   └── v1/
│   │   │       └── endpoints.py # GET /, /health, and /version endpoints
│   │   ├── core/                # DB connections, security helpers, environment configurations
│   │   │   ├── config.py        # Pydantic Settings env loader (dev, prod, example)
│   │   │   ├── logging.py       # Custom console and rotating file logging setup
│   │   │   ├── exceptions.py    # Global exception handlings mappings
│   │   │   └── database.py      # SQLAlchemy 2.0 Async Session engine setup
│   │   ├── models/              # SQLAlchemy database structures
│   │   ├── schemas/             # Pydantic validation input/output schemas
│   │   │   └── response.py      # Unified StandardResponse and ErrorResponse schemas
│   │   ├── services/            # Core business workflows
│   │   ├── repositories/        # Database SQL execution helpers
│   │   ├── middleware/          # FastAPI middleware hooks (logging, auth filters)
│   │   │   └── request_id.py    # Global X-Request-ID propagation interceptor
│   │   ├── utils/               # Helper utilities
│   │   └── main.py              # Server main bootstrap entry file
│   ├── alembic/                 # Alembic migration scripts registry
│   │   └── versions/            # Actual migration scripts
│   │       └── 0001_initial.py  # Initial migration enabling PostGIS
│   ├── logs/                    # Local rotating log outputs (app.log, access.log, etc.)
│   ├── alembic.ini              # Alembic command configuration mapper
│   ├── requirements.txt         # Python package dependencies registry
│   ├── .env.example             # Documented configurations template
│   ├── .env.development         # Local development environments settings
│   └── .env.production          # Hardened production container settings
│
├── database/                    # SQL schema definitions and custom migration tools
├── docs/                        # Architectural documents and installation manuals
└── deployment/                  # Docker container orchestration configurations
    └── docker-compose.yml       # Orchestrates services and mounts persistent volumes
```

---

## 🛠 Directory Conventions

1. **Feature-First**: In `mobile/lib/features/`, features must remain modular. A feature should never import presentation components from another feature. Shared cross-module elements belong in `mobile/lib/shared/`.
2. **Modular API**: In `backend/app/`, endpoints are separated by concern. Route functions handle HTTP validation using Pydantic, delegating business operations to services and sql statements to repositories.
