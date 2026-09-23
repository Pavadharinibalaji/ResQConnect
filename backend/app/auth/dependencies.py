from fastapi import Depends, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from uuid import UUID

from app.dependencies.database import get_db
from app.auth.repository import AuthRepository
from app.users.service import UserService
from app.users.repository import UserRepository
from app.auth.service import AuthService
from app.auth.jwt import decode_token
from app.users.models import User
from app.auth.exceptions import InvalidTokenException, UserNotAuthenticatedException
from app.core.exceptions import ResQConnectException

security = HTTPBearer()

def get_auth_service(db: AsyncSession = Depends(get_db)) -> AuthService:
    auth_repo = AuthRepository(db)
    user_repo = UserRepository(db)
    user_service = UserService(user_repo)
    return AuthService(auth_repo, user_service)

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db)
) -> User:
    try:
        token = credentials.credentials
        payload = decode_token(token, token_type="access")
        user_id = UUID(payload["sub"])
        
        user_repo = UserRepository(db)
        user = await user_repo.get_by_id(user_id)
        if not user:
            raise UserNotAuthenticatedException("User not found")
        return user
    except ResQConnectException as e:
        raise e
    except Exception as e:
        raise InvalidTokenException("Could not validate credentials")

async def get_current_active_user(
    current_user: User = Depends(get_current_user)
) -> User:
    if current_user.status != "active":
        raise UserNotAuthenticatedException("Inactive user")
    return current_user
