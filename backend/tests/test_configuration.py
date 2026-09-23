"""
Configuration security boundary.

- ENVIRONMENT must be set explicitly; it is normalised (trim + lower-case) and must be
  one of development / staging / production. Nothing defaults to development.
- Outside development the application refuses to start unless the Firebase Admin SDK
  is initialised, so the unverified development token decoder can never be the only
  authentication path of a running non-development server.
- The Docker build context excludes secrets and local artefacts.

No real credentials are used: "configured" is simulated by the SDK-initialised flag,
and secret values are compared, never printed.
"""
import os
import re
import secrets
import socket
import subprocess
import sys
from pathlib import Path

import pytest
from pydantic import ValidationError

import app.core.firebase_auth as firebase_auth
from app.core.config import Settings, settings
from app.main import app, lifespan

BACKEND_DIR = Path(__file__).resolve().parents[1]
VERIFY_URL = "/api/v1/auth/verify-firebase"


def _settings_from_env(monkeypatch, **env):
    """Build Settings from the given environment only (no .env file).

    Required secrets get generated test-only values unless the test provides them.
    """
    monkeypatch.delenv("ENVIRONMENT", raising=False)
    monkeypatch.setenv("SECRET_KEY", secrets.token_urlsafe(48))
    monkeypatch.setenv("POSTGRES_PASSWORD", secrets.token_urlsafe(16))
    for key, value in env.items():
        monkeypatch.setenv(key, value)
    return Settings(_env_file=None)


# --------------------------------------------------------------------------- ENVIRONMENT

def test_environment_is_required(monkeypatch):
    with pytest.raises(ValidationError) as exc_info:
        _settings_from_env(monkeypatch)
    assert "ENVIRONMENT" in str(exc_info.value)


@pytest.mark.parametrize("raw, expected", [
    ("development", "development"),
    ("DEVELOPMENT", "development"),
    ("  Development \n", "development"),
    ("production", "production"),
    (" PRODUCTION", "production"),
    ("Staging", "staging"),
])
def test_environment_is_normalised(monkeypatch, raw, expected):
    assert _settings_from_env(monkeypatch, ENVIRONMENT=raw).ENVIRONMENT == expected


@pytest.mark.parametrize("raw", ["", "   ", "dev", "prod", "test", "local", "developement", "development,production"])
def test_unknown_environment_is_rejected(monkeypatch, raw):
    with pytest.raises(ValidationError):
        _settings_from_env(monkeypatch, ENVIRONMENT=raw)


def test_configuration_error_does_not_leak_secrets(monkeypatch):
    secret_key = "secret-key-marker-7f3a9c"
    db_password = "db-password-marker-51be02"
    with pytest.raises(ValidationError) as exc_info:
        _settings_from_env(monkeypatch, ENVIRONMENT="bogus", SECRET_KEY=secret_key, POSTGRES_PASSWORD=db_password)
    message = str(exc_info.value)
    assert secret_key not in message
    assert db_password not in message


# ------------------------------------------------------------- development token shortcut

@pytest.mark.parametrize("raw, allowed", [
    ("development", True),
    ("  DEVELOPMENT ", True),
    ("production", False),
    ("staging", False),
    ("", False),
    ("dev", False),
    ("local", False),
    ("test", False),
])
def test_development_shortcut_gate(monkeypatch, raw, allowed):
    monkeypatch.setattr(settings, "ENVIRONMENT", raw)
    assert firebase_auth._development_auth_allowed() is allowed


@pytest.mark.asyncio
@pytest.mark.parametrize("raw", ["dev", "local", "test", "unset-value"])
async def test_unknown_environment_cannot_use_shortcut_over_http(async_client, monkeypatch, raw):
    monkeypatch.setattr(settings, "ENVIRONMENT", raw)
    monkeypatch.setattr(firebase_auth, "firebase_initialized", False)
    res = await async_client.post(VERIFY_URL, json={"id_token": "mock-token-+15550009001"})
    assert res.status_code == 401


# ------------------------------------------------------------ Firebase startup validation

@pytest.mark.asyncio
@pytest.mark.parametrize("env", ["production", "staging"])
async def test_startup_fails_without_firebase_outside_development(monkeypatch, env):
    monkeypatch.setattr(settings, "ENVIRONMENT", env)
    monkeypatch.setattr(firebase_auth, "firebase_initialized", False)

    with pytest.raises(RuntimeError, match="Firebase"):
        async with lifespan(app):
            pass


@pytest.mark.asyncio
@pytest.mark.parametrize("env", ["production", "staging"])
async def test_startup_succeeds_with_firebase_outside_development(monkeypatch, env):
    monkeypatch.setattr(settings, "ENVIRONMENT", env)
    monkeypatch.setattr(firebase_auth, "firebase_initialized", True)

    async with lifespan(app):
        pass


@pytest.mark.asyncio
async def test_development_starts_without_firebase_credentials(monkeypatch):
    monkeypatch.setattr(settings, "ENVIRONMENT", "development")
    monkeypatch.setattr(firebase_auth, "firebase_initialized", False)

    async with lifespan(app):
        pass


@pytest.mark.asyncio
async def test_startup_failure_message_has_no_secrets(monkeypatch):
    monkeypatch.setattr(settings, "ENVIRONMENT", "production")
    monkeypatch.setattr(settings, "FIREBASE_CREDENTIALS_PATH", "/run/secrets/credential-path-marker-9d1e.json")
    monkeypatch.setattr(firebase_auth, "firebase_initialized", False)

    with pytest.raises(RuntimeError) as exc_info:
        async with lifespan(app):
            pass
    message = str(exc_info.value)
    for secret in (settings.SECRET_KEY, settings.POSTGRES_PASSWORD, "credential-path-marker-9d1e"):
        assert secret not in message


def _free_port() -> int:
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def test_production_server_process_refuses_to_start_without_firebase(tmp_path):
    env = dict(os.environ)
    env.update({
        "ENVIRONMENT": "production",
        "FIREBASE_CREDENTIALS_PATH": str(tmp_path / "missing-service-account.json"),
        "PYTHONUNBUFFERED": "1",
    })
    port = _free_port()
    try:
        proc = subprocess.run(
            [sys.executable, "-m", "uvicorn", "app.main:app", "--host", "127.0.0.1", "--port", str(port)],
            cwd=BACKEND_DIR, env=env, capture_output=True, text=True, timeout=45,
        )
    except subprocess.TimeoutExpired:
        pytest.fail("production server kept running without Firebase configuration")

    output = proc.stdout + proc.stderr
    assert proc.returncode != 0
    assert "Application startup failed" in output
    assert "Firebase" in output
    for secret in (settings.SECRET_KEY, settings.POSTGRES_PASSWORD):
        assert secret not in output


# --------------------------------------------------------------------- Docker build context

def _dockerignore_rules():
    path = BACKEND_DIR / ".dockerignore"
    assert path.exists(), "backend/.dockerignore is missing"
    rules = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        negate = line.startswith("!")
        pattern = line[1:] if negate else line
        rules.append((negate, pattern.strip("/")))
    return rules


def _pattern_regex(pattern: str) -> re.Pattern:
    # Approximation of Docker's matcher: '*' and '?' stay within one path segment,
    # '**' spans any number of segments, '[...]' is a character class.
    out, i = "", 0
    while i < len(pattern):
        if pattern[i] == "[" and "]" in pattern[i + 1:]:
            end = pattern.index("]", i + 1)
            body = pattern[i + 1:end]
            out, i = out + "[" + ("^" + body[1:] if body.startswith("^") else body) + "]", end + 1
        elif pattern.startswith("**/", i):
            out, i = out + "(?:.*/)?", i + 3
        elif pattern.startswith("**", i):
            out, i = out + ".*", i + 2
        elif pattern[i] == "*":
            out, i = out + "[^/]*", i + 1
        elif pattern[i] == "?":
            out, i = out + "[^/]", i + 1
        else:
            out, i = out + re.escape(pattern[i]), i + 1
    return re.compile(out + r"\Z")


def _excluded(relpath: str, rules) -> bool:
    parts = relpath.split("/")
    candidates = ["/".join(parts[:n]) for n in range(1, len(parts) + 1)]
    excluded = False
    for negate, pattern in rules:
        regex = _pattern_regex(pattern)
        if any(regex.match(candidate) for candidate in candidates):
            excluded = not negate
    return excluded


@pytest.mark.parametrize("relpath", [
    ".env", ".env.development", ".env.production", ".env.example", ".env.staging.local",
    ".venv/Lib/site-packages/fastapi/__init__.py", "venv/bin/python",
    "logs/app.log", "logs/errors.log", "debug.log",
    ".pytest_cache/v/cache/nodeids", "app/__pycache__/main.cpython-312.pyc", "app/core/x.pyc",
    "tests/test_evidence.py", "pytest.ini", ".coverage", "htmlcov/index.html",
    "static/uploads/evidence/abc.jpg",
    "firebase-adminsdk.json", "resqconnect-f1a23-firebase-adminsdk-abc12.json", "service-account.json",
    ".git/config",
])
def test_dockerignore_excludes_sensitive_and_local_files(relpath):
    assert _excluded(relpath, _dockerignore_rules()), f"{relpath} would be sent to the Docker build context"


@pytest.mark.parametrize("relpath", [
    "app/main.py", "app/api/v1/incidents.py", "app/core/config.py", "app/utils/evidence.py",
    "requirements.txt", "alembic.ini", "alembic/env.py", "alembic/versions/2026_08_16_0003_create_incident_evidence.py",
    "Dockerfile",
])
def test_dockerignore_keeps_runtime_files(relpath):
    assert not _excluded(relpath, _dockerignore_rules()), f"{relpath} is required by the image but excluded"
