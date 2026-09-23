import jwt
from datetime import datetime, timedelta
from typing import Any, Dict
from uuid import UUID, uuid4
from app.core.config import settings
from app.auth.exceptions import InvalidTokenException

def create_access_token(subject: UUID) -> str:
    expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode = {"exp": expire, "sub": str(subject), "type": "access"}
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.JWT_ALGORITHM)
    return encoded_jwt

def create_refresh_token(subject: UUID, jti: str) -> str:
    expire = datetime.utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    to_encode = {"exp": expire, "sub": str(subject), "type": "refresh", "jti": jti}
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.JWT_ALGORITHM)
    return encoded_jwt

def decode_token(token: str, token_type: str = "access") -> Dict[str, Any]:
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
        if payload.get("type") != token_type:
            raise InvalidTokenException("Invalid token type")
        return payload
    except jwt.ExpiredSignatureError:
        raise InvalidTokenException("Token has expired")
    except jwt.PyJWTError:
        raise InvalidTokenException("Could not validate credentials")
