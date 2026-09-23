from uuid import UUID, uuid4
from datetime import datetime, timedelta
from typing import Optional, Tuple
from app.auth.repository import AuthRepository
from app.auth.models import UserSession, AuditLog
from app.auth.jwt import create_access_token, create_refresh_token, decode_token
from app.auth.firebase import verify_firebase_token
from app.auth.exceptions import InvalidTokenException
from app.users.service import UserService
from app.core.config import settings
import logging

logger = logging.getLogger("resqconnect")

class AuthService:
    def __init__(self, repository: AuthRepository, user_service: UserService):
        self.repository = repository
        self.user_service = user_service

    async def verify_and_login(self, id_token: str, device_id: Optional[str], ip_address: Optional[str], user_agent: Optional[str]) -> Tuple[str, str]:
        # 1. Verify firebase token
        fb_data = await verify_firebase_token(id_token)
        
        # 2. Find or create user
        user = await self.user_service.find_or_create(fb_data["uid"], fb_data["phone_number"])
        
        # 3. Generate tokens
        jti = str(uuid4())
        access_token = create_access_token(user.id)
        refresh_token = create_refresh_token(user.id, jti)
        
        # 4. Save session
        expires_at = datetime.utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
        session = UserSession(
            user_id=user.id,
            refresh_token_jti=jti,
            device_id=device_id,
            ip_address=ip_address,
            user_agent=user_agent,
            login_time=datetime.utcnow(),
            last_active=datetime.utcnow(),
            expires_at=expires_at
        )
        await self.repository.create_session(session)
        
        # 5. Audit log
        await self.log_action(user.id, "login", ip_address, user_agent)
        
        return access_token, refresh_token

    async def refresh_tokens(self, refresh_token: str, ip_address: Optional[str], user_agent: Optional[str]) -> Tuple[str, str]:
        # 1. Decode token
        payload = decode_token(refresh_token, token_type="refresh")
        user_id = UUID(payload["sub"])
        jti = payload["jti"]
        
        # 2. Check database session
        session = await self.repository.get_session_by_jti(jti)
        if not session or session.is_revoked or session.expires_at < datetime.utcnow():
            await self.log_action(user_id, "failed_refresh", ip_address, user_agent, {"jti": jti, "reason": "invalid_session"})
            raise InvalidTokenException("Invalid or revoked session")
            
        # 3. Rotate tokens (Invalidate old, create new)
        await self.repository.revoke_session(jti)
        
        new_jti = str(uuid4())
        new_access_token = create_access_token(user_id)
        new_refresh_token = create_refresh_token(user_id, new_jti)
        
        expires_at = datetime.utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
        new_session = UserSession(
            user_id=user_id,
            refresh_token_jti=new_jti,
            device_id=session.device_id,
            ip_address=ip_address,
            user_agent=user_agent,
            login_time=session.login_time,
            last_active=datetime.utcnow(),
            expires_at=expires_at
        )
        await self.repository.create_session(new_session)
        await self.log_action(user_id, "refresh", ip_address, user_agent)
        
        return new_access_token, new_refresh_token

    async def logout(self, refresh_token: str, ip_address: Optional[str], user_agent: Optional[str]) -> None:
        try:
            payload = decode_token(refresh_token, token_type="refresh")
            user_id = UUID(payload["sub"])
            jti = payload["jti"]
            await self.repository.revoke_session(jti)
            await self.log_action(user_id, "logout", ip_address, user_agent)
        except InvalidTokenException:
            pass # Already expired/invalid, safe to ignore on logout

    async def logout_all(self, user_id: UUID, current_jti: Optional[str] = None) -> None:
        await self.repository.revoke_all_sessions(user_id, except_jti=current_jti)
        await self.log_action(user_id, "logout_all", None, None)

    async def log_action(self, user_id: UUID, action: str, ip_address: Optional[str], user_agent: Optional[str], details: dict = None) -> None:
        log = AuditLog(
            user_id=user_id,
            action=action,
            ip_address=ip_address,
            user_agent=user_agent,
            details=details
        )
        await self.repository.log_audit(log)
