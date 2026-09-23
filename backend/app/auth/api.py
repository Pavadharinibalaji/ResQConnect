from fastapi import APIRouter, Depends, Request
from app.common.responses import BaseResponse, success_response
from app.auth.schemas import VerifyFirebaseRequest, RefreshTokenRequest, TokenResponse
from app.auth.service import AuthService
from app.auth.dependencies import get_auth_service, get_current_user
from app.users.models import User
from app.core.config import settings

router = APIRouter(prefix="/auth", tags=["Auth"])

@router.post("/verify-firebase", response_model=BaseResponse[TokenResponse])
async def verify_firebase(
    request_data: VerifyFirebaseRequest,
    request: Request,
    auth_service: AuthService = Depends(get_auth_service)
):
    ip_address = request.client.host if request.client else None
    user_agent = request.headers.get("user-agent")
    
    access_token, refresh_token = await auth_service.verify_and_login(
        id_token=request_data.id_token,
        device_id=request_data.device_id,
        ip_address=ip_address,
        user_agent=user_agent
    )
    
    return success_response(
        data=TokenResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60
        ),
        message="Authentication successful"
    )

@router.post("/refresh", response_model=BaseResponse[TokenResponse])
async def refresh_token(
    request_data: RefreshTokenRequest,
    request: Request,
    auth_service: AuthService = Depends(get_auth_service)
):
    ip_address = request.client.host if request.client else None
    user_agent = request.headers.get("user-agent")
    
    access_token, refresh_token = await auth_service.refresh_tokens(
        refresh_token=request_data.refresh_token,
        ip_address=ip_address,
        user_agent=user_agent
    )
    
    return success_response(
        data=TokenResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60
        ),
        message="Token refreshed successfully"
    )

@router.post("/logout", response_model=BaseResponse[None])
async def logout(
    request_data: RefreshTokenRequest,
    request: Request,
    auth_service: AuthService = Depends(get_auth_service)
):
    ip_address = request.client.host if request.client else None
    user_agent = request.headers.get("user-agent")
    
    await auth_service.logout(
        refresh_token=request_data.refresh_token,
        ip_address=ip_address,
        user_agent=user_agent
    )
    return success_response(message="Logged out successfully")

@router.post("/logout-all", response_model=BaseResponse[None])
async def logout_all(
    current_user: User = Depends(get_current_user),
    auth_service: AuthService = Depends(get_auth_service)
):
    await auth_service.logout_all(user_id=current_user.id)
    return success_response(message="Logged out from all devices")
