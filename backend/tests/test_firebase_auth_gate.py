"""
Security regression tests: the development Firebase shortcut must only work when
ENVIRONMENT is "development".

Outside development, /auth/verify-firebase must never accept the `mock-token-*`
shortcut or an unsigned/self-made JWT, even when the Firebase Admin SDK
credentials are missing.

Limitation: a *successful* real Firebase verification needs Google-signed ID
tokens and cannot be integration-tested offline. The SDK boundary is tested by
checking that, outside development, the Admin SDK verifier is the only thing
consulted and that its rejection is surfaced as 401.
"""
import time

import jwt as pyjwt
import pytest
from sqlalchemy import text

import app.core.firebase_auth as firebase_auth
from app.core.config import settings

VERIFY_URL = "/api/v1/auth/verify-firebase"


def _forged_unsigned_style_token(phone: str) -> str:
    # Signed with an attacker-chosen key; the dev decoder ignores signatures.
    return pyjwt.encode(
        {"sub": "attacker-chosen-uid", "phone_number": phone, "exp": int(time.time()) + 3600},
        "attacker-chosen-signing-key-0123456789abcdef",
        algorithm="HS256",
    )


async def _users_with_phone(db_session, phone: str) -> int:
    return (await db_session.execute(
        text("SELECT count(*) FROM users WHERE phone_number = :p"), {"p": phone}
    )).scalar()


@pytest.fixture
def environment(monkeypatch):
    def _set(value: str):
        monkeypatch.setattr(settings, "ENVIRONMENT", value)
    return _set


@pytest.fixture
def sdk_not_configured(monkeypatch):
    monkeypatch.setattr(firebase_auth, "firebase_initialized", False)


@pytest.mark.asyncio
async def test_development_shortcut_still_works_in_development(async_client, db_session, environment, sdk_not_configured):
    environment("development")
    res = await async_client.post(VERIFY_URL, json={"id_token": "mock-token-+15550001001"})

    assert res.status_code == 200
    data = res.json()["data"]
    assert data["user"]["phone_number"] == "+15550001001"
    assert data["access_token"]
    assert await _users_with_phone(db_session, "+15550001001") == 1


@pytest.mark.asyncio
@pytest.mark.parametrize("env", ["production", "staging", "PRODUCTION", ""])
async def test_mock_shortcut_rejected_outside_development(async_client, db_session, environment, sdk_not_configured, env):
    environment(env)
    res = await async_client.post(VERIFY_URL, json={"id_token": "mock-token-+15550001002"})

    assert res.status_code == 401
    assert "access_token" not in res.text
    assert await _users_with_phone(db_session, "+15550001002") == 0


@pytest.mark.asyncio
async def test_forged_jwt_rejected_in_production(async_client, db_session, environment, sdk_not_configured):
    environment("production")
    res = await async_client.post(VERIFY_URL, json={"id_token": _forged_unsigned_style_token("+15550001003")})

    assert res.status_code == 401
    assert "access_token" not in res.text
    assert await _users_with_phone(db_session, "+15550001003") == 0


@pytest.mark.asyncio
async def test_rejection_does_not_leak_configuration_details(async_client, environment, sdk_not_configured):
    environment("production")
    res = await async_client.post(VERIFY_URL, json={"id_token": "mock-token-+15550001004"})

    assert res.status_code == 401
    body = res.text.lower()
    for leak in ("credential", "adminsdk", "development", ".json", "traceback"):
        assert leak not in body


@pytest.mark.asyncio
async def test_production_uses_admin_sdk_and_rejects_invalid_token(async_client, db_session, environment, monkeypatch):
    environment("production")
    monkeypatch.setattr(firebase_auth, "firebase_initialized", True)
    calls = []

    def rejecting_verify_id_token(token, *args, **kwargs):
        calls.append(token)
        raise ValueError("Token signature verification failed")

    monkeypatch.setattr(firebase_auth.auth, "verify_id_token", rejecting_verify_id_token)

    for token in ("mock-token-+15550001005", _forged_unsigned_style_token("+15550001005"), "garbage"):
        res = await async_client.post(VERIFY_URL, json={"id_token": token})
        assert res.status_code == 401
    assert len(calls) == 3
    assert await _users_with_phone(db_session, "+15550001005") == 0


@pytest.mark.asyncio
async def test_invalid_token_rejected_in_development(async_client, environment, sdk_not_configured):
    environment("development")
    res = await async_client.post(VERIFY_URL, json={"id_token": "not-a-jwt"})
    assert res.status_code == 401
