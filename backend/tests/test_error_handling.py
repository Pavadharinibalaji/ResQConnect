"""
Regression tests for API error paths that used to escape as HTTP 500.

A. Request validation failures must always produce a structured, JSON-serializable
   422 response, including errors raised by custom Pydantic validators (whose
   error context carries a raw exception object) and inputs such as NaN that the
   JSON parser accepts but a strict JSON encoder cannot emit.
B. PATCH /api/v1/incidents/{id}/status with an assigned_responder_id that does not
   reference an existing user must return 404 instead of a database-level 500.

These tests use a client with raise_app_exceptions=False so that server errors are
observed exactly as a real client would see them (an HTTP 500), not as a raised
exception inside the test.
"""
import json
import uuid

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text

from app.core.security import create_access_token
from app.main import app
from app.models.auth import User
from app.models.incidents import Incident


@pytest_asyncio.fixture
async def http_client(override_db, tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    transport = ASGITransport(app=app, raise_app_exceptions=False)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client


async def _user(db_session, role="citizen"):
    user = User(firebase_uid=f"eh-{uuid.uuid4()}", phone_number=f"+1444{uuid.uuid4().int % 10**7:07d}",
                role=role, is_active=True)
    db_session.add(user)
    await db_session.commit()
    return user


async def _incident(db_session, reporter, status="reported"):
    incident = Incident(title="Original title", description="Original description", category="fire",
                        severity="high", status=status, latitude=1.0, longitude=1.0,
                        reporter_id=reporter.id if reporter else None)
    db_session.add(incident)
    await db_session.commit()
    return incident.id


def _auth(user):
    return {"Authorization": f"Bearer {create_access_token(str(user.id), user.role)}"}


VALID_PROFILE = {"display_name": "Valid Name", "emergency_role": "citizen"}


def _assert_structured_422(res, field):
    assert res.status_code == 422, res.text
    assert res.headers["content-type"].startswith("application/json")
    body = json.loads(res.text)  # the body itself must be valid JSON
    json.dumps(body, allow_nan=False)  # ... and strictly serializable (no NaN/Infinity)
    assert body["success"] is False
    assert isinstance(body["detail"], list) and body["detail"]
    for error in body["detail"]:
        assert isinstance(error["loc"], list)
        assert isinstance(error["msg"], str) and error["msg"]
        assert isinstance(error["type"], str) and error["type"]
    if field is not None:
        assert any(error["loc"][-1] == field for error in body["detail"]), body["detail"]
    lowered = res.text.lower()
    assert "traceback" not in lowered and "valueerror" not in lowered
    return body


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# A. Validation error handling
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@pytest.mark.asyncio
@pytest.mark.parametrize("username", ["bad name!", "ab", "no-dashes", "x" * 31])
async def test_invalid_username_returns_structured_422(http_client, db_session, username):
    user = await _user(db_session)
    res = await http_client.put("/api/v1/profile", json={**VALID_PROFILE, "username": username}, headers=_auth(user))
    _assert_structured_422(res, "username")


@pytest.mark.asyncio
async def test_custom_validator_message_is_preserved(http_client, db_session):
    user = await _user(db_session)
    res = await http_client.put("/api/v1/profile", json={**VALID_PROFILE, "username": "bad name!"}, headers=_auth(user))
    body = _assert_structured_422(res, "username")

    error = next(e for e in body["detail"] if e["loc"][-1] == "username")
    assert error["type"] == "value_error"
    assert error["loc"] == ["body", "username"]
    assert "Username must be 3-30 characters" in error["msg"]
    assert error["ctx"]["error"] == "Username must be 3-30 characters long and contain only letters, numbers, and underscores."
    profile = (await db_session.execute(
        text("SELECT username FROM profiles WHERE user_id = :u"), {"u": user.id}
    )).scalar_one_or_none()
    assert profile is None


@pytest.mark.asyncio
async def test_valid_username_still_accepted(http_client, db_session):
    user = await _user(db_session)
    res = await http_client.put("/api/v1/profile", json={**VALID_PROFILE, "username": "@good_name"}, headers=_auth(user))
    assert res.status_code == 200, res.text
    assert res.json()["data"]["username"] == "good_name"


@pytest.mark.asyncio
@pytest.mark.parametrize("path, payload, field", [
    ("/api/v1/auth/profile-setup", {"full_name": "Valid Name", "role": ["citizen"]}, "role"),
    ("/api/v1/auth/profile-setup", {"full_name": "Valid Name", "role": {"name": "citizen"}}, "role"),
    ("/api/v1/profile", {"display_name": "Valid Name", "emergency_role": ["citizen"]}, "emergency_role"),
])
async def test_role_with_wrong_json_type_returns_422(http_client, db_session, path, payload, field):
    user = await _user(db_session)
    method = http_client.post if path.endswith("profile-setup") else http_client.put
    res = await method(path, json=payload, headers=_auth(user))
    _assert_structured_422(res, field)
    stored = (await db_session.execute(text("SELECT role FROM users WHERE id = :u"), {"u": user.id})).scalar_one()
    assert stored == "citizen"


@pytest.mark.asyncio
async def test_admin_grant_with_list_role_returns_422(http_client, db_session):
    admin = await _user(db_session, role="admin")
    target = await _user(db_session)
    res = await http_client.post(f"/api/v1/admin/users/{target.id}/roles", json={"role": ["police"]}, headers=_auth(admin))
    _assert_structured_422(res, "role")


@pytest.mark.asyncio
@pytest.mark.parametrize("path, payload, missing", [
    ("/api/v1/profile", {}, {"display_name", "emergency_role"}),
    ("/api/v1/profile", {"display_name": "Valid Name"}, {"emergency_role"}),
    ("/api/v1/auth/profile-setup", {}, {"full_name", "role"}),
])
async def test_missing_required_fields_return_422(http_client, db_session, path, payload, missing):
    user = await _user(db_session)
    method = http_client.post if path.endswith("profile-setup") else http_client.put
    res = await method(path, json=payload, headers=_auth(user))
    body = _assert_structured_422(res, sorted(missing)[0])
    reported = {e["loc"][-1] for e in body["detail"] if e["type"] == "missing"}
    assert reported == missing


@pytest.mark.asyncio
@pytest.mark.parametrize("raw, field", [
    ('{"display_name": "Valid Name", "emergency_role": "citizen", "response_radius_km": "far"}', "response_radius_km"),
    ('{"display_name": "Valid Name", "emergency_role": "citizen", "response_radius_km": 999}', "response_radius_km"),
    ('{"display_name": "Valid Name", "emergency_role": "citizen", "response_radius_km": NaN}', "response_radius_km"),
    ('{"display_name": "Valid Name", "emergency_role": "citizen", "response_radius_km": Infinity}', "response_radius_km"),
    ('{"display_name": "Valid Name", "emergency_role": "citizen", "skills": "first-aid"}', "skills"),
    ('{"display_name": "V", "emergency_role": "citizen"}', "display_name"),
    ('{"display_name": "Valid Name", "emergency_role": "citizen"', None),  # truncated JSON
])
async def test_malformed_body_values_return_422(http_client, db_session, raw, field):
    user = await _user(db_session)
    res = await http_client.put(
        "/api/v1/profile", content=raw,
        headers={**_auth(user), "Content-Type": "application/json"},
    )
    body = _assert_structured_422(res, field)
    if field is None:
        assert [e["type"] for e in body["detail"]] == ["json_invalid"]


@pytest.mark.asyncio
async def test_malformed_path_parameter_returns_422(http_client, db_session):
    user = await _user(db_session)
    res = await http_client.patch("/api/v1/incidents/not-a-uuid/status", json={"status": "cancelled"}, headers=_auth(user))
    _assert_structured_422(res, "incident_id")


@pytest.mark.asyncio
async def test_non_utf8_json_body_is_a_client_error(http_client, db_session):
    user = await _user(db_session)
    res = await http_client.put(
        "/api/v1/profile", content=b'{"display_name": "\xff\xfe"}',
        headers={**_auth(user), "Content-Type": "application/json"},
    )
    # FastAPI rejects an undecodable body itself with 400 before validation runs.
    assert res.status_code == 400, res.text
    assert json.loads(res.text)["detail"] == "There was an error parsing the body"


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# B. assigned_responder_id
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

async def _stored(db_session, incident_id):
    return (await db_session.execute(
        text("SELECT status, title, assigned_responder_id FROM incidents WHERE id = :i"), {"i": incident_id}
    )).one()


async def _patch(client, incident_id, payload, headers):
    return await client.patch(f"/api/v1/incidents/{incident_id}/status", json=payload, headers=headers)


@pytest.mark.asyncio
@pytest.mark.parametrize("actor_role", ["reporter", "admin"])
async def test_valid_assigned_responder_is_saved(http_client, db_session, actor_role):
    reporter = await _user(db_session)
    responder = await _user(db_session, role="volunteer")
    actor = reporter if actor_role == "reporter" else await _user(db_session, role="admin")
    incident_id = await _incident(db_session, reporter)

    res = await _patch(http_client, incident_id, {"assigned_responder_id": str(responder.id)}, _auth(actor))
    assert res.status_code == 200, res.text
    assert res.json()["data"]["assigned_responder_id"] == str(responder.id)
    assert (await _stored(db_session, incident_id)).assigned_responder_id == responder.id


@pytest.mark.asyncio
async def test_valid_assignment_together_with_status_change(http_client, db_session):
    reporter = await _user(db_session)
    responder = await _user(db_session)
    incident_id = await _incident(db_session, reporter)

    res = await _patch(http_client, incident_id,
                       {"status": "verified", "assigned_responder_id": str(responder.id)}, _auth(reporter))
    assert res.status_code == 200, res.text
    stored = await _stored(db_session, incident_id)
    assert (stored.status, stored.assigned_responder_id) == ("verified", responder.id)


@pytest.mark.asyncio
@pytest.mark.parametrize("actor_role", ["reporter", "admin"])
async def test_nonexistent_assigned_responder_returns_404(http_client, db_session, actor_role):
    reporter = await _user(db_session)
    actor = reporter if actor_role == "reporter" else await _user(db_session, role="admin")
    incident_id = await _incident(db_session, reporter)

    res = await _patch(http_client, incident_id, {"assigned_responder_id": str(uuid.uuid4())}, _auth(actor))
    assert res.status_code == 404, res.text
    body = res.json()
    assert body["detail"] == "Assigned responder not found."
    assert "foreign key" not in res.text.lower() and "integrity" not in res.text.lower()
    assert (await _stored(db_session, incident_id)).assigned_responder_id is None


@pytest.mark.asyncio
async def test_nonexistent_assigned_responder_applies_no_other_change(http_client, db_session):
    reporter = await _user(db_session)
    incident_id = await _incident(db_session, reporter)

    res = await _patch(http_client, incident_id,
                       {"status": "verified", "title": "Changed", "assigned_responder_id": str(uuid.uuid4())},
                       _auth(reporter))
    assert res.status_code == 404, res.text
    stored = await _stored(db_session, incident_id)
    assert (stored.status, stored.title, stored.assigned_responder_id) == ("reported", "Original title", None)


@pytest.mark.asyncio
async def test_nonexistent_assigned_responder_keeps_existing_assignment(http_client, db_session):
    reporter = await _user(db_session)
    responder = await _user(db_session)
    incident_id = await _incident(db_session, reporter)
    assert (await _patch(http_client, incident_id, {"assigned_responder_id": str(responder.id)},
                         _auth(reporter))).status_code == 200

    res = await _patch(http_client, incident_id, {"assigned_responder_id": str(uuid.uuid4())}, _auth(reporter))
    assert res.status_code == 404, res.text
    assert (await _stored(db_session, incident_id)).assigned_responder_id == responder.id

    # Omitting the field leaves the assignment untouched (unchanged behaviour).
    res = await _patch(http_client, incident_id, {"title": "New title"}, _auth(reporter))
    assert res.status_code == 200, res.text
    assert (await _stored(db_session, incident_id)).assigned_responder_id == responder.id


@pytest.mark.asyncio
@pytest.mark.parametrize("value", ["not-a-uuid", 12345, ["00000000-0000-0000-0000-000000000000"]])
async def test_malformed_assigned_responder_returns_422(http_client, db_session, value):
    reporter = await _user(db_session)
    incident_id = await _incident(db_session, reporter)

    res = await _patch(http_client, incident_id, {"assigned_responder_id": value}, _auth(reporter))
    _assert_structured_422(res, "assigned_responder_id")
    assert (await _stored(db_session, incident_id)).assigned_responder_id is None


@pytest.mark.asyncio
@pytest.mark.parametrize("target_exists", [True, False])
async def test_unrelated_user_still_forbidden_before_responder_lookup(http_client, db_session, target_exists):
    reporter = await _user(db_session)
    other = await _user(db_session, role="police")
    target = await _user(db_session) if target_exists else None
    incident_id = await _incident(db_session, reporter)

    responder_id = str(target.id) if target else str(uuid.uuid4())
    res = await _patch(http_client, incident_id, {"assigned_responder_id": responder_id}, _auth(other))
    # Authorization is decided first, so outsiders cannot probe which user ids exist.
    assert res.status_code == 403, res.text
    assert (await _stored(db_session, incident_id)).assigned_responder_id is None


@pytest.mark.asyncio
async def test_unauthenticated_assignment_rejected(http_client, db_session):
    reporter = await _user(db_session)
    incident_id = await _incident(db_session, reporter)

    res = await _patch(http_client, incident_id, {"assigned_responder_id": str(uuid.uuid4())}, {})
    assert res.status_code == 401
    assert (await _stored(db_session, incident_id)).assigned_responder_id is None
