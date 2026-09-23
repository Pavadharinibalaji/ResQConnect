"""
Regression tests for incident response serialization.

IncidentResponse used to be validated straight from the ORM object, which made
Pydantic touch the lazy `Incident.responders` relationship and raise
MissingGreenlet on every endpoint that returns an incident once one exists.
"""
import uuid

import pytest

from app.core.security import create_access_token
from app.models.auth import User

INCIDENT_PAYLOAD = {
    "title": "Serialization Regression Incident",
    "description": "Smoke visible from the third floor",
    "category": "fire",
    "severity": "high",
    "latitude": 12.9716,
    "longitude": 77.5946,
    "address": "MG Road",
}


async def _create_user(db_session, phone: str) -> User:
    user = User(firebase_uid=f"test-{uuid.uuid4()}", phone_number=phone, role="citizen", is_active=True)
    db_session.add(user)
    await db_session.commit()
    return user


def _auth(user: User) -> dict:
    return {"Authorization": f"Bearer {create_access_token(str(user.id), user.role)}"}


@pytest.mark.asyncio
async def test_persisted_incident_serializes_on_all_read_endpoints(async_client, db_session):
    reporter = await _create_user(db_session, "+19990000001")

    create_res = await async_client.post("/api/v1/incidents", json=INCIDENT_PAYLOAD, headers=_auth(reporter))
    assert create_res.status_code == 201
    created = create_res.json()["data"]
    incident_id = created["id"]
    assert created["reporter_id"] == str(reporter.id)
    assert created["status"] == "reported"
    assert created["responder_count"] == 0
    assert created["user_responder_status"] is None
    assert created["evidence"] == []

    feed_res = await async_client.get("/api/v1/incidents")
    assert feed_res.status_code == 200
    feed_ids = [item["id"] for item in feed_res.json()["data"]["incidents"]]
    assert incident_id in feed_ids

    nearby_res = await async_client.get(
        "/api/v1/incidents/nearby",
        params={"latitude": 12.9716, "longitude": 77.5946, "radius_km": 5.0},
    )
    assert nearby_res.status_code == 200
    nearby = {item["id"]: item for item in nearby_res.json()["data"]["incidents"]}
    assert incident_id in nearby
    assert nearby[incident_id]["distance_km"] == 0.0

    detail_res = await async_client.get(f"/api/v1/incidents/{incident_id}")
    assert detail_res.status_code == 200
    detail = detail_res.json()["data"]
    assert detail["id"] == incident_id
    assert detail["responders"] == []
    assert detail["responder_count"] == 0


@pytest.mark.asyncio
async def test_responder_fields_after_joining_incident(async_client, db_session):
    reporter = await _create_user(db_session, "+19990000002")
    responder = await _create_user(db_session, "+19990000003")

    create_res = await async_client.post("/api/v1/incidents", json=INCIDENT_PAYLOAD, headers=_auth(reporter))
    assert create_res.status_code == 201
    incident_id = create_res.json()["data"]["id"]

    respond_res = await async_client.post(f"/api/v1/incidents/{incident_id}/respond", headers=_auth(responder))
    assert respond_res.status_code == 200
    responded = respond_res.json()["data"]
    assert responded["status"] == "active"
    assert responded["responder_count"] == 1
    assert responded["user_responder_status"] == "responding"
    assert [r["user_id"] for r in responded["responders"]] == [str(responder.id)]

    # Detail as the responder: their own status is reported.
    detail_res = await async_client.get(f"/api/v1/incidents/{incident_id}", headers=_auth(responder))
    assert detail_res.status_code == 200
    detail = detail_res.json()["data"]
    assert detail["responder_count"] == 1
    assert detail["user_responder_status"] == "responding"
    assert len(detail["responders"]) == 1

    # Feed as an anonymous viewer: count is shared, personal status is not.
    feed_res = await async_client.get("/api/v1/incidents")
    assert feed_res.status_code == 200
    feed_item = next(i for i in feed_res.json()["data"]["incidents"] if i["id"] == incident_id)
    assert feed_item["responder_count"] == 1
    assert feed_item["user_responder_status"] is None
