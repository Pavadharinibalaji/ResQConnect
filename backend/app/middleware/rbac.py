from typing import List, Optional
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.database import get_db
from app.core.roles import is_admin
from app.core.security import decode_token
from app.models.auth import User

# Bearer Authorization Token extraction scheme
security_bearer = HTTPBearer()

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security_bearer),
    db: AsyncSession = Depends(get_db)
) -> User:
    """
    Dependency that decodes the HTTP Bearer JWT Access Token and fetches the
    associated User from the database, verifying the account is active.
    """
    token = credentials.credentials
    payload = decode_token(token, "access")
    
    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session expired or invalid token.",
            headers={"WWW-Authenticate": "Bearer"},
        )
        
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid session token context.",
        )

    # Fetch user, preloading roles relationship using selectinload (SQLAlchemy 2.0 style)
    stmt = select(User).where(User.id == user_id).options(selectinload(User.roles))
    result = await db.execute(stmt)
    user = result.scalars().first()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Responder account not found.",
        )
        
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This account has been deactivated.",
        )
        
    return user


security_bearer_optional = HTTPBearer(auto_error=False)

async def get_optional_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security_bearer_optional),
    db: AsyncSession = Depends(get_db)
) -> Optional[User]:
    """
    Optional authentication dependency. Returns User if valid Bearer token provided, else None.
    """
    if not credentials:
        return None

    try:
        token = credentials.credentials
        payload = decode_token(token, "access")
        if not payload:
            return None

        user_id = payload.get("sub")
        if not user_id:
            return None

        stmt = select(User).where(User.id == user_id).options(selectinload(User.roles))
        result = await db.execute(stmt)
        user = result.scalars().first()

        if user and user.is_active:
            return user
    except Exception:
        pass

    return None


class RoleChecker:
    """
    FastAPI Dependency builder enforcing Role-Based Access Control (RBAC) (Task 3).
    Allows access if the user's role matches any in the allowed list, or if the user is an 'admin'.
    """
    def __init__(self, allowed_roles: List[str]):
        self.allowed_roles = allowed_roles

    def __call__(self, current_user: User = Depends(get_current_user)) -> User:
        # Admins bypass role checks (single admin definition: app.core.roles.is_admin)
        if is_admin(current_user):
            return current_user

        user_roles_list = [r.name for r in current_user.roles] + [current_user.role]

        # Match roles
        has_access = any(r in self.allowed_roles for r in user_roles_list)
        if not has_access:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access denied. Insufficient permissions. Required: {self.allowed_roles}",
            )
            
        return current_user
