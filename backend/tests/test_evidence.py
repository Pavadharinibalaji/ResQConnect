import io
import uuid
import pytest
from httpx import AsyncClient
from app.core.security import create_access_token
from app.models.auth import User


@pytest.mark.asyncio
async def test_upload_photo_evidence_success(async_client: AsyncClient, db_session):
    # Step 7: uploads require incident access, so the reporter is a real user (no auth mock).
    reporter = User(firebase_uid=f"ev-{uuid.uuid4()}", phone_number="+919999999999", role="citizen", is_active=True)
    db_session.add(reporter)
    await db_session.commit()
    token = create_access_token(user_id=str(reporter.id), role="citizen")
    headers = {"Authorization": f"Bearer {token}"}

    # 1. Create incident first
    inc_payload = {
        "title": "Evidence Test Fire Incident",
        "description": "Building fire with smoke",
        "category": "fire",
        "severity": "critical",
        "latitude": 12.9716,
        "longitude": 77.5946,
        "address": "Station Grid 5"
    }
    create_res = await async_client.post("/api/v1/incidents", json=inc_payload, headers=headers)
    assert create_res.status_code == 201
    inc_id = create_res.json()["data"]["id"]

    # 2. Upload photo evidence
    fake_image_bytes = b"\xFF\xD8\xFF\xE0\x00\x10JFIF\x00\x01\x01\x01\x00\x60\x00\x60\x00\x00\xFF\xFE\x00\x13Created by ResQTest"
    files = {
        "file": ("fire_scene.jpg", io.BytesIO(fake_image_bytes), "image/jpeg")
    }

    upload_res = await async_client.post(
        f"/api/v1/incidents/{inc_id}/evidence?type=photo",
        files=files,
        headers=headers
    )
    assert upload_res.status_code == 201
    evidence_data = upload_res.json()["data"]
    assert evidence_data["type"] == "photo"
    assert evidence_data["file_url"] == f"/api/v1/incidents/{inc_id}/evidence/{evidence_data['id']}"

    # 3. Verify incident detail includes evidence
    detail_res = await async_client.get(f"/api/v1/incidents/{inc_id}", headers=headers)
    assert detail_res.status_code == 200
    evidence_list = detail_res.json()["data"]["evidence"]
    assert len(evidence_list) == 1
    assert evidence_list[0]["id"] == evidence_data["id"]

    # 4. The reporter can download it through the protected endpoint
    file_res = await async_client.get(evidence_data["file_url"], headers=headers)
    assert file_res.status_code == 200
    assert file_res.content == fake_image_bytes


# ---------------------------------------------------------------------------
# Evidence upload security regression tests (real auth, test DB, tmp storage)
# ---------------------------------------------------------------------------
import os
import re

from sqlalchemy import text

from app.models.incidents import Incident

MB = 1024 * 1024
JPEG_BYTES = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00" + b"\x00" * 64
PNG_BYTES = b"\x89PNG\r\n\x1a\n" + b"\x00" * 64
MP4_BYTES = b"\x00\x00\x00\x18ftypmp42\x00\x00\x00\x00mp42isom" + b"\x00" * 64
HTML_BYTES = b"<html><body><script>alert(document.cookie)</script></body></html>"
# Step 7: evidence is referenced through the protected API endpoint; the stored file is
# named after the evidence id with a server-chosen extension.
SAFE_URL = re.compile(r"^/api/v1/incidents/[0-9a-f-]{36}/evidence/[0-9a-f-]{36}$")
STORED_NAME = re.compile(r"^[0-9a-f-]{36}\.(jpg|png|webp|mp4|mov|webm|avi)$")


def _expected_stored_name(data, ext):
    return f"{data['id']}.{ext}"


async def _seed_incident(db_session):
    user = User(firebase_uid=f"ev-{uuid.uuid4()}", phone_number=f"+1444{uuid.uuid4().int % 10**7:07d}",
                role="citizen", is_active=True)
    db_session.add(user)
    await db_session.flush()
    incident = Incident(title="Evidence security", description="d", category="fire", severity="high",
                        status="reported", latitude=1.0, longitude=1.0, reporter_id=user.id)
    db_session.add(incident)
    await db_session.commit()
    headers = {"Authorization": f"Bearer {create_access_token(str(user.id), user.role)}"}
    return incident.id, headers


async def _upload(async_client, incident_id, headers, filename, content, content_type, evidence_type="photo"):
    return await async_client.post(
        f"/api/v1/incidents/{incident_id}/evidence",
        params={"type": evidence_type},
        files={"file": (filename, io.BytesIO(content), content_type)},
        headers=headers,
    )


def _stored_files(tmp_path):
    upload_dir = tmp_path / "static" / "uploads" / "evidence"
    return sorted(p.name for p in upload_dir.iterdir()) if upload_dir.exists() else []


async def _evidence_rows(db_session, incident_id):
    return (await db_session.execute(
        text("SELECT count(*) FROM incident_evidence WHERE incident_id = :i"), {"i": incident_id}
    )).scalar()


async def _assert_rejected(res, status_code, db_session, incident_id, tmp_path):
    assert res.status_code == status_code, res.text
    detail = str(res.json().get("detail", "")).lower()
    for leak in ("traceback", "static", "uploads", "\\", "tmp"):
        assert leak not in detail
    assert _stored_files(tmp_path) == []
    assert await _evidence_rows(db_session, incident_id) == 0


@pytest.mark.asyncio
@pytest.mark.parametrize("filename, content, content_type, evidence_type, ext", [
    ("scene.jpg", JPEG_BYTES, "image/jpeg", "photo", "jpg"),
    ("scene.png", PNG_BYTES, "image/png", "photo", "png"),
    ("scene.jpg", JPEG_BYTES, "application/octet-stream", "photo", "jpg"),  # mobile client default
    ("clip.mp4", MP4_BYTES, "video/mp4", "video", "mp4"),
])
async def test_valid_evidence_accepted(async_client, db_session, tmp_path, filename, content, content_type, evidence_type, ext):
    incident_id, headers = await _seed_incident(db_session)
    res = await _upload(async_client, incident_id, headers, filename, content, content_type, evidence_type)

    assert res.status_code == 201, res.text
    data = res.json()["data"]
    assert data["type"] == evidence_type
    assert SAFE_URL.match(data["file_url"]) and data["file_url"].endswith(data["id"])
    stored = _stored_files(tmp_path)
    assert stored == [_expected_stored_name(data, ext)]
    assert (tmp_path / "static" / "uploads" / "evidence" / stored[0]).read_bytes() == content


@pytest.mark.asyncio
@pytest.mark.parametrize("evidence_type", ["document", "html", "", "PHOTO/../x"])
async def test_unsupported_evidence_type_rejected(async_client, db_session, tmp_path, evidence_type):
    incident_id, headers = await _seed_incident(db_session)
    res = await _upload(async_client, incident_id, headers, "scene.jpg", JPEG_BYTES, "image/jpeg", evidence_type)
    await _assert_rejected(res, 400, db_session, incident_id, tmp_path)


@pytest.mark.asyncio
async def test_photo_at_size_limit_accepted(async_client, db_session, tmp_path):
    incident_id, headers = await _seed_incident(db_session)
    content = JPEG_BYTES + b"\x00" * (10 * MB - len(JPEG_BYTES))
    res = await _upload(async_client, incident_id, headers, "big.jpg", content, "image/jpeg")
    assert res.status_code == 201, res.text


@pytest.mark.asyncio
async def test_oversized_photo_rejected(async_client, db_session, tmp_path):
    incident_id, headers = await _seed_incident(db_session)
    content = JPEG_BYTES + b"\x00" * (10 * MB + 1 - len(JPEG_BYTES))
    res = await _upload(async_client, incident_id, headers, "huge.jpg", content, "image/jpeg")
    await _assert_rejected(res, 413, db_session, incident_id, tmp_path)


@pytest.mark.asyncio
async def test_oversized_video_rejected(async_client, db_session, tmp_path):
    incident_id, headers = await _seed_incident(db_session)
    content = MP4_BYTES + b"\x00" * (50 * MB + 1 - len(MP4_BYTES))
    res = await _upload(async_client, incident_id, headers, "huge.mp4", content, "video/mp4", "video")
    await _assert_rejected(res, 413, db_session, incident_id, tmp_path)


@pytest.mark.asyncio
@pytest.mark.parametrize("filename, content, content_type", [
    ("evil.html", JPEG_BYTES, "image/jpeg"),            # dangerous extension, image bytes
    ("evil.svg", b"<svg onload=alert(1)>", "image/svg+xml"),
    ("evil.php", JPEG_BYTES, "image/jpeg"),
    ("evil.jpg.exe", JPEG_BYTES, "image/jpeg"),
    ("evil", HTML_BYTES, "text/html"),                  # no extension, HTML content
])
async def test_dangerous_extension_or_type_rejected(async_client, db_session, tmp_path, filename, content, content_type):
    incident_id, headers = await _seed_incident(db_session)
    res = await _upload(async_client, incident_id, headers, filename, content, content_type)
    await _assert_rejected(res, 400, db_session, incident_id, tmp_path)


@pytest.mark.asyncio
@pytest.mark.parametrize("filename, content, content_type, evidence_type", [
    ("scene.jpg", HTML_BYTES, "image/jpeg", "photo"),    # claims JPEG, is HTML
    ("scene.jpg", JPEG_BYTES, "text/html", "photo"),     # JPEG bytes declared as HTML
    ("scene.jpg", JPEG_BYTES, "video/mp4", "photo"),     # declared type contradicts evidence type
    ("clip.mp4", JPEG_BYTES, "video/mp4", "video"),      # claims video, is an image
    ("scene.png", JPEG_BYTES, "image/png", "photo"),     # extension/content mismatch
])
async def test_content_and_declared_mime_must_match(async_client, db_session, tmp_path, filename, content, content_type, evidence_type):
    incident_id, headers = await _seed_incident(db_session)
    res = await _upload(async_client, incident_id, headers, filename, content, content_type, evidence_type)
    await _assert_rejected(res, 400, db_session, incident_id, tmp_path)


@pytest.mark.asyncio
@pytest.mark.parametrize("filename", [
    "../../../../evil.jpg",
    "..\\..\\..\\evil.jpg",
    "/etc/passwd.jpg",
    "C:\\Windows\\evil.jpg",
])
async def test_client_filename_cannot_choose_storage_path(async_client, db_session, tmp_path, filename):
    incident_id, headers = await _seed_incident(db_session)
    res = await _upload(async_client, incident_id, headers, filename, JPEG_BYTES, "image/jpeg")

    assert res.status_code == 201, res.text
    data = res.json()["data"]
    assert SAFE_URL.match(data["file_url"])
    stored = _stored_files(tmp_path)
    assert stored == [_expected_stored_name(data, "jpg")] and STORED_NAME.match(stored[0])
    # Nothing was written anywhere else under the test's working directory.
    written = [os.path.relpath(os.path.join(root, f), tmp_path) for root, _, files in os.walk(tmp_path) for f in files]
    assert written == [os.path.join("static", "uploads", "evidence", stored[0])]
    # "static/uploads/evidence/../../../../evil.jpg" would resolve to tmp_path.parent.
    assert not (tmp_path.parent / "evil.jpg").exists()
    assert "evil" not in stored[0]


@pytest.mark.asyncio
async def test_upload_requires_authentication(async_client, db_session, tmp_path):
    incident_id, _ = await _seed_incident(db_session)
    res = await _upload(async_client, incident_id, {}, "scene.jpg", JPEG_BYTES, "image/jpeg")
    assert res.status_code == 401
    assert _stored_files(tmp_path) == []
