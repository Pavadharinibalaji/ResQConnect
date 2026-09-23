import os
import secrets

# Point every settings-derived database URL at the test database BEFORE the app
# (and its module-level engines) is imported. Credentials still come from .env;
# only the database name differs. Override with TEST_POSTGRES_DB if needed.
TEST_DB_NAME = os.environ.get("TEST_POSTGRES_DB", "resqconnect_test")
if not TEST_DB_NAME.endswith("_test"):
    raise RuntimeError(
        f"Refusing to run tests against '{TEST_DB_NAME}': test database name must end with '_test'."
    )
os.environ["POSTGRES_DB"] = TEST_DB_NAME
# ENVIRONMENT is required by Settings; the suite runs as an explicit development
# environment instead of depending on a developer's local .env file.
os.environ["ENVIRONMENT"] = "development"
# Tests sign JWTs with a throwaway key generated per run, never the developer's real
# SECRET_KEY. POSTGRES_PASSWORD still comes from the local .env (the test DB server).
os.environ["SECRET_KEY"] = secrets.token_urlsafe(48)

import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.pool import NullPool

from app.core.config import settings
from app.core.database import get_db as core_get_db
from app.dependencies.database import get_db as legacy_get_db
from app.main import app


@pytest_asyncio.fixture
async def db_connection():
    """
    One connection per test, inside an outer transaction that is always rolled back.

    NullPool: the connection is opened on this test's event loop and truly closed
    at teardown, so no asyncpg connection can outlive the loop that created it.
    """
    engine = create_async_engine(settings.async_database_uri, poolclass=NullPool)
    assert engine.url.database == TEST_DB_NAME, f"Test engine points at {engine.url.database!r}"

    async with engine.connect() as connection:
        outer = await connection.begin()
        try:
            yield connection
        finally:
            if outer.is_active:
                await outer.rollback()
    await engine.dispose()


def _session_for(connection) -> AsyncSession:
    # Same options as app.core.database.SessionLocal. "create_savepoint" turns the
    # session's own commit()/rollback() into RELEASE / ROLLBACK TO SAVEPOINT, so the
    # outer transaction above is never committed.
    return AsyncSession(
        bind=connection,
        join_transaction_mode="create_savepoint",
        autoflush=False,
        expire_on_commit=False,
    )


@pytest_asyncio.fixture
async def db_session(db_connection):
    """Session for arranging/inspecting data directly within the test's transaction."""
    session = _session_for(db_connection)
    try:
        yield session
    finally:
        await session.close()


@pytest_asyncio.fixture
async def override_db(db_connection):
    """
    Route both production get_db dependencies to the test connection.

    Each request gets its own session (as in production), bound to the shared test
    connection, and each override mirrors its production counterpart's
    commit/rollback/close behaviour.
    """

    async def _core_get_db():
        async with _session_for(db_connection) as session:
            try:
                yield session
                await session.commit()
            except Exception:
                await session.rollback()
                raise
            finally:
                await session.close()

    async def _legacy_get_db():
        async with _session_for(db_connection) as session:
            try:
                yield session
            finally:
                await session.close()

    app.dependency_overrides[core_get_db] = _core_get_db
    app.dependency_overrides[legacy_get_db] = _legacy_get_db
    try:
        yield
    finally:
        # Remove only our keys; tests may manage their own overrides.
        app.dependency_overrides.pop(core_get_db, None)
        app.dependency_overrides.pop(legacy_get_db, None)


@pytest_asyncio.fixture
async def async_client(override_db, tmp_path, monkeypatch):
    # The app writes uploads to the CWD-relative "static/uploads/evidence" and
    # serves "/static" from the CWD-relative "static" directory, so running each
    # API test from its own tmp_path keeps uploaded files out of the repository.
    monkeypatch.chdir(tmp_path)

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client
