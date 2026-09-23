import uuid
import pytest
from datetime import timedelta
from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.testclient import TestClient
from jose import jwt

from app.core.config import settings
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_token,
    verify_hash,
)
from app.middleware.rbac import RoleChecker, get_current_user
from app.models.auth import User

# Setup dummy app to test RBAC dependencies
app = FastAPI()

class DummyRole:
    def __init__(self, name: str):
        self.name = name

class DummyUser:
    def __init__(self, uid: str, role: str, is_active: bool = True, roles_list: list = None):
        self.id = uuid.UUID(uid)
        self.role = role
        self.is_active = is_active
        self.roles = [DummyRole(r) for r in (roles_list or [])]

# Mock user retrieval dependencies
def get_mock_citizen_user():
    return DummyUser("11111111-1111-1111-1111-111111111111", "citizen")

def get_mock_police_user():
    return DummyUser("22222222-2222-2222-2222-222222222222", "police")

# FastAPI endpoint functions (prefixed with "route_" so pytest doesn't collect them as unit tests)
@app.get("/test-citizen")
def route_citizen_endpoint(user: User = Depends(RoleChecker(allowed_roles=["citizen"]))):
    return {"status": "success", "user_id": str(user.id)}

@app.get("/test-responder")
def route_responder_endpoint(user: User = Depends(RoleChecker(allowed_roles=["police", "fire"]))):
    return {"status": "success", "user_id": str(user.id)}


def test_jwt_generation_and_decoding():
    """
    Verifies that JWT access and refresh tokens generate and parse correctly (Task 5 & 15).
    """
    user_id = str(uuid.uuid4())
    role = "volunteer"
    
    # 1. Test Access Token
    access_token = create_access_token(user_id, role)
    decoded_access = decode_token(access_token, "access")
    
    assert decoded_access is not None
    assert decoded_access["sub"] == user_id
    assert decoded_access["role"] == role
    assert decoded_access["type"] == "access"

    # 2. Test Refresh Token
    refresh_token = create_refresh_token(user_id)
    decoded_refresh = decode_token(refresh_token, "refresh")
    
    assert decoded_refresh is not None
    assert decoded_refresh["sub"] == user_id
    assert decoded_refresh["type"] == "refresh"

    # 3. Test Invalid Token Type mapping
    assert decode_token(access_token, "refresh") is None
    assert decode_token(refresh_token, "access") is None


def test_token_hashing_and_verification():
    """
    Verifies that refresh tokens are hashed and compared correctly (Task 5 & 15).
    """
    token = "some-long-refresh-token-string"
    hashed = hash_token(token)
    
    assert hashed != token
    assert len(hashed) == 64
    assert verify_hash(token, hashed) is True
    assert verify_hash("wrong-token", hashed) is False


def test_rbac_middleware_citizens_pass():
    """
    Tests that RoleChecker allows citizens to access citizen-specific endpoints (Task 3 & 15).
    """
    # Override get_current_user to return mock citizen
    app.dependency_overrides[get_current_user] = get_mock_citizen_user
    
    client = TestClient(app)
    response = client.get("/test-citizen")
    
    assert response.status_code == 200
    assert response.json()["status"] == "success"
    assert response.json()["user_id"] == "11111111-1111-1111-1111-111111111111"
    
    app.dependency_overrides.clear()


def test_rbac_middleware_citizens_blocked():
    """
    Tests that RoleChecker blocks citizens from responder endpoints (Task 3 & 15).
    """
    # Override get_current_user to return mock citizen
    app.dependency_overrides[get_current_user] = get_mock_citizen_user
    
    client = TestClient(app)
    response = client.get("/test-responder")
    
    # Citizen is not in ["police", "fire"] so access must be forbidden (403)
    assert response.status_code == 403
    
    app.dependency_overrides.clear()


def test_rbac_middleware_direct_checks():
    """
    Tests RoleChecker class invocation logic directly (Task 3 & 15).
    """
    checker = RoleChecker(allowed_roles=["police", "fire"])
    
    # 1. Police user has access
    assert checker(get_mock_police_user()) is not None
    
    # 2. Citizen user raises 403 Forbidden
    with pytest.raises(HTTPException) as excinfo:
        checker(get_mock_citizen_user())
        
    assert excinfo.value.status_code == 403
    assert "Access denied" in excinfo.value.detail
