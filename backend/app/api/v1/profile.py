import logging
from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.middleware.rbac import get_current_user
from app.models.auth import User
from app.schemas.profiles import (
    ProfileCompletionStatusResponse,
    ProfileResponse,
    ProfileUpdateRequest,
)
from app.schemas.response import success_response
from app.services.profile_service import ProfileService

logger = logging.getLogger("resqconnect.api.profile")
router = APIRouter(prefix="/profile", tags=["User Profile Engine"])

@router.get("", status_code=status.HTTP_200_OK)
async def get_profile(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Retrieves the authenticated user's profile details.
    """
    profile = await ProfileService.get_or_create_profile(db, current_user)
    return success_response(
        data=ProfileResponse.model_validate(profile).model_dump(mode="json"),
        message="Profile retrieved successfully."
    )

@router.put("", status_code=status.HTTP_200_OK)
async def update_profile(
    payload: ProfileUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Idempotent endpoint to create/update full profile setup details and settings.
    """
    updated_profile = await ProfileService.update_profile(db, current_user, payload)
    return success_response(
        data=ProfileResponse.model_validate(updated_profile).model_dump(mode="json"),
        message="Profile updated successfully."
    )

@router.get("/completion", status_code=status.HTTP_200_OK)
async def get_profile_completion_status(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Returns the profile completion state flag for initial routing decisions.
    """
    profile = await ProfileService.get_or_create_profile(db, current_user)
    data = ProfileCompletionStatusResponse(
        user_id=current_user.id,
        is_completed=profile.profile_completed,
        emergency_role=profile.emergency_role
    )
    return success_response(
        data=data.model_dump(mode="json"),
        message="Profile completion status checked."
    )
