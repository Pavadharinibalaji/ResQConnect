from uuid import UUID
from fastapi import APIRouter, Depends
from app.common.responses import BaseResponse, success_response
from app.users.schemas import UserResponse, UserUpdate
from app.users.service import UserService
from app.users.dependencies import get_user_service
# Note: get_current_user will be imported from app.auth.dependencies once auth is built.
# To prevent circular/missing imports initially, we mock it or import it if it exists.
from app.auth.dependencies import get_current_user, get_current_active_user
from app.users.models import User

router = APIRouter(prefix="/users", tags=["Users"])

@router.get("/me", response_model=BaseResponse[UserResponse])
async def get_me(
    current_user: User = Depends(get_current_active_user)
):
    return success_response(data=UserResponse.model_validate(current_user))

@router.patch("/profile", response_model=BaseResponse[UserResponse])
async def update_profile(
    user_update: UserUpdate,
    current_user: User = Depends(get_current_active_user),
    user_service: UserService = Depends(get_user_service)
):
    updated_user = await user_service.update_profile(current_user.id, user_update)
    return success_response(data=UserResponse.model_validate(updated_user), message="Profile updated")

@router.get("/{id}", response_model=BaseResponse[UserResponse])
async def get_user_by_id(
    id: UUID,
    user_service: UserService = Depends(get_user_service),
    current_user: User = Depends(get_current_active_user) # Requires auth to view others
):
    user = await user_service.get_user(id)
    return success_response(data=UserResponse.model_validate(user))
