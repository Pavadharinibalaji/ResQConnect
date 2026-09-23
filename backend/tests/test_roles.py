"""
Role verification / RBAC foundation.

- Self-service (profile-setup, PUT /profile) may select citizen/volunteer, or a role the
  user already holds through an admin grant (user_roles). It never writes privileged
  roles into user_roles.
- Only admins (single is_admin definition) grant/revoke ngo/police/fire/ambulance/admin,
  never for themselves.
- Organisational roles never imply admin.
"""
import uuid

import pytest
from sqlalchemy import select, text

from app.core.roles import ADMIN_GRANTABLE_ROLES, ORGANIZATIONAL_ROLES, SELF_SELECTABLE_ROLES, is_admin
from app.core.security import create_access_token
from app.models.auth import Role, User
from app.models.incidents import Incident

ORG_ROLES = ["ngo", "police", "fire", "ambulance"]
PRIVILEGED = ORG_ROLES + ["admin"]
BOGUS_ROLES = ["administrator", "superadmin", "police_officer", "firefighter", "root", "Admin ", " POLICE"]


# ----------------------------------------------------------------------------- helpers

async def _user(db_session, role="citizen", granted=()):
    user = User(firebase_uid=f"rb-{uuid.uuid4()}", phone_number=f"+1111{uuid.uuid4().int % 10**7:07d}",
                role=role, is_active=True)
    if granted:
        roles = (await db_session.execute(select(Role).where(Role.name.in_(granted)))).scalars().all()
        assert {r.name for r in roles} == set(granted)
        user.roles.extend(roles)
    db_session.add(user)
    await db_session.commit()
    return user


def _auth(user, role_claim=None):
    return {"Authorization": f"Bearer {create_access_token(str(user.id), role_claim or user.role)}"}


async def _state(db_session, user):
    """(primary role, sorted user_roles names, profile emergency_role or None) straight from the DB."""
    primary = (await db_session.execute(text("SELECT role FROM users WHERE id = :u"), {"u": user.id})).scalar()
    granted = sorted((await db_session.execute(text(
        "SELECT r.name FROM user_roles ur JOIN roles r ON r.id = ur.role_id WHERE ur.user_id = :u"), {"u": user.id}
    )).scalars().all())
    emergency = (await db_session.execute(
        text("SELECT emergency_role FROM profiles WHERE user_id = :u"), {"u": user.id})).scalar()
    return primary, granted, emergency


async def _profile_setup(async_client, user, role, **extra):
    return await async_client.post("/api/v1/auth/profile-setup", headers=_auth(user),
                                   json={"full_name": "Test User", "role": role, **extra})


async def _put_profile(async_client, user, emergency_role, **extra):
    return await async_client.put("/api/v1/profile", headers=_auth(user),
                                  json={"display_name": "Test User", "emergency_role": emergency_role, **extra})


async def _grant(async_client, actor, target_id, role, headers=None):
    return await async_client.post(f"/api/v1/admin/users/{target_id}/roles", json={"role": role},
                                   headers=headers if headers is not None else _auth(actor))


async def _revoke(async_client, actor, target_id, role, headers=None):
    return await async_client.delete(f"/api/v1/admin/users/{target_id}/roles/{role}",
                                     headers=headers if headers is not None else _auth(actor))


# ------------------------------------------------------------------------ role categories

def test_role_categories_are_explicit():
    assert SELF_SELECTABLE_ROLES == {"citizen", "volunteer"}
    assert ORGANIZATIONAL_ROLES == {"ngo", "police", "fire", "ambulance"}
    assert ADMIN_GRANTABLE_ROLES == {"ngo", "police", "fire", "ambulance", "admin"}


# --------------------------------------------------------------------------- self-service

@pytest.mark.asyncio
@pytest.mark.parametrize("role", ["citizen", "volunteer", "VOLUNTEER"])
async def test_profile_setup_allows_self_selectable_roles(async_client, db_session, role):
    user = await _user(db_session)
    res = await _profile_setup(async_client, user, role)
    assert res.status_code == 200, res.text
    primary, granted, _ = await _state(db_session, user)
    assert primary == role.lower()
    assert not set(granted) & set(PRIVILEGED)


@pytest.mark.asyncio
@pytest.mark.parametrize("role", PRIVILEGED + ["Police", " FIRE "])
async def test_profile_setup_rejects_privileged_roles(async_client, db_session, role):
    user = await _user(db_session)
    res = await _profile_setup(async_client, user, role)
    assert res.status_code == 403
    assert await _state(db_session, user) == ("citizen", [], None)


@pytest.mark.asyncio
@pytest.mark.parametrize("role", BOGUS_ROLES[:5])
async def test_profile_setup_rejects_unknown_role_names(async_client, db_session, role):
    user = await _user(db_session)
    res = await _profile_setup(async_client, user, role)
    assert res.status_code == 400
    assert await _state(db_session, user) == ("citizen", [], None)


@pytest.mark.asyncio
async def test_profile_setup_ignores_injected_role_fields(async_client, db_session):
    user = await _user(db_session)
    res = await _profile_setup(async_client, user, "citizen", roles=["admin"], is_admin=True, role_ids=["x"])
    assert res.status_code == 200
    primary, granted, _ = await _state(db_session, user)
    assert primary == "citizen" and not set(granted) & set(PRIVILEGED)
    assert (await _grant(async_client, user, uuid.uuid4(), "police")).status_code == 403


@pytest.mark.asyncio
@pytest.mark.parametrize("role", ORG_ROLES)
async def test_put_profile_cannot_escalate_existing_ordinary_role(async_client, db_session, role):
    user = await _user(db_session, role="volunteer")
    assert (await _put_profile(async_client, user, "volunteer")).status_code == 200
    res = await _put_profile(async_client, user, role)
    assert res.status_code == 403
    primary, granted, emergency = await _state(db_session, user)
    assert (primary, emergency) == ("volunteer", "volunteer")
    assert not set(granted) & set(PRIVILEGED)


@pytest.mark.asyncio
@pytest.mark.parametrize("role, expected", [("admin", 403), ("administrator", 400), ("superadmin", 400)])
async def test_put_profile_rejects_admin_and_unknown_roles(async_client, db_session, role, expected):
    user = await _user(db_session)
    res = await _put_profile(async_client, user, role)
    assert res.status_code == expected
    primary, granted, _ = await _state(db_session, user)
    assert primary == "citizen" and "admin" not in granted


@pytest.mark.asyncio
async def test_legacy_user_update_cannot_escalate(async_client, db_session):
    user = await _user(db_session)
    await async_client.patch("/api/v1/users/profile", headers=_auth(user),
                             json={"display_name": "x", "role": "admin", "roles": ["police"]})
    assert await _state(db_session, user) == ("citizen", [], None)


@pytest.mark.asyncio
async def test_forged_role_claim_in_token_is_not_trusted(async_client, db_session):
    user, target = await _user(db_session), await _user(db_session)
    res = await _grant(async_client, user, target.id, "police", headers=_auth(user, role_claim="admin"))
    assert res.status_code == 403
    assert (await _state(db_session, target))[1] == []


# ------------------------------------------------------------------------------ admin grant

@pytest.mark.asyncio
@pytest.mark.parametrize("role", ORG_ROLES)
async def test_admin_can_grant_organizational_roles(async_client, db_session, role):
    admin, target = await _user(db_session, role="admin"), await _user(db_session)
    res = await _grant(async_client, admin, target.id, role)
    assert res.status_code == 200, res.text
    assert role in res.json()["data"]["roles"]
    primary, granted, _ = await _state(db_session, target)
    assert granted == [role] and primary == "citizen"

    # The grantee may now select the granted role through self-service.
    assert (await _profile_setup(async_client, target, role)).status_code == 200
    assert (await _put_profile(async_client, target, role)).status_code == 200
    assert await _state(db_session, target) == (role, [role], role)


@pytest.mark.asyncio
@pytest.mark.parametrize("admin_kwargs", [{"role": "admin"}, {"role": "citizen", "granted": ("admin",)}])
async def test_admin_via_primary_role_or_user_roles_can_grant(async_client, db_session, admin_kwargs):
    admin, target = await _user(db_session, **admin_kwargs), await _user(db_session)
    res = await _grant(async_client, admin, target.id, "fire")
    assert res.status_code == 200
    assert (await _state(db_session, target))[1] == ["fire"]


@pytest.mark.asyncio
async def test_grant_is_idempotent(async_client, db_session):
    admin, target = await _user(db_session, role="admin"), await _user(db_session)
    assert (await _grant(async_client, admin, target.id, "ngo")).status_code == 200
    assert (await _grant(async_client, admin, target.id, "ngo")).status_code == 200
    assert (await _state(db_session, target))[1] == ["ngo"]


@pytest.mark.asyncio
@pytest.mark.parametrize("actor_kwargs", [
    {"role": "citizen"}, {"role": "volunteer"},
    {"role": "police", "granted": ("police",)}, {"role": "fire", "granted": ("fire",)},
    {"role": "ambulance", "granted": ("ambulance",)}, {"role": "ngo", "granted": ("ngo",)},
])
@pytest.mark.parametrize("role", ORG_ROLES)
async def test_non_admin_cannot_grant(async_client, db_session, actor_kwargs, role):
    actor, target = await _user(db_session, **actor_kwargs), await _user(db_session)
    res = await _grant(async_client, actor, target.id, role)
    assert res.status_code == 403
    assert (await _state(db_session, target))[1] == []


@pytest.mark.asyncio
async def test_unauthenticated_cannot_grant(async_client, db_session):
    target = await _user(db_session)
    res = await async_client.post(f"/api/v1/admin/users/{target.id}/roles", json={"role": "police"})
    assert res.status_code == 401


@pytest.mark.asyncio
@pytest.mark.parametrize("actor_kwargs", [{"role": "citizen"}, {"role": "admin"}, {"role": "police", "granted": ("police",)}])
@pytest.mark.parametrize("role", ["police", "admin"])
async def test_nobody_can_grant_roles_to_themselves(async_client, db_session, actor_kwargs, role):
    actor = await _user(db_session, **actor_kwargs)
    before = await _state(db_session, actor)
    res = await _grant(async_client, actor, actor.id, role)
    assert res.status_code == 403
    assert await _state(db_session, actor) == before


@pytest.mark.asyncio
@pytest.mark.parametrize("role", BOGUS_ROLES + ["citizen", "volunteer", ""])
async def test_admin_cannot_grant_unknown_or_self_service_roles(async_client, db_session, role):
    admin, target = await _user(db_session, role="admin"), await _user(db_session)
    res = await _grant(async_client, admin, target.id, role)
    assert res.status_code == 400
    assert (await _state(db_session, target))[1] == []


@pytest.mark.asyncio
async def test_grant_payload_cannot_carry_multiple_roles(async_client, db_session):
    admin, target = await _user(db_session, role="admin"), await _user(db_session)
    res = await async_client.post(f"/api/v1/admin/users/{target.id}/roles", headers=_auth(admin),
                                  json={"role": ["police", "admin"]})
    assert res.status_code == 422
    assert (await _state(db_session, target))[1] == []


@pytest.mark.asyncio
async def test_grant_to_unknown_user_returns_404(async_client, db_session):
    admin = await _user(db_session, role="admin")
    assert (await _grant(async_client, admin, uuid.uuid4(), "police")).status_code == 404


# ------------------------------------------------------------------------ admin separation

@pytest.mark.asyncio
@pytest.mark.parametrize("role", ["police", "fire", "ambulance", "ngo", "volunteer", "citizen"])
async def test_non_admin_roles_do_not_imply_admin(async_client, db_session, role):
    granted = (role,) if role in ORG_ROLES else ()
    user = await _user(db_session, role=role, granted=granted)
    await db_session.refresh(user, ["roles"])  # the app loads roles in get_current_user
    assert is_admin(user) is False

    # Cannot use admin endpoints...
    target = await _user(db_session)
    assert (await _grant(async_client, user, target.id, "ngo")).status_code == 403
    # ...and gets no admin override on someone else's incident.
    reporter = await _user(db_session)
    incident = Incident(title="t", description="d", category="fire", severity="high", status="reported",
                        latitude=1.0, longitude=1.0, reporter_id=reporter.id)
    db_session.add(incident)
    await db_session.commit()
    res = await async_client.patch(f"/api/v1/incidents/{incident.id}/status", json={"status": "cancelled"},
                                   headers=_auth(user))
    assert res.status_code == 403


@pytest.mark.asyncio
@pytest.mark.parametrize("admin_kwargs", [{"role": "admin"}, {"role": "citizen", "granted": ("admin",)}])
async def test_real_admin_keeps_incident_override(async_client, db_session, admin_kwargs):
    admin, reporter = await _user(db_session, **admin_kwargs), await _user(db_session)
    assert is_admin(admin) is True
    incident = Incident(title="t", description="d", category="fire", severity="high", status="reported",
                        latitude=1.0, longitude=1.0, reporter_id=reporter.id)
    db_session.add(incident)
    await db_session.commit()
    res = await async_client.patch(f"/api/v1/incidents/{incident.id}/status", json={"status": "cancelled"},
                                   headers=_auth(admin))
    assert res.status_code == 200


# ------------------------------------------------------------------------------- revocation

@pytest.mark.asyncio
@pytest.mark.parametrize("role", ORG_ROLES)
async def test_admin_can_revoke_organizational_role(async_client, db_session, role):
    admin, target = await _user(db_session, role="admin"), await _user(db_session)
    assert (await _grant(async_client, admin, target.id, role)).status_code == 200
    assert (await _put_profile(async_client, target, role)).status_code == 200
    assert await _state(db_session, target) == (role, [role], role)

    res = await _revoke(async_client, admin, target.id, role)
    assert res.status_code == 200, res.text
    # Primary and profile roles that relied on the grant fall back to citizen.
    assert await _state(db_session, target) == ("citizen", [], "citizen")
    assert (await _profile_setup(async_client, target, role)).status_code == 403


@pytest.mark.asyncio
@pytest.mark.parametrize("actor_kwargs", [{"role": "citizen"}, {"role": "police", "granted": ("police",)}])
async def test_non_admin_cannot_revoke(async_client, db_session, actor_kwargs):
    actor, target = await _user(db_session, **actor_kwargs), await _user(db_session, role="fire", granted=("fire",))
    res = await _revoke(async_client, actor, target.id, "fire")
    assert res.status_code == 403
    assert await _state(db_session, target) == ("fire", ["fire"], None)


@pytest.mark.asyncio
@pytest.mark.parametrize("actor_kwargs, role", [
    ({"role": "police", "granted": ("police",)}, "police"),
    ({"role": "admin"}, "admin"),
    ({"role": "citizen", "granted": ("admin",)}, "admin"),
])
async def test_nobody_can_revoke_their_own_roles(async_client, db_session, actor_kwargs, role):
    actor = await _user(db_session, **actor_kwargs)
    before = await _state(db_session, actor)
    res = await _revoke(async_client, actor, actor.id, role)
    assert res.status_code == 403
    assert await _state(db_session, actor) == before


@pytest.mark.asyncio
async def test_revoking_another_admin_never_removes_the_last_admin(async_client, db_session):
    admin_a = await _user(db_session, role="admin")
    admin_b = await _user(db_session, role="citizen", granted=("admin",))

    res = await _revoke(async_client, admin_a, admin_b.id, "admin")
    assert res.status_code == 200
    assert (await _state(db_session, admin_b))[1] == []
    # B lost admin; A (the actor) is necessarily still an admin.
    target = await _user(db_session)
    assert (await _grant(async_client, admin_b, target.id, "ngo")).status_code == 403
    assert (await _grant(async_client, admin_a, target.id, "ngo")).status_code == 200
    # The remaining admin cannot revoke itself.
    assert (await _revoke(async_client, admin_a, admin_a.id, "admin")).status_code == 403


@pytest.mark.asyncio
async def test_revoking_primary_admin_role_resets_primary_role(async_client, db_session):
    admin_a, admin_b = await _user(db_session, role="admin"), await _user(db_session, role="admin")
    res = await _revoke(async_client, admin_a, admin_b.id, "admin")
    assert res.status_code == 200
    assert (await _state(db_session, admin_b))[:2] == ("citizen", [])


@pytest.mark.asyncio
async def test_revoke_role_not_held_returns_404_and_unknown_role_400(async_client, db_session):
    admin, target = await _user(db_session, role="admin"), await _user(db_session)
    assert (await _revoke(async_client, admin, target.id, "police")).status_code == 404
    assert (await _revoke(async_client, admin, target.id, "superadmin")).status_code == 400
    assert (await _revoke(async_client, admin, uuid.uuid4(), "police")).status_code == 404
