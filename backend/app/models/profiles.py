import uuid
from datetime import datetime, timezone
from typing import Optional, List
from sqlalchemy import String, Boolean, Float, DateTime, ForeignKey, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.models.base import Base

class Profile(Base):
    """
    Represents detailed user profile information (Profile System).
    Linked 1-to-1 with the core User authentication model.
    """
    __tablename__ = "profiles"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4, index=True)
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
        index=True
    )

    display_name: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    username: Mapped[Optional[str]] = mapped_column(String(50), unique=True, nullable=True, index=True)
    bio: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    avatar_url: Mapped[Optional[str]] = mapped_column(String(1024), nullable=True)
    location: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)

    emergency_role: Mapped[str] = mapped_column(String(50), default="citizen", nullable=False)
    skills: Mapped[List[str]] = mapped_column(JSON, default=list, nullable=False)
    response_radius_km: Mapped[float] = mapped_column(Float, default=10.0, nullable=False)

    emergency_alerts_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    nearby_alerts_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    critical_override_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    availability_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    high_urgency_sound_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    profile_completed: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False
    )

    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="profile")
