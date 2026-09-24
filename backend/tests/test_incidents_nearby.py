import uuid
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import event, text

from app.core.security import create_access_token
from app.models.auth import User
from app.models.evidence import IncidentEvidence
from app.models.incidents import Incident
from app.models.responders import IncidentResponder
from app.utils.geo import haversine_distance

def test_haversine_distance_calculation():
    # Bengaluru Center (12.9716, 77.5946) to Indiranagar (12.9784, 77.6408)
    dist = haversine_distance(12.9716, 77.5946, 12.9784, 77.6408)
    assert 4.0 <= dist <= 6.0

def test_haversine_distance_same_point():
    dist = haversine_distance(12.9716, 77.5946, 12.9716, 77.5946)
    assert dist == 0.0

@pytest.mark.asyncio
async def test_get_nearby_incidents_empty(async_client):
    response = await async_client.get(
        "/api/v1/incidents/nearby",
        params={"latitude": 12.9716, "longitude": 77.5946, "radius_km": 10.0}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert "incidents" in data["data"]


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PostGIS nearby query
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Points lie on the equator, where the WGS84 geodesic distance is exactly the
# equatorial arc: 1 degree of longitude = 2*pi*6378.137/360 km. The origin is at
# longitude 30 so that a swapped latitude/longitude would land thousands of km away.

KM_PER_DEGREE_AT_EQUATOR = 111.31949079327357
ORIGIN_LAT, ORIGIN_LON = 0.0, 30.0
NEARBY_URL = "/api/v1/incidents/nearby"


def _east_of_origin(km: float) -> tuple[float, float]:
    return ORIGIN_LAT, ORIGIN_LON + km / KM_PER_DEGREE_AT_EQUATOR


def _incident(km: float, *, located: bool = True, **overrides) -> Incident:
    lat, lon = _east_of_origin(km)
    fields = dict(
        title=f"Nearby {km} km", description="d", category="fire", severity="high", status="reported",
        latitude=lat, longitude=lon,
        location=f"SRID=4326;POINT({lon} {lat})" if located else None,
    )
    fields.update(overrides)
    return Incident(**fields)


async def _add_all(db_session, *objects) -> list:
    db_session.add_all(objects)
    await db_session.commit()
    return list(objects)


async def _create_user(db_session) -> User:
    user = User(firebase_uid=f"nearby-{uuid.uuid4()}", phone_number=f"+1555{uuid.uuid4().int % 10**7:07d}",
                role="citizen", is_active=True)
    db_session.add(user)
    await db_session.commit()
    return user


def _auth(user: User) -> dict:
    return {"Authorization": f"Bearer {create_access_token(str(user.id), user.role)}"}


async def _nearby(async_client, headers=None, **params) -> dict:
    query = {"latitude": ORIGIN_LAT, "longitude": ORIGIN_LON, "radius_km": 10.0, **params}
    response = await async_client.get(NEARBY_URL, params=query, headers=headers or {})
    assert response.status_code == 200, response.text
    return response.json()["data"]


def _ids(data: dict) -> list[str]:
    return [item["id"] for item in data["incidents"]]


@contextmanager
def _record_selects(db_connection):
    """Records SELECT statements executed on the test connection (all request sessions use it)."""
    statements = []

    def _record(conn, cursor, statement, parameters, context, executemany):
        if statement.lstrip().upper().startswith("SELECT"):
            statements.append(statement)

    sync_connection = db_connection.sync_connection
    event.listen(sync_connection, "before_cursor_execute", _record)
    try:
        yield statements
    finally:
        event.remove(sync_connection, "before_cursor_execute", _record)


@pytest.mark.asyncio
async def test_geography_expression_index_exists(db_session):
    indexdef = (await db_session.execute(text(
        "SELECT indexdef FROM pg_indexes WHERE tablename = 'incidents' "
        "AND indexname = 'idx_incidents_location_geography'"
    ))).scalar_one_or_none()
    assert indexdef is not None
    assert "USING gist" in indexdef
    assert "::geography" in indexdef


@pytest.mark.asyncio
@pytest.mark.parametrize("radius_km", [1, 3, 5, 10, 25])
async def test_radius_includes_inside_and_excludes_outside(async_client, db_session, radius_km):
    inside, outside = await _add_all(
        db_session, _incident(radius_km * 0.9), _incident(radius_km * 1.1)
    )

    data = await _nearby(async_client, radius_km=radius_km)

    assert _ids(data) == [str(inside.id)]
    assert data["total"] == 1
    assert data["radius_km"] == radius_km


@pytest.mark.asyncio
@pytest.mark.parametrize("radius_km", [1, 3, 5, 10, 25])
async def test_radius_boundary_uses_exact_geography_distance(async_client, db_session, radius_km):
    # Inclusive radius compared against the exact WGS84 distance: no rounding tolerance
    # (the old rounded haversine would also have returned the +4 m and +10 m incidents).
    just_inside, plus_4m, plus_10m = await _add_all(
        db_session,
        _incident(radius_km - 0.001),
        _incident(radius_km + 0.004),
        _incident(radius_km + 0.010),
    )

    data = await _nearby(async_client, radius_km=radius_km)

    assert _ids(data) == [str(just_inside.id)]
    assert data["total"] == 1


@pytest.mark.asyncio
async def test_distance_km_is_postgis_geography_distance(async_client, db_session):
    await _add_all(db_session, _incident(5.565975))  # 0.05 degrees of longitude

    item = (await _nearby(async_client))["incidents"][0]

    assert item["distance_km"] == 5.57


@pytest.mark.asyncio
async def test_known_city_pair_distance(async_client, db_session):
    # Bengaluru centre -> Indiranagar, WGS84 geodesic ~5.02 km.
    await _add_all(db_session, Incident(
        title="Indiranagar", description="d", category="fire", severity="high", status="reported",
        latitude=12.9784, longitude=77.6408, location="SRID=4326;POINT(77.6408 12.9784)",
    ))

    data = await _nearby(async_client, latitude=12.9716, longitude=77.5946, radius_km=10)

    assert len(data["incidents"]) == 1
    assert 4.9 <= data["incidents"][0]["distance_km"] <= 5.2


@pytest.mark.asyncio
async def test_results_ordered_nearest_first(async_client, db_session):
    far, near, middle = await _add_all(db_session, _incident(3.0), _incident(1.0), _incident(2.0))

    data = await _nearby(async_client)

    assert _ids(data) == [str(near.id), str(middle.id), str(far.id)]
    assert [item["distance_km"] for item in data["incidents"]] == [1.0, 2.0, 3.0]


@pytest.mark.asyncio
async def test_equal_distances_are_ordered_by_id(async_client, db_session):
    same_point = [_incident(2.0, id=uuid.uuid4()) for _ in range(4)]
    await _add_all(db_session, *same_point)
    expected = sorted(str(incident.id) for incident in same_point)

    first = await _nearby(async_client)
    second = await _nearby(async_client)

    assert _ids(first) == expected
    assert _ids(second) == expected


@pytest.mark.asyncio
async def test_pagination_limit_offset_and_total(async_client, db_session):
    incidents = await _add_all(db_session, *[_incident(0.5 + i) for i in range(7)])
    await _add_all(db_session, _incident(50.0))  # outside the radius
    ordered = [str(incident.id) for incident in incidents]

    pages = [await _nearby(async_client, limit=3, offset=offset) for offset in (0, 3, 6, 10)]

    assert [_ids(page) for page in pages] == [ordered[0:3], ordered[3:6], ordered[6:7], []]
    assert [page["total"] for page in pages] == [7, 7, 7, 7]


@pytest.mark.asyncio
@pytest.mark.parametrize("param, value, matching", [
    ("category", "MEDICAL", {"category": "medical"}),
    ("status", "in_progress", {"status": "in_progress"}),
    ("severity", "low", {"severity": "low"}),
])
async def test_filters_are_applied_before_pagination(async_client, db_session, param, value, matching):
    await _add_all(db_session, *[_incident(0.5 + i) for i in range(3)])  # non-matching, nearer
    wanted = await _add_all(db_session, *[_incident(5.0 + i, **matching) for i in range(3)])
    await _add_all(db_session, _incident(40.0, **matching))  # matching, outside the radius

    data = await _nearby(async_client, limit=2, **{param: value})

    assert _ids(data) == [str(wanted[0].id), str(wanted[1].id)]
    assert data["total"] == 3


@pytest.mark.asyncio
async def test_null_location_is_excluded(async_client, db_session):
    located, _unlocated = await _add_all(
        db_session, _incident(2.0), _incident(1.0, located=False)
    )

    data = await _nearby(async_client)

    assert _ids(data) == [str(located.id)]
    assert data["total"] == 1


@pytest.mark.asyncio
async def test_responder_fields_for_authenticated_and_anonymous_users(async_client, db_session):
    viewer, other_a, other_b = [await _create_user(db_session) for _ in range(3)]
    joined, not_joined = await _add_all(db_session, _incident(1.0), _incident(2.0))
    db_session.add_all([
        IncidentResponder(incident_id=joined.id, user_id=viewer.id, status="arrived"),
        IncidentResponder(incident_id=joined.id, user_id=other_a.id, status="responding"),
        IncidentResponder(incident_id=joined.id, user_id=other_b.id, status="withdrawn"),
        IncidentResponder(incident_id=not_joined.id, user_id=other_a.id, status="assisting"),
    ])
    await db_session.commit()

    authenticated = await _nearby(async_client, headers=_auth(viewer))
    anonymous = await _nearby(async_client)

    by_id = {item["id"]: item for item in authenticated["incidents"]}
    assert by_id[str(joined.id)]["user_responder_status"] == "arrived"
    assert by_id[str(not_joined.id)]["user_responder_status"] is None
    assert by_id[str(joined.id)]["responder_count"] == 2  # withdrawn is not counted
    assert by_id[str(not_joined.id)]["responder_count"] == 1

    assert [item["user_responder_status"] for item in anonymous["incidents"]] == [None, None]
    assert [item["responder_count"] for item in anonymous["incidents"]] == [2, 1]


@pytest.mark.asyncio
async def test_evidence_is_returned_per_incident(async_client, db_session):
    with_evidence, without_evidence = await _add_all(db_session, _incident(1.0), _incident(2.0))
    now = datetime.now(timezone.utc)
    later = IncidentEvidence(incident_id=with_evidence.id, type="video", file_path="b.mp4",
                             file_url="legacy/b.mp4", created_at=now)
    earlier = IncidentEvidence(incident_id=with_evidence.id, type="photo", file_path="a.jpg",
                               file_url="legacy/a.jpg", created_at=now - timedelta(minutes=5))
    await _add_all(db_session, later, earlier)

    items = (await _nearby(async_client))["incidents"]

    evidence = items[0]["evidence"]
    assert [e["id"] for e in evidence] == [str(earlier.id), str(later.id)]
    assert evidence[0]["file_url"] == f"/api/v1/incidents/{with_evidence.id}/evidence/{earlier.id}"
    assert items[1]["evidence"] == []


@pytest.mark.asyncio
async def test_response_shape_is_preserved(async_client, db_session):
    await _add_all(db_session, _incident(1.0, address="Somewhere"))

    data = await _nearby(async_client)

    assert set(data) == {"total", "radius_km", "incidents"}
    assert set(data["incidents"][0]) == {
        "id", "title", "description", "category", "severity", "status", "latitude", "longitude",
        "address", "distance_km", "reporter_id", "assigned_responder_id", "responder_count",
        "user_responder_status", "responders", "evidence", "created_at", "updated_at",
    }
    assert isinstance(data["incidents"][0]["distance_km"], float)


async def _selects_for_matching_incidents(async_client, db_session, db_connection, count, headers):
    responders = [await _create_user(db_session) for _ in range(2)]
    incidents = await _add_all(db_session, *[_incident(0.1 * (i + 1)) for i in range(count)])
    await _add_all(db_session, *[_incident(50.0 + i) for i in range(count)])  # outside the radius
    for incident in incidents:
        db_session.add_all([IncidentResponder(incident_id=incident.id, user_id=u.id) for u in responders])
        db_session.add(IncidentEvidence(incident_id=incident.id, type="photo", file_path="x.jpg", file_url="x"))
    await db_session.commit()

    with _record_selects(db_connection) as selects:
        data = await _nearby(async_client, headers=headers, limit=100)
    assert len(data["incidents"]) == data["total"] >= count
    assert all(item["responder_count"] == 2 and len(item["evidence"]) == 1 for item in data["incidents"])
    return len(selects)


@pytest.mark.asyncio
@pytest.mark.parametrize("authenticated", [False, True])
async def test_query_count_does_not_grow_with_matching_incidents(
    async_client, db_session, db_connection, authenticated
):
    viewer = await _create_user(db_session)
    headers = _auth(viewer) if authenticated else None

    with_5 = await _selects_for_matching_incidents(async_client, db_session, db_connection, 5, headers)
    with_20 = await _selects_for_matching_incidents(async_client, db_session, db_connection, 20, headers)

    # 5 -> 25 matching incidents (the second call also sees the first 5): same statement count.
    assert with_5 == with_20
    # count + page + responder counts + evidence (+ viewer status), plus a fixed auth lookup.
    assert with_20 <= 10
