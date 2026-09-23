import hashlib
from datetime import timedelta
from typing import Any, Dict, Optional
from jose import jwt, JWTError
from app.core.config import settings
from app.shared.utils import utc_now

def hash_token(token: str) -> str:
    """
    Hashes a token using SHA-256 for secure database storage (Task 5).
    """
    return hashlib.sha256(token.encode('utf-8')).hexdigest()

def verify_hash(token: str, token_hash: str) -> bool:
    """
    Verifies a token against its stored hash (Task 5).
    """
    return hash_token(token) == token_hash

def create_access_token(user_id: str, role: str) -> str:
    """
    Generates a short-lived JWT Access Token containing user_id and role (Task 5).
    """
    expire = utc_now() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode: Dict[str, Any] = {
        "sub": str(user_id),
        "role": role,
        "type": "access",
        "exp": expire
    }
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.JWT_ALGORITHM)
    return encoded_jwt

def create_refresh_token(user_id: str) -> str:
    """
    Generates a long-lived JWT Refresh Token (Task 5).
    """
    # 30 days refresh token lifecycle
    expire = utc_now() + timedelta(days=30)
    to_encode: Dict[str, Any] = {
        "sub": str(user_id),
        "type": "refresh",
        "exp": expire
    }
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.JWT_ALGORITHM)
    return encoded_jwt

def decode_token(token: str, expected_type: str = "access") -> Optional[Dict[str, Any]]:
    """
    Decodes and validates a JWT token (Task 5).
    """
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
        token_type = payload.get("type")
        if token_type != expected_type:
            return None
        return payload
    except JWTError:
        return None
