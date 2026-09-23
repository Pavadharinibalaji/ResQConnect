import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.database import get_db
from app.core.roles import ADMIN_GRANTABLE_ROLES, SELF_SELECTABLE_ROLES, describe, granted_role_names, is_admin
from app.middleware.rbac import get_current_user
from app.models.auth import Role, User
from app.models.profiles import Profile
from app.schemas.response import success_response
from app.utils.audit import log_audit_event

logger = logging.getLogger("resqconnect.api.admin")
router = APIRouter(prefix="/admin", tags=["Administration"])

# Primary/profile role a user falls back to when the role it relied on is revoked.
FALLBACK_ROLE = "citizen"


class RoleGrantRequest(BaseModel):
    model_config = ConfigDict(strict=True)
    role: str = Field(..., description=f"Role to grant: {describe(ADMIN_GRANTABLE_ROLES)}")


async def require_admin(current_user: User = Depends(get_current_user)) -> User:
    if not is_admin(current_user):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Administrator privileges required.")
    return current_user


def _check_role_change(admin: User, target_user_id: uuid.UUID, role_name: str) -> None:
    # Exact canonical names only: no case folding or aliases for privileged roles.
    if role_name not in ADMIN_GRANTABLE_ROLES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Role cannot be managed here. Admin-granted roles: {describe(ADMIN_GRANTABLE_ROLES)}; "
                   f"{describe(SELF_SELECTABLE_ROLES)} are self-service.",
        )
    # Also guarantees the acting admin keeps admin rights, so the last admin cannot be removed.
    if target_user_id == admin.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Administrators cannot change their own roles.")


async def _load_user(db: AsyncSession, user_id: uuid.UUID) -> User:
    user = (await db.execute(
        select(User).where(User.id == user_id).options(selectinload(User.roles))
    )).scalars().first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found.")
    return user


def _role_summary(user: User) -> dict:
    return {"user_id": str(user.id), "primary_role": user.role, "roles": sorted(granted_role_names(user))}


@router.post("/users/{user_id}/roles", status_code=status.HTTP_200_OK)
async def grant_role(
    user_id: uuid.UUID,
    payload: RoleGrantRequest,
    request: Request,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Grants an admin-controlled role (ngo, police, fire, ambulance, admin) to another user."""
    _check_role_change(admin, user_id, payload.role)
    target = await _load_user(db, user_id)

    role = (await db.execute(select(Role).where(Role.name == payload.role))).scalars().first()
    if role is None:
        logger.error("Role '%s' is missing from the roles table.", payload.role)
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Role is not configured.")

    granted = role not in target.roles
    if granted:
        target.roles.append(role)
        await db.flush()
        await log_audit_event(
            db, user_id=admin.id, action="role_granted",
            ip_address=request.client.host if request.client else None,
            user_agent=request.headers.get("user-agent"),
            details={"target_user_id": str(target.id), "role": payload.role},
        )

    return success_response(
        data=_role_summary(target),
        message=f"Role '{payload.role}' granted." if granted else f"User already holds role '{payload.role}'.",
    )


@router.delete("/users/{user_id}/roles/{role_name}", status_code=status.HTTP_200_OK)
async def revoke_role(
    user_id: uuid.UUID,
    role_name: str,
    request: Request,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Revokes an admin-controlled role; primary/profile roles relying on it fall back to citizen."""
    _check_role_change(admin, user_id, role_name)
    target = await _load_user(db, user_id)

    held_grant = next((role for role in target.roles if role.name == role_name), None)
    if held_grant is None and target.role != role_name:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User does not hold this role.")

    if held_grant is not None:
        target.roles.remove(held_grant)
    if target.role == role_name:
        target.role = FALLBACK_ROLE
    profile = (await db.execute(select(Profile).where(Profile.user_id == target.id))).scalars().first()
    if profile is not None and profile.emergency_role == role_name:
        profile.emergency_role = FALLBACK_ROLE

    await db.flush()
    await log_audit_event(
        db, user_id=admin.id, action="role_revoked",
        ip_address=request.client.host if request.client else None,
        user_agent=request.headers.get("user-agent"),
        details={"target_user_id": str(target.id), "role": role_name},
    )
    return success_response(data=_role_summary(target), message=f"Role '{role_name}' revoked.")
