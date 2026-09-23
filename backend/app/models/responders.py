import uuid
from datetime import datetime
from typing import Optional
from sqlalchemy import String, DateTime, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.models.base import Base
from app.shared.utils import utc_now

class IncidentResponder(Base):
    """
    Represents user responses to emergency incidents (Phase 1).
    Statuses: responding, arrived, assisting, completed, withdrawn
    """
    __tablename__ = "incident_responders"
    __table_args__ = (
        UniqueConstraint("incident_id", "user_id", name="uq_incident_responder"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4, index=True)
    
    incident_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("incidents.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    status: Mapped[str] = mapped_column(String(50), nullable=False, default="responding", index=True)
    notes: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)

    joined_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now, nullable=False)
    completed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    # Relationships
    incident: Mapped["Incident"] = relationship("Incident", back_populates="responders")
    user: Mapped["User"] = relationship("User", foreign_keys=[user_id])
