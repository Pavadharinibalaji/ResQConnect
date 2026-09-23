from sqlalchemy import Column, String, DateTime, Boolean, ForeignKey
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship
from app.database.base import Base
from app.database.mixins import UUIDMixin, TimestampMixin

class UserSession(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "user_sessions"

    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    refresh_token_jti = Column(String, unique=True, index=True, nullable=False)
    device_id = Column(String, nullable=True)
    user_agent = Column(String, nullable=True)
    ip_address = Column(String, nullable=True)
    login_time = Column(DateTime, nullable=False)
    last_active = Column(DateTime, nullable=False)
    expires_at = Column(DateTime, nullable=False)
    is_revoked = Column(Boolean, default=False, nullable=False)

    # Relationships
    user = relationship("User", backref="sessions")


class AuditLog(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "audit_logs"

    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True, index=True)
    action = Column(String, nullable=False, index=True)
    ip_address = Column(String, nullable=True)
    user_agent = Column(String, nullable=True)
    details = Column(JSONB, nullable=True)
