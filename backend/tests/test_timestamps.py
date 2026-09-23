"""
Timestamp correctness: every timestamp the application produces must be
timezone-aware UTC, and must survive PostgreSQL (timestamptz) and the API as the
same instant.

Background: asyncpg interprets a *naive* datetime bound to a timestamptz column
in the host's local timezone, so naive `datetime.utcnow()` values were shifted
by the host's UTC offset (e.g. -5:30 on an IST machine). The aware-UTC checks
below catch the cause on any host; the instant comparisons catch the shift on
any non-UTC host.
"""
import uuid
from datetime import datetime, timedelta, timezone

import pytest
from jose import jwt
from sqlalchemy import text

from app.core.config import settings
from app.core.security import create_access_token, create_refresh_token
from app.models.auth import User
from app.models.incidents import Incident

INCIDENT_PAYLOAD = {
    "title": "Timestamp Incident",
    "description": "Checking timestamp semantics",
    "category": "medical",
    "severity": "low",
    "latitude": 12.9716,
    "longitude": 77.5946,
}


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _assert_utc(value: datetime) -> None:
    assert value.tzinfo is not None, f"naive datetime: {value!r}"
    assert value.utcoffset() == timedelta(0), f"not UTC: {value!r}"


def _parse_utc(raw: str) -> datetime:
    value = datetime.fromisoformat(raw)
    _assert_utc(value)
    return value


async def _create_user(db_session, phone: str) -> User:
    user = User(firebase_uid=f"ts-{uuid.uuid4()}", phone_number=phone, role="citizen", is_active=True)
    db_session.add(user)
    await db_session.commit()
    return user


def _auth(user: User) -> dict:
    return {"Authorization": f"Bearer {create_access_token(str(user.id), user.role)}"}


@pytest.mark.asyncio
async def test_orm_default_timestamps_round_trip_through_postgres(db_session):
    before = _utc_now()
    user = User(firebase_uid=f"ts-{uuid.uuid4()}", phone_number="+17770000001", role="citizen")
    incident = Incident(
        title="t", description="d", category="fire", severity="low",
        status="reported", latitude=0.0, longitude=0.0,
    )
    db_session.add_all([user, incident])
    await db_session.flush()
    after = _utc_now()

    for obj, table in ((user, "users"), (incident, "incidents")):
        _assert_utc(obj.created_at)
        _assert_utc(obj.updated_at)
        assert before <= obj.created_at <= after

        stored = (await db_session.execute(
            text(f"SELECT created_at, updated_at FROM {table} WHERE id = :id"), {"id": obj.id}
        )).one()
        assert stored.created_at == obj.created_at
        assert stored.updated_at == obj.updated_at


@pytest.mark.asyncio
async def test_incident_api_timestamps_preserve_the_same_instant(async_client, db_session):
    user = await _create_user(db_session, "+17770000002")

    before = _utc_now()
    create_res = await async_client.post("/api/v1/incidents", json=INCIDENT_PAYLOAD, headers=_auth(user))
    after = _utc_now()
    assert create_res.status_code == 201
    body = create_res.json()
    created = body["data"]

    created_at = _parse_utc(created["created_at"])
    updated_at = _parse_utc(created["updated_at"])
    assert before <= created_at <= after
    _parse_utc(body["timestamp"])  # response envelope timestamp

    stored = (await db_session.execute(
        text("SELECT created_at, updated_at FROM incidents WHERE id = :id"), {"id": created["id"]}
    )).one()
    assert stored.created_at == created_at
    assert stored.updated_at == updated_at

    detail_res = await async_client.get(f"/api/v1/incidents/{created['id']}")
    assert detail_res.status_code == 200
    assert _parse_utc(detail_res.json()["data"]["created_at"]) == created_at
    assert _parse_utc(detail_res.json()["data"]["updated_at"]) == updated_at


@pytest.mark.asyncio
async def test_responder_service_timestamps_are_utc_instants(async_client, db_session):
    reporter = await _create_user(db_session, "+17770000003")
    responder = await _create_user(db_session, "+17770000004")
    create_res = await async_client.post("/api/v1/incidents", json=INCIDENT_PAYLOAD, headers=_auth(reporter))
    incident_id = create_res.json()["data"]["id"]

    before = _utc_now()
    respond_res = await async_client.post(f"/api/v1/incidents/{incident_id}/respond", headers=_auth(responder))
    assert respond_res.status_code == 200
    complete_res = await async_client.patch(
        f"/api/v1/incidents/{incident_id}/responders/me/status",
        json={"status": "completed"},
        headers=_auth(responder),
    )
    after = _utc_now()
    assert complete_res.status_code == 200

    entry = complete_res.json()["data"]["responders"][0]
    joined_at = _parse_utc(entry["joined_at"])
    updated_at = _parse_utc(entry["updated_at"])
    completed_at = _parse_utc(entry["completed_at"])
    for value in (joined_at, updated_at, completed_at):
        assert before <= value <= after

    stored = (await db_session.execute(
        text("SELECT joined_at, updated_at, completed_at FROM incident_responders WHERE id = :id"),
        {"id": entry["id"]},
    )).one()
    assert (stored.joined_at, stored.updated_at, stored.completed_at) == (joined_at, updated_at, completed_at)


def test_jwt_expiry_is_relative_to_current_utc_time():
    before = int(_utc_now().timestamp())
    access = jwt.decode(create_access_token(str(uuid.uuid4()), "citizen"), settings.SECRET_KEY,
                        algorithms=[settings.JWT_ALGORITHM])
    refresh = jwt.decode(create_refresh_token(str(uuid.uuid4())), settings.SECRET_KEY,
                         algorithms=[settings.JWT_ALGORITHM])
    after = int(_utc_now().timestamp()) + 1

    access_ttl = settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60
    assert before + access_ttl <= access["exp"] <= after + access_ttl

    refresh_ttl = 30 * 24 * 60 * 60
    assert before + refresh_ttl <= refresh["exp"] <= after + refresh_ttl
