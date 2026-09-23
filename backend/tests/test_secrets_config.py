"""
Secrets hygiene.

- SECRET_KEY and POSTGRES_PASSWORD have no source-code fallbacks: they must be
  supplied by the environment / .env in every ENVIRONMENT.
- Configuration errors never echo secret values.
- Secret-bearing files (.env*, Firebase service accounts, logs) cannot be staged by Git,
  while .env.example stays trackable and contains placeholders only.

All secret values used here are generated per test run; real local values are only
compared in memory and never included in assertion output.
"""
import secrets
import shutil
import subprocess
from pathlib import Path

import pytest
from dotenv import dotenv_values
from pydantic import ValidationError

from app.core.config import Settings

BACKEND_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = BACKEND_DIR.parent
SECRET_ENV_KEYS = ("ENVIRONMENT", "SECRET_KEY", "POSTGRES_PASSWORD")


def _generated_secret_key() -> str:
    return secrets.token_urlsafe(48)


def _generated_db_password() -> str:
    return secrets.token_urlsafe(16)


def _settings(monkeypatch, **env) -> Settings:
    """Settings built only from the given variables (no .env file)."""
    for key in SECRET_ENV_KEYS:
        monkeypatch.delenv(key, raising=False)
    for key, value in env.items():
        monkeypatch.setenv(key, value)
    return Settings(_env_file=None)


def _valid_env(**overrides) -> dict:
    env = {
        "ENVIRONMENT": "development",
        "SECRET_KEY": _generated_secret_key(),
        "POSTGRES_PASSWORD": _generated_db_password(),
    }
    env.update(overrides)
    return {k: v for k, v in env.items() if v is not None}


# ------------------------------------------------------------------ required secrets

def test_secrets_have_no_source_code_defaults():
    assert Settings.model_fields["SECRET_KEY"].is_required()
    assert Settings.model_fields["POSTGRES_PASSWORD"].is_required()


@pytest.mark.parametrize("environment", ["development", "staging", "production"])
def test_missing_secret_key_fails(monkeypatch, environment):
    with pytest.raises(ValidationError) as exc_info:
        _settings(monkeypatch, **_valid_env(ENVIRONMENT=environment, SECRET_KEY=None))
    assert "SECRET_KEY" in str(exc_info.value)


@pytest.mark.parametrize("environment", ["development", "staging", "production"])
def test_missing_database_password_fails(monkeypatch, environment):
    with pytest.raises(ValidationError) as exc_info:
        _settings(monkeypatch, **_valid_env(ENVIRONMENT=environment, POSTGRES_PASSWORD=None))
    assert "POSTGRES_PASSWORD" in str(exc_info.value)


@pytest.mark.parametrize("environment", ["development", "staging", "production"])
def test_explicit_secrets_are_accepted(monkeypatch, environment):
    env = _valid_env(ENVIRONMENT=environment)
    config = _settings(monkeypatch, **env)
    assert config.SECRET_KEY == env["SECRET_KEY"]
    assert config.POSTGRES_PASSWORD == env["POSTGRES_PASSWORD"]
    assert env["POSTGRES_PASSWORD"] in config.async_database_uri


@pytest.mark.parametrize("bad_key", [
    "",
    "   ",
    "x" * 31,                               # too short
    "replace-with-a-long-random-secret",    # the .env.example placeholder
    "  replace-with-a-long-random-secret-and-more-padding  ",
])
def test_weak_or_placeholder_secret_key_rejected(monkeypatch, bad_key):
    with pytest.raises(ValidationError) as exc_info:
        _settings(monkeypatch, **_valid_env(SECRET_KEY=bad_key))
    assert "SECRET_KEY" in str(exc_info.value)


@pytest.mark.parametrize("bad_password", ["", "   "])
def test_empty_database_password_rejected(monkeypatch, bad_password):
    with pytest.raises(ValidationError) as exc_info:
        _settings(monkeypatch, **_valid_env(POSTGRES_PASSWORD=bad_password))
    assert "POSTGRES_PASSWORD" in str(exc_info.value)


def test_configuration_errors_do_not_echo_secret_values(monkeypatch):
    short_key = "short-" + secrets.token_hex(8)          # invalid: too short
    db_password = _generated_db_password()
    with pytest.raises(ValidationError) as exc_info:
        _settings(monkeypatch, **_valid_env(SECRET_KEY=short_key, POSTGRES_PASSWORD=db_password, ENVIRONMENT="bogus"))
    message = str(exc_info.value)
    leaked = short_key in message or db_password in message or "bogus" in message
    assert not leaked, "a configuration error message contains an input value"


# ------------------------------------------------------------------------ .env.example

def test_env_example_contains_placeholders_only():
    example = dotenv_values(BACKEND_DIR / ".env.example")
    assert example["ENVIRONMENT"] == "development"
    assert "replace-with" in example["SECRET_KEY"]
    assert "replace-with" in example["POSTGRES_PASSWORD"]
    assert "FIREBASE_CREDENTIALS_PATH" in example

    real_values = set()
    for name in (".env", ".env.development", ".env.production"):
        path = BACKEND_DIR / name
        if path.exists():
            for key, value in dotenv_values(path).items():
                if value and any(word in key for word in ("SECRET", "PASSWORD", "DATABASE_URL")):
                    real_values.add(value)
    leaked = any(value in (example_value or "") for value in real_values for example_value in example.values())
    assert not leaked, "a real local secret value appears in .env.example"


def test_env_example_is_valid_but_placeholder_key_cannot_be_used(monkeypatch):
    for key in SECRET_ENV_KEYS:
        monkeypatch.delenv(key, raising=False)
    with pytest.raises(ValidationError) as exc_info:
        Settings(_env_file=BACKEND_DIR / ".env.example")
    errors = exc_info.value.errors()
    assert [e["loc"] for e in errors] == [("SECRET_KEY",)]


# ---------------------------------------------------------------------------- Git safety

needs_git = pytest.mark.skipif(
    shutil.which("git") is None or not (REPO_ROOT / ".git").exists(),
    reason="git repository not available",
)


def _git(*args) -> subprocess.CompletedProcess:
    return subprocess.run(["git", *args], cwd=REPO_ROOT, capture_output=True, text=True)


def _ignored(relpath: str) -> bool:
    # --no-index also covers files that do not exist yet or are already tracked.
    return _git("check-ignore", "-q", "--no-index", relpath).returncode == 0


@needs_git
@pytest.mark.parametrize("relpath", [
    "backend/.env",
    "backend/.env.development",
    "backend/.env.production",
    "backend/.env.staging",
    "backend/.env.local",
    "mobile/.env",
    "backend/firebase-adminsdk.json",
    "backend/resqconnect-f1a23-firebase-adminsdk-abc12-0123456789.json",
    "backend/service-account.json",
    "backend/secrets/service-account-prod.json",
    "backend/logs/app.log",
    "backend/logs/errors.log",
    "mobile/android/hs_err_pid1234.log",
])
def test_secret_bearing_files_are_git_ignored(relpath):
    assert _ignored(relpath), f"{relpath} could be committed"


@needs_git
@pytest.mark.parametrize("relpath", [
    "backend/.env.example",
    "backend/app/core/config.py",
    "backend/requirements.txt",
    "backend/alembic.ini",
    "mobile/lib/config/env.dart",
    "mobile/lib/firebase_options.dart",
    "docs/EnvironmentVariables.md",
])
def test_safe_files_remain_trackable(relpath):
    assert not _ignored(relpath), f"{relpath} is ignored but must be trackable"


@needs_git
def test_no_secret_file_is_tracked():
    tracked = _git("ls-files").stdout.splitlines()
    offenders = [
        path for path in tracked
        if (Path(path).name.startswith(".env") and Path(path).name != ".env.example")
        or "adminsdk" in path or Path(path).name.startswith("service-account")
    ]
    assert offenders == []
