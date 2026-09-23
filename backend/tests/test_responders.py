import pytest
from app.services.responder_service import validate_incident_status_transition, VALID_RESPONDER_STATUSES
from fastapi import HTTPException

def test_incident_status_transition_valid():
    # Valid transitions
    validate_incident_status_transition("reported", "verified")
    validate_incident_status_transition("reported", "active")
    validate_incident_status_transition("active", "resolved")
    validate_incident_status_transition("active", "cancelled")

def test_incident_status_transition_invalid():
    # Invalid transition (resolved -> active)
    with pytest.raises(HTTPException) as exc_info:
        validate_incident_status_transition("resolved", "active")
    assert exc_info.value.status_code == 400

    # Invalid transition (cancelled -> reported)
    with pytest.raises(HTTPException) as exc_info2:
        validate_incident_status_transition("cancelled", "reported")
    assert exc_info2.value.status_code == 400

def test_valid_responder_statuses():
    assert "responding" in VALID_RESPONDER_STATUSES
    assert "arrived" in VALID_RESPONDER_STATUSES
    assert "assisting" in VALID_RESPONDER_STATUSES
    assert "completed" in VALID_RESPONDER_STATUSES
    assert "withdrawn" in VALID_RESPONDER_STATUSES
