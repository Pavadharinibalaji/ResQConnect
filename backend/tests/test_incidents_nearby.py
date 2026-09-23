import pytest
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
