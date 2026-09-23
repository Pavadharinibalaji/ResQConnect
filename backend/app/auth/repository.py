from uuid import UUID
from typing import Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from app.auth.models import UserSession, AuditLog
from datetime import datetime

class AuthRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create_session(self, session: UserSession) -> UserSession:
        self.db.add(session)
        await self.db.flush()
        return session

    async def get_session_by_jti(self, jti: str) -> Optional[UserSession]:
        result = await self.db.execute(
            select(UserSession).where(UserSession.refresh_token_jti == jti)
        )
        return result.scalar_one_or_none()

    async def revoke_session(self, jti: str) -> None:
        await self.db.execute(
            update(UserSession)
            .where(UserSession.refresh_token_jti == jti)
            .values(is_revoked=True)
        )
        await self.db.flush()

    async def revoke_all_sessions(self, user_id: UUID, except_jti: Optional[str] = None) -> None:
        stmt = update(UserSession).where(UserSession.user_id == user_id)
        if except_jti:
            stmt = stmt.where(UserSession.refresh_token_jti != except_jti)
        stmt = stmt.values(is_revoked=True)
        await self.db.execute(stmt)
        await self.db.flush()
        
    async def log_audit(self, log: AuditLog) -> None:
        self.db.add(log)
        await self.db.flush()
