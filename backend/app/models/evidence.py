import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.models.base import Base
from app.shared.utils import utc_now

class IncidentEvidence(Base):
    """
    Represents photo/video evidence uploaded for an emergency incident (Phase 2).
    Types: photo, video
    """
    __tablename__ = "incident_evidence"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4, index=True)
    
    incident_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("incidents.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    
    type: Mapped[str] = mapped_column(String(20), nullable=False, default="photo") # photo, video
    file_path: Mapped[str] = mapped_column(String(512), nullable=False)
    file_url: Mapped[str] = mapped_column(String(1024), nullable=False)
    
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)

    # Relationship
    incident: Mapped["Incident"] = relationship("Incident", back_populates="evidence_items")
