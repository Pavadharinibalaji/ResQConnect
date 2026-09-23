# ResQConnect Backend

This is the backend for the AI-powered emergency response platform, ResQConnect.

## Technology Stack
- FastAPI
- Python 3.12+
- Async SQLAlchemy 2.x
- PostgreSQL
- Alembic
- Pydantic v2

## Architecture
The backend is built as a **scalable modular monolith**. It contains a solid foundation in `core`, `database`, `common`, and `dependencies` which allow feature modules (`users`, `incidents`, `ai`, etc.) to grow independently and eventually be extracted into microservices if needed.

## Setup & Running

1. **Install dependencies**: 
```bash
pip install -r requirements.txt
```

2. **Set up Environment Variables**:
Copy `.env.example` to `.env` and configure your database settings.

3. **Run Database Migrations**:
```bash
alembic upgrade head
```

4. **Start the API Server**:
```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

5. **Access API Documentation**:
Go to `http://localhost:8000/docs` (Swagger UI) or `http://localhost:8000/redoc`.

## Testing
To run the automated tests:
```bash
pytest
```

The suite needs PostgreSQL with PostGIS and a migrated database whose name ends in `_test` (default `resqconnect_test`, override with `TEST_POSTGRES_DB`); it never touches the development database. `tests/conftest.py` sets `ENVIRONMENT=development` and a random `SECRET_KEY`; the database connection comes from `POSTGRES_*` (environment variables or `.env`). No Firebase credentials are needed.

```bash
alembic upgrade head   # against the test database (POSTGRES_DB=resqconnect_test)
pytest -q
```

### Continuous integration
`.github/workflows/backend.yml` runs the complete suite on every backend change: a disposable `postgis/postgis:18-3.6` service container with CI-only credentials, a fresh `resqconnect_test` database, `alembic upgrade head` (checked against the head revision), a PostGIS/schema check, then `pytest -q`. The job fails if any test is skipped. It uses no real secrets (the `SECRET_KEY` is generated per run) and deploys nothing.
