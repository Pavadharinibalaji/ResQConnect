import logging
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.database import get_db
from app.core.firebase_auth import verify_firebase_id_token
from app.core.roles import SELF_SELECTABLE_ROLES, resolve_self_service_role
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_token,
)
from app.middleware.rbac import get_current_user
from app.models.auth import RefreshToken, Role, User
from app.schemas.auth import (
    FirebaseVerifyRequest,
    ProfileUpdateRequest,
    TokenRefreshRequest,
    UserProfileResponse,
)
from app.schemas.response import success_response
from app.utils.audit import log_audit_event

logger = logging.getLogger("resqconnect.api.auth")
router = APIRouter(prefix="/auth", tags=["Authentication & Profile"])

@router.post("/verify-firebase", status_code=status.HTTP_200_OK)
async def verify_firebase(
    payload: FirebaseVerifyRequest,
    request: Request,
    db: AsyncSession = Depends(get_db)
):
    """
    Verifies Firebase ID Token, signs in or registers user, and generates JWT Access/Refresh tokens (Task 4 & 6).
    """
    ip_address = request.client.host if request.client else None
    user_agent = request.headers.get("user-agent")

    try:
        # Verify Token via Admin SDK
        firebase_user = verify_firebase_id_token(payload.id_token)
    except ValueError as e:
        # Log failed login attempt
        await log_audit_event(
            db, user_id=None, action="failed_login",
            ip_address=ip_address, user_agent=user_agent,
            details={"error": str(e)}
        )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e)
        )

    firebase_uid = firebase_user["uid"]
    phone_number = firebase_user["phone_number"]
    full_name = firebase_user.get("name")

    # Look up User in database
    stmt = select(User).where(User.firebase_uid == firebase_uid).options(selectinload(User.roles))
    result = await db.execute(stmt)
    user = result.scalars().first()

    is_new_user = False
    if not user:
        is_new_user = True
        # Check if the citizen role exists in Roles seed table
        role_stmt = select(Role).where(Role.name == "citizen")
        role_result = await db.execute(role_stmt)
        citizen_role = role_result.scalars().first()
        
        # Create new user record (Task 2 & 4)
        user = User(
            firebase_uid=firebase_uid,
            phone_number=phone_number,
            full_name=full_name,
            role="citizen",
            is_verified=True,
            is_active=True
        )
        if citizen_role:
            user.roles.append(citizen_role)
        
        db.add(user)
        await db.flush() # get user.id mapping
    else:
        # Ensure profile verification flag is checked
        if not user.is_active:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="User account has been deactivated."
            )

    # Update login timestamp
    user.last_login = datetime.now(timezone.utc)
    
    # Create Local Access/Refresh Tokens (Task 5)
    access_token = create_access_token(str(user.id), user.role)
    refresh_token = create_refresh_token(str(user.id))

    # Hash and save refresh token
    hashed_rt = hash_token(refresh_token)
    # Set expiration matching 30 days
    from datetime import timedelta
    expire_time = datetime.now(timezone.utc) + timedelta(days=30)

    db_rt = RefreshToken(
        user_id=user.id,
        token_hash=hashed_rt,
        expires_at=expire_time
    )
    db.add(db_rt)

    # Log successful login auditing
    await log_audit_event(
        db, user_id=user.id, action="login",
        ip_address=ip_address, user_agent=user_agent,
        details={"is_new_user": is_new_user}
    )

    response_data = {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "is_new_user": is_new_user,
        "user": UserProfileResponse.model_validate(user).model_dump(mode="json"),
    }

    return success_response(
        data=response_data,
        message="Authentication successful."
    )

@router.post("/refresh", status_code=status.HTTP_200_OK)
async def refresh_tokens(
    payload: TokenRefreshRequest,
    request: Request,
    db: AsyncSession = Depends(get_db)
):
    """
    Accepts Refresh Token, rotates refresh session, and returns new Access/Refresh tokens (Task 5 & 6).
    """
    ip_address = request.client.host if request.client else None
    user_agent = request.headers.get("user-agent")

    token = payload.refresh_token
    token_claims = decode_token(token, "refresh")

    if not token_claims:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session expired or invalid refresh credentials."
        )

    user_id = token_claims.get("sub")
    hashed_input = hash_token(token)

    # Query refresh tokens database
    stmt = select(RefreshToken).where(
        RefreshToken.token_hash == hashed_input,
        RefreshToken.is_revoked == False
    ).options(selectinload(RefreshToken.user))
    
    result = await db.execute(stmt)
    db_rt = result.scalars().first()

    now_utc = datetime.now(timezone.utc)
    if not db_rt or db_rt.expires_at < now_utc:
        # Replay Attack or Revoked Token
        if db_rt:
            db_rt.is_revoked = True
            await db.flush()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid session refresh request."
        )

    user = db_rt.user
    if not user or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Deactivated user account."
        )

    # 1. Rotate Refresh Token: Revoke old one
    db_rt.is_revoked = True

    # 2. Generate new Access and Refresh tokens
    new_access_token = create_access_token(str(user.id), user.role)
    new_refresh_token = create_refresh_token(str(user.id))

    # 3. Hash and store new refresh token
    from datetime import timedelta
    new_expire_time = datetime.now(timezone.utc) + timedelta(days=30)
    
    new_db_rt = RefreshToken(
        user_id=user.id,
        token_hash=hash_token(new_refresh_token),
        expires_at=new_expire_time
    )
    db.add(new_db_rt)

    # Log audit event
    await log_audit_event(
        db, user_id=user.id, action="refresh",
        ip_address=ip_address, user_agent=user_agent
    )

    response_data = {
        "access_token": new_access_token,
        "refresh_token": new_refresh_token,
        "token_type": "bearer"
    }

    return success_response(
        data=response_data,
        message="Session tokens rotated successfully."
    )

@router.post("/logout", status_code=status.HTTP_200_OK)
async def logout(
    payload: TokenRefreshRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Revokes the provided Refresh Token, logging out the active device session (Task 5 & 6).
    """
    ip_address = request.client.host if request.client else None
    user_agent = request.headers.get("user-agent")

    hashed_token = hash_token(payload.refresh_token)
    stmt = select(RefreshToken).where(
        RefreshToken.token_hash == hashed_token,
        RefreshToken.user_id == current_user.id
    )
    result = await db.execute(stmt)
    db_rt = result.scalars().first()

    if db_rt:
        db_rt.is_revoked = True
        await db.flush()

    await log_audit_event(
        db, user_id=current_user.id, action="logout",
        ip_address=ip_address, user_agent=user_agent
    )

    return success_response(message="Logout successful.")

@router.post("/logout-all", status_code=status.HTTP_200_OK)
async def logout_all_devices(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Revokes all Refresh Tokens associated with the user, forcing logouts on all devices (Task 5 & 6).
    """
    ip_address = request.client.host if request.client else None
    user_agent = request.headers.get("user-agent")

    # Revoke all active refresh tokens
    stmt = select(RefreshToken).where(
        RefreshToken.user_id == current_user.id,
        RefreshToken.is_revoked == False
    )
    result = await db.execute(stmt)
    active_tokens = result.scalars().all()

    for token in active_tokens:
        token.is_revoked = True

    await log_audit_event(
        db, user_id=current_user.id, action="logout_all",
        ip_address=ip_address, user_agent=user_agent
    )

    return success_response(message="Logged out from all connected devices.")

@router.get("/me", response_model=None)
async def get_me(
    current_user: User = Depends(get_current_user)
):
    """
    Returns the authenticated user details (Task 6).
    """
    profile = UserProfileResponse.model_validate(current_user)
    return success_response(
        data=profile.model_dump(),
        message="User profile retrieved successfully."
    )

@router.post("/profile-setup", status_code=status.HTTP_200_OK)
async def profile_setup(
    payload: ProfileUpdateRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Saves full name, updates role selection, and generates new access token (Task 9).
    """
    ip_address = request.client.host if request.client else None
    user_agent = request.headers.get("user-agent")

    # Self-service may pick citizen/volunteer or a privileged role already granted by an admin.
    selected_role = resolve_self_service_role(current_user, payload.role)

    # 1. Update basic fields
    current_user.full_name = payload.full_name
    current_user.profile_photo = payload.profile_photo
    current_user.role = selected_role

    # 2. Record self-selectable roles in user_roles; privileged roles are only ever
    #    written there by the admin role endpoints.
    if selected_role in SELF_SELECTABLE_ROLES:
        stmt = select(Role).where(Role.name == selected_role)
        result = await db.execute(stmt)
        target_role = result.scalars().first()

        if target_role and target_role not in current_user.roles:
            current_user.roles.append(target_role)

    await db.flush()

    # 3. Generate a new JWT access token reflecting the updated role claim!
    new_access_token = create_access_token(str(current_user.id), current_user.role)

    await log_audit_event(
        db, user_id=current_user.id, action="profile_setup",
        ip_address=ip_address, user_agent=user_agent,
        details={"selected_role": current_user.role}
    )

    response_data = {
        "access_token": new_access_token,
        "user": UserProfileResponse.model_validate(current_user)
    }

    return success_response(
        data=response_data,
        message="Profile initialized successfully."
    )
