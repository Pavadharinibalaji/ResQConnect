import logging
from typing import Optional
from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.roles import SELF_SELECTABLE_ROLES, resolve_self_service_role
from app.models.auth import User, Role
from app.models.profiles import Profile
from app.schemas.profiles import ProfileUpdateRequest

logger = logging.getLogger("resqconnect.services.profile")

class ProfileService:
    @staticmethod
    async def get_or_create_profile(db: AsyncSession, user: User) -> Profile:
        """
        Retrieves user profile or creates an initial default profile.
        """
        stmt = select(Profile).where(Profile.user_id == user.id)
        result = await db.execute(stmt)
        profile = result.scalars().first()

        if not profile:
            profile = Profile(
                user_id=user.id,
                display_name=user.full_name or "Responder User",
                avatar_url=user.profile_photo,
                emergency_role=user.role or "citizen",
                profile_completed=False,
            )
            db.add(profile)
            await db.flush()

        return profile

    @staticmethod
    async def update_profile(db: AsyncSession, user: User, payload: ProfileUpdateRequest) -> Profile:
        """
        Updates user profile, validates username handle uniqueness, and sets profile_completed = True.
        """
        # Role authority: self-selectable roles or privileged roles already granted by an admin.
        emergency_role = resolve_self_service_role(user, payload.emergency_role)

        # Retrieve existing or new profile
        profile = await ProfileService.get_or_create_profile(db, user)

        # Check username uniqueness if handle provided and changed
        if payload.username and payload.username != profile.username:
            stmt = select(Profile).where(
                Profile.username == payload.username,
                Profile.id != profile.id
            )
            result = await db.execute(stmt)
            existing = result.scalars().first()
            if existing:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Username '@{payload.username}' is already taken. Please choose another username."
                )
            profile.username = payload.username

        # Update profile fields
        profile.display_name = payload.display_name
        profile.bio = payload.bio
        profile.avatar_url = payload.avatar_url
        profile.location = payload.location
        profile.emergency_role = emergency_role
        profile.skills = payload.skills
        profile.response_radius_km = payload.response_radius_km

        profile.emergency_alerts_enabled = payload.emergency_alerts_enabled
        profile.nearby_alerts_enabled = payload.nearby_alerts_enabled
        profile.critical_override_enabled = payload.critical_override_enabled
        profile.availability_enabled = payload.availability_enabled
        profile.high_urgency_sound_enabled = payload.high_urgency_sound_enabled

        profile.profile_completed = True

        # Synchronize core user attributes
        user.full_name = payload.display_name
        user.role = emergency_role
        if payload.avatar_url:
            user.profile_photo = payload.avatar_url

        # Record self-selectable roles in user_roles; privileged roles are only ever
        # written there by the admin role endpoints.
        if emergency_role in SELF_SELECTABLE_ROLES:
            role_stmt = select(Role).where(Role.name == emergency_role)
            role_res = await db.execute(role_stmt)
            target_role = role_res.scalars().first()

            if target_role and target_role not in user.roles:
                user.roles.append(target_role)

        await db.flush()
        logger.info(f"Profile updated successfully for user {user.id} ({payload.display_name})")
        return profile
