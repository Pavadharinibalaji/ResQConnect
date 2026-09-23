"""
Security regression tests for PATCH /api/v1/incidents/{id}/status.

Rule: only the incident's reporter or an admin (primary role or user_roles, as in
RoleChecker) may update an incident. Self-selectable roles (citizen, volunteer,
ngo, police, fire, ambulance) and joining as a responder grant nothing here.
"""
import uuid

import pytest
from sqlalchemy import select, text

from app.core.security import create_access_token
from app.models.auth import Role, User
from app.models.incidents import Incident
from app.models.responders import IncidentResponder


async def _user(db_session, role="citizen", extra_roles=()):
    user = User(firebase_uid=f"sa-{uuid.uuid4()}", phone_number=f"+1333{uuid.uuid4().int % 10**7:07d}",
                role=role, is_active=True)
    if extra_roles:
        roles = (await db_session.execute(select(Role).where(Role.name.in_(extra_roles)))).scalars().all()
        assert {r.name for r in roles} == set(extra_roles)
        user.roles.extend(roles)
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


async def _stored(db_session, incident_id):
    return (await db_session.execute(
        text("SELECT status, title, description FROM incidents WHERE id = :i"), {"i": incident_id}
    )).one()


async def _patch(async_client, incident_id, payload, headers):
    return await async_client.patch(f"/api/v1/incidents/{incident_id}/status", json=payload, headers=headers)


@pytest.mark.asyncio
async def test_unauthenticated_request_rejected(async_client, db_session):
    reporter = await _user(db_session)
    incident_id = await _incident(db_session, reporter)

    res = await _patch(async_client, incident_id, {"status": "cancelled"}, {})
    assert res.status_code == 401
    assert (await _stored(db_session, incident_id)).status == "reported"


@pytest.mark.asyncio
@pytest.mark.parametrize("role", ["citizen", "volunteer", "ngo", "police", "fire", "ambulance"])
async def test_unrelated_user_cannot_change_status(async_client, db_session, role):
    reporter = await _user(db_session)
    other = await _user(db_session, role=role)
    incident_id = await _incident(db_session, reporter)

    res = await _patch(async_client, incident_id, {"status": "cancelled"}, _auth(other))
    assert res.status_code == 403
    assert "traceback" not in res.text.lower()
    assert (await _stored(db_session, incident_id)).status == "reported"


@pytest.mark.asyncio
async def test_unrelated_user_cannot_change_other_fields(async_client, db_session):
    reporter = await _user(db_session)
    other = await _user(db_session)
    incident_id = await _incident(db_session, reporter)

    res = await _patch(async_client, incident_id, {"title": "Hijacked", "description": "Hijacked"}, _auth(other))
    assert res.status_code == 403
    stored = await _stored(db_session, incident_id)
    assert (stored.title, stored.description) == ("Original title", "Original description")


@pytest.mark.asyncio
async def test_responder_who_is_not_reporter_cannot_change_status(async_client, db_session):
    reporter = await _user(db_session)
    responder = await _user(db_session, role="fire")
    incident_id = await _incident(db_session, reporter, status="active")
    db_session.add(IncidentResponder(incident_id=incident_id, user_id=responder.id, status="responding"))
    await db_session.commit()

    res = await _patch(async_client, incident_id, {"status": "resolved"}, _auth(responder))
    assert res.status_code == 403
    assert (await _stored(db_session, incident_id)).status == "active"


@pytest.mark.asyncio
async def test_incident_without_reporter_cannot_be_changed_by_regular_user(async_client, db_session):
    user = await _user(db_session)
    incident_id = await _incident(db_session, None)

    res = await _patch(async_client, incident_id, {"status": "cancelled"}, _auth(user))
    assert res.status_code == 403
    assert (await _stored(db_session, incident_id)).status == "reported"


@pytest.mark.asyncio
async def test_reporter_can_walk_valid_transitions(async_client, db_session):
    reporter = await _user(db_session)
    incident_id = await _incident(db_session, reporter)

    for new_status in ("verified", "active", "resolved"):
        res = await _patch(async_client, incident_id, {"status": new_status}, _auth(reporter))
        assert res.status_code == 200, res.text
        assert res.json()["data"]["status"] == new_status
        assert (await _stored(db_session, incident_id)).status == new_status


@pytest.mark.asyncio
@pytest.mark.parametrize("admin_kwargs", [{"role": "admin"}, {"role": "citizen", "extra_roles": ("admin",)}])
async def test_admin_can_change_any_incident(async_client, db_session, admin_kwargs):
    reporter = await _user(db_session)
    admin = await _user(db_session, **admin_kwargs)
    incident_id = await _incident(db_session, reporter)

    res = await _patch(async_client, incident_id, {"status": "cancelled"}, _auth(admin))
    assert res.status_code == 200, res.text
    assert (await _stored(db_session, incident_id)).status == "cancelled"


@pytest.mark.asyncio
@pytest.mark.parametrize("start, target", [("resolved", "active"), ("reported", "banana")])
async def test_invalid_transition_or_value_still_rejected_for_reporter(async_client, db_session, start, target):
    reporter = await _user(db_session)
    incident_id = await _incident(db_session, reporter, status=start)

    res = await _patch(async_client, incident_id, {"status": target}, _auth(reporter))
    assert res.status_code == 400
    assert (await _stored(db_session, incident_id)).status == start


@pytest.mark.asyncio
async def test_missing_incident_returns_404(async_client, db_session):
    user = await _user(db_session)
    res = await _patch(async_client, uuid.uuid4(), {"status": "cancelled"}, _auth(user))
    assert res.status_code == 404
