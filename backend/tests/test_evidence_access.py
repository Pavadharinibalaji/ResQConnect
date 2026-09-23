"""
Evidence access control.

Upload and view are allowed only for the incident's reporter, an admin (same
detection as incident status updates) or a user with a non-withdrawn
IncidentResponder row for that incident. Self-selected profile roles grant nothing.
Evidence is served only through the authenticated API endpoint, never /static.
"""
import io
import uuid
from pathlib import Path

import pytest
from sqlalchemy import select, text

from app.core.security import create_access_token
from app.models.auth import Role, User
from app.models.evidence import IncidentEvidence
from app.models.incidents import Incident
from app.models.responders import IncidentResponder

JPEG_BYTES = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00" + b"\x00" * 64
PNG_BYTES = b"\x89PNG\r\n\x1a\n" + b"\x00" * 64
MP4_BYTES = b"\x00\x00\x00\x18ftypmp42\x00\x00\x00\x00mp42isom" + b"\x00" * 64
SELF_SELECTABLE_ROLES = ["citizen", "volunteer", "ngo", "police", "fire", "ambulance"]


# ----------------------------------------------------------------------------- helpers

async def _user(db_session, role="citizen", extra_roles=()):
    user = User(firebase_uid=f"ea-{uuid.uuid4()}", phone_number=f"+1222{uuid.uuid4().int % 10**7:07d}",
                role=role, is_active=True)
    if extra_roles:
        user.roles.extend((await db_session.execute(select(Role).where(Role.name.in_(extra_roles)))).scalars().all())
    db_session.add(user)
    await db_session.commit()
    return user


async def _incident(db_session, reporter):
    incident = Incident(title="Evidence access", description="d", category="fire", severity="high",
                        status="active", latitude=1.0, longitude=1.0, reporter_id=reporter.id)
    db_session.add(incident)
    await db_session.commit()
    return incident.id


async def _join(db_session, user, incident_id, status="responding"):
    db_session.add(IncidentResponder(incident_id=incident_id, user_id=user.id, status=status))
    await db_session.commit()


def _auth(user):
    return {"Authorization": f"Bearer {create_access_token(str(user.id), user.role)}"}


def _upload_dir(tmp_path) -> Path:
    return tmp_path / "static" / "uploads" / "evidence"


async def _seed_evidence(db_session, tmp_path, incident_id, content=JPEG_BYTES, ext=".jpg", evidence_type="photo",
                         write_file=True):
    """Evidence row + file exactly as the upload endpoint stores them (relative path under the CWD)."""
    evidence_id = uuid.uuid4()
    filename = f"{evidence_id}{ext}"
    if write_file:
        _upload_dir(tmp_path).mkdir(parents=True, exist_ok=True)
        (_upload_dir(tmp_path) / filename).write_bytes(content)
    db_session.add(IncidentEvidence(
        id=evidence_id, incident_id=incident_id, type=evidence_type,
        file_path=str(Path("static") / "uploads" / "evidence" / filename),
        file_url=f"/api/v1/incidents/{incident_id}/evidence/{evidence_id}",
    ))
    await db_session.commit()
    return evidence_id, filename


async def _upload(async_client, incident_id, headers, filename="scene.jpg", content=JPEG_BYTES, content_type="image/jpeg"):
    return await async_client.post(
        f"/api/v1/incidents/{incident_id}/evidence", params={"type": "photo"},
        files={"file": (filename, io.BytesIO(content), content_type)}, headers=headers,
    )


def _evidence_url(incident_id, evidence_id):
    return f"/api/v1/incidents/{incident_id}/evidence/{evidence_id}"


async def _evidence_count(db_session, incident_id):
    return (await db_session.execute(
        text("SELECT count(*) FROM incident_evidence WHERE incident_id = :i"), {"i": incident_id})).scalar()


def _files(tmp_path):
    return sorted(p.name for p in _upload_dir(tmp_path).iterdir()) if _upload_dir(tmp_path).exists() else []


def _assert_no_path_leak(res, tmp_path):
    blob = (res.text + " " + " ".join(f"{k}: {v}" for k, v in res.headers.items())).lower()
    for leak in (str(tmp_path).lower(), "static/uploads", "static\\uploads", "file_path"):
        assert leak not in blob


# ------------------------------------------------------------------------------ upload

@pytest.mark.asyncio
async def test_upload_unauthenticated_rejected(async_client, db_session, tmp_path):
    reporter = await _user(db_session)
    incident_id = await _incident(db_session, reporter)
    res = await _upload(async_client, incident_id, {})
    assert res.status_code == 401
    assert _files(tmp_path) == [] and await _evidence_count(db_session, incident_id) == 0


@pytest.mark.asyncio
async def test_upload_allowed_for_reporter(async_client, db_session, tmp_path):
    reporter = await _user(db_session)
    incident_id = await _incident(db_session, reporter)
    res = await _upload(async_client, incident_id, _auth(reporter))
    assert res.status_code == 201, res.text
    data = res.json()["data"]
    assert data["file_url"] == _evidence_url(incident_id, data["id"])
    assert _files(tmp_path) == [f"{data['id']}.jpg"]


@pytest.mark.asyncio
@pytest.mark.parametrize("status", ["responding", "arrived", "assisting", "completed"])
async def test_upload_allowed_for_participating_responder(async_client, db_session, tmp_path, status):
    reporter, responder = await _user(db_session), await _user(db_session, role="volunteer")
    incident_id = await _incident(db_session, reporter)
    await _join(db_session, responder, incident_id, status)
    res = await _upload(async_client, incident_id, _auth(responder))
    assert res.status_code == 201, res.text


@pytest.mark.asyncio
@pytest.mark.parametrize("admin_kwargs", [{"role": "admin"}, {"role": "citizen", "extra_roles": ("admin",)}])
async def test_upload_allowed_for_admin(async_client, db_session, tmp_path, admin_kwargs):
    reporter, admin = await _user(db_session), await _user(db_session, **admin_kwargs)
    incident_id = await _incident(db_session, reporter)
    res = await _upload(async_client, incident_id, _auth(admin))
    assert res.status_code == 201, res.text


@pytest.mark.asyncio
@pytest.mark.parametrize("role", SELF_SELECTABLE_ROLES)
async def test_upload_denied_for_unrelated_user_with_any_profile_role(async_client, db_session, tmp_path, role):
    reporter, other = await _user(db_session), await _user(db_session, role=role)
    incident_id = await _incident(db_session, reporter)
    res = await _upload(async_client, incident_id, _auth(other))
    assert res.status_code == 403
    _assert_no_path_leak(res, tmp_path)
    assert _files(tmp_path) == [] and await _evidence_count(db_session, incident_id) == 0


@pytest.mark.asyncio
async def test_upload_denied_for_withdrawn_responder(async_client, db_session, tmp_path):
    reporter, responder = await _user(db_session), await _user(db_session)
    incident_id = await _incident(db_session, reporter)
    await _join(db_session, responder, incident_id, "withdrawn")
    res = await _upload(async_client, incident_id, _auth(responder))
    assert res.status_code == 403
    assert _files(tmp_path) == [] and await _evidence_count(db_session, incident_id) == 0


@pytest.mark.asyncio
async def test_upload_denied_for_responder_of_another_incident(async_client, db_session, tmp_path):
    reporter, responder = await _user(db_session), await _user(db_session)
    incident_a, incident_b = await _incident(db_session, reporter), await _incident(db_session, reporter)
    await _join(db_session, responder, incident_a)
    res = await _upload(async_client, incident_b, _auth(responder))
    assert res.status_code == 403
    assert _files(tmp_path) == [] and await _evidence_count(db_session, incident_b) == 0


@pytest.mark.asyncio
async def test_authorization_runs_before_file_validation(async_client, db_session, tmp_path):
    reporter, other = await _user(db_session), await _user(db_session)
    incident_id = await _incident(db_session, reporter)
    res = await _upload(async_client, incident_id, _auth(other), filename="evil.html",
                        content=b"<script>alert(1)</script>", content_type="text/html")
    assert res.status_code == 403
    assert _files(tmp_path) == []


@pytest.mark.asyncio
async def test_upload_to_missing_incident_returns_404(async_client, db_session, tmp_path):
    user = await _user(db_session)
    res = await _upload(async_client, uuid.uuid4(), _auth(user))
    assert res.status_code == 404
    assert _files(tmp_path) == []


# -------------------------------------------------------------------------------- read

@pytest.mark.asyncio
async def test_read_unauthenticated_rejected(async_client, db_session, tmp_path):
    reporter = await _user(db_session)
    incident_id = await _incident(db_session, reporter)
    evidence_id, _ = await _seed_evidence(db_session, tmp_path, incident_id)
    res = await async_client.get(_evidence_url(incident_id, evidence_id))
    assert res.status_code == 401
    assert JPEG_BYTES not in res.content


@pytest.mark.asyncio
async def test_read_allowed_for_reporter_with_safe_headers(async_client, db_session, tmp_path):
    reporter = await _user(db_session)
    incident_id = await _incident(db_session, reporter)
    evidence_id, _ = await _seed_evidence(db_session, tmp_path, incident_id)

    res = await async_client.get(_evidence_url(incident_id, evidence_id), headers=_auth(reporter))
    assert res.status_code == 200
    assert res.content == JPEG_BYTES
    assert res.headers["content-type"] == "image/jpeg"
    assert res.headers["x-content-type-options"] == "nosniff"
    assert "private" in res.headers["cache-control"] and "no-store" in res.headers["cache-control"]
    assert "sandbox" in res.headers["content-security-policy"]
    _assert_no_path_leak(res, tmp_path)


@pytest.mark.asyncio
@pytest.mark.parametrize("status", ["responding", "completed"])
async def test_read_allowed_for_participating_responder(async_client, db_session, tmp_path, status):
    reporter, responder = await _user(db_session), await _user(db_session)
    incident_id = await _incident(db_session, reporter)
    await _join(db_session, responder, incident_id, status)
    evidence_id, _ = await _seed_evidence(db_session, tmp_path, incident_id)
    res = await async_client.get(_evidence_url(incident_id, evidence_id), headers=_auth(responder))
    assert res.status_code == 200 and res.content == JPEG_BYTES


@pytest.mark.asyncio
@pytest.mark.parametrize("admin_kwargs", [{"role": "admin"}, {"role": "citizen", "extra_roles": ("admin",)}])
async def test_read_allowed_for_admin(async_client, db_session, tmp_path, admin_kwargs):
    reporter, admin = await _user(db_session), await _user(db_session, **admin_kwargs)
    incident_id = await _incident(db_session, reporter)
    evidence_id, _ = await _seed_evidence(db_session, tmp_path, incident_id)
    res = await async_client.get(_evidence_url(incident_id, evidence_id), headers=_auth(admin))
    assert res.status_code == 200 and res.content == JPEG_BYTES


@pytest.mark.asyncio
@pytest.mark.parametrize("role", SELF_SELECTABLE_ROLES)
async def test_read_denied_for_unrelated_user_with_any_profile_role(async_client, db_session, tmp_path, role):
    reporter, other = await _user(db_session), await _user(db_session, role=role)
    incident_id = await _incident(db_session, reporter)
    evidence_id, filename = await _seed_evidence(db_session, tmp_path, incident_id)
    res = await async_client.get(_evidence_url(incident_id, evidence_id), headers=_auth(other))
    assert res.status_code == 403
    assert JPEG_BYTES not in res.content and filename not in res.text
    _assert_no_path_leak(res, tmp_path)


@pytest.mark.asyncio
async def test_read_denied_for_withdrawn_responder(async_client, db_session, tmp_path):
    reporter, responder = await _user(db_session), await _user(db_session)
    incident_id = await _incident(db_session, reporter)
    await _join(db_session, responder, incident_id, "withdrawn")
    evidence_id, _ = await _seed_evidence(db_session, tmp_path, incident_id)
    res = await async_client.get(_evidence_url(incident_id, evidence_id), headers=_auth(responder))
    assert res.status_code == 403


@pytest.mark.asyncio
async def test_unrelated_user_gets_same_403_for_existing_and_unknown_evidence(async_client, db_session, tmp_path):
    reporter, other = await _user(db_session), await _user(db_session)
    incident_id = await _incident(db_session, reporter)
    evidence_id, _ = await _seed_evidence(db_session, tmp_path, incident_id)
    existing = await async_client.get(_evidence_url(incident_id, evidence_id), headers=_auth(other))
    unknown = await async_client.get(_evidence_url(incident_id, uuid.uuid4()), headers=_auth(other))
    assert existing.status_code == unknown.status_code == 403
    assert existing.json() == unknown.json()


@pytest.mark.asyncio
async def test_evidence_cannot_be_fetched_through_another_incident(async_client, db_session, tmp_path):
    reporter = await _user(db_session)  # authorised on both incidents
    incident_a, incident_b = await _incident(db_session, reporter), await _incident(db_session, reporter)
    evidence_id, _ = await _seed_evidence(db_session, tmp_path, incident_a)

    res = await async_client.get(_evidence_url(incident_b, evidence_id), headers=_auth(reporter))
    assert res.status_code == 404
    assert JPEG_BYTES not in res.content

    outsider = await _user(db_session)
    await _join(db_session, outsider, incident_b)
    res = await async_client.get(_evidence_url(incident_b, evidence_id), headers=_auth(outsider))
    assert res.status_code == 404
    assert JPEG_BYTES not in res.content


@pytest.mark.asyncio
async def test_missing_evidence_file_handled_safely(async_client, db_session, tmp_path):
    reporter = await _user(db_session)
    incident_id = await _incident(db_session, reporter)
    evidence_id, filename = await _seed_evidence(db_session, tmp_path, incident_id, write_file=False)
    res = await async_client.get(_evidence_url(incident_id, evidence_id), headers=_auth(reporter))
    assert res.status_code == 404
    assert filename not in res.text
    _assert_no_path_leak(res, tmp_path)


@pytest.mark.asyncio
async def test_unknown_evidence_and_missing_incident_return_404(async_client, db_session, tmp_path):
    reporter = await _user(db_session)
    incident_id = await _incident(db_session, reporter)
    res = await async_client.get(_evidence_url(incident_id, uuid.uuid4()), headers=_auth(reporter))
    assert res.status_code == 404
    res = await async_client.get(_evidence_url(uuid.uuid4(), uuid.uuid4()), headers=_auth(reporter))
    assert res.status_code == 404


@pytest.mark.asyncio
async def test_tampered_file_path_cannot_escape_upload_directory(async_client, db_session, tmp_path):
    reporter = await _user(db_session)
    incident_id = await _incident(db_session, reporter)
    (tmp_path / "outside-secret.txt").write_bytes(b"TOP-SECRET")
    evidence_id = uuid.uuid4()
    db_session.add(IncidentEvidence(id=evidence_id, incident_id=incident_id, type="photo",
                                    file_path="static/uploads/evidence/../../../outside-secret.txt",
                                    file_url=_evidence_url(incident_id, evidence_id)))
    await db_session.commit()
    res = await async_client.get(_evidence_url(incident_id, evidence_id), headers=_auth(reporter))
    assert res.status_code == 404
    assert b"TOP-SECRET" not in res.content


@pytest.mark.asyncio
@pytest.mark.parametrize("content, ext, evidence_type, media_type", [
    (JPEG_BYTES, ".jpg", "photo", "image/jpeg"),
    (PNG_BYTES, ".png", "photo", "image/png"),
    (MP4_BYTES, ".mp4", "video", "video/mp4"),
])
async def test_served_media_type_is_server_determined(async_client, db_session, tmp_path, content, ext, evidence_type, media_type):
    reporter = await _user(db_session)
    incident_id = await _incident(db_session, reporter)
    evidence_id, _ = await _seed_evidence(db_session, tmp_path, incident_id, content=content, ext=ext,
                                          evidence_type=evidence_type)
    res = await async_client.get(_evidence_url(incident_id, evidence_id), headers=_auth(reporter))
    assert res.status_code == 200
    assert res.headers["content-type"] == media_type
    assert res.headers["x-content-type-options"] == "nosniff"


# ---------------------------------------------------------------------- public path gone

@pytest.mark.asyncio
async def test_public_static_evidence_url_no_longer_serves_files(async_client, db_session, tmp_path):
    reporter = await _user(db_session)
    incident_id = await _incident(db_session, reporter)
    _, filename = await _seed_evidence(db_session, tmp_path, incident_id)

    for headers in ({}, _auth(reporter)):
        res = await async_client.get(f"/static/uploads/evidence/{filename}", headers=headers)
        assert res.status_code == 404
        assert JPEG_BYTES not in res.content


@pytest.mark.asyncio
async def test_incident_responses_point_to_protected_endpoint(async_client, db_session, tmp_path):
    reporter = await _user(db_session)
    incident_id = await _incident(db_session, reporter)
    upload = await _upload(async_client, incident_id, _auth(reporter))
    assert upload.status_code == 201
    evidence_id = upload.json()["data"]["id"]

    detail = await async_client.get(f"/api/v1/incidents/{incident_id}")
    evidence = detail.json()["data"]["evidence"]
    assert [e["file_url"] for e in evidence] == [_evidence_url(incident_id, evidence_id)]
    assert "/static/" not in detail.text
    _assert_no_path_leak(detail, tmp_path)
