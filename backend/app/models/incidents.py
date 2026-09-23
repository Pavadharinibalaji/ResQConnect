import uuid
from datetime import datetime
from typing import Optional
from sqlalchemy import String, Text, Float, DateTime, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from geoalchemy2 import Geometry
from app.models.base import Base
from app.shared.utils import utc_now

class Incident(Base):
    """
    Represents emergency incident events (Task 6 & Emergency Feed Engine).
    Categories: fire, medical, flood, crime, rescue
    Severities: low, medium, high, critical
    Statuses: reported, in_progress, resolved, cancelled
    """
    __tablename__ = "incidents"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4, index=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    category: Mapped[str] = mapped_column(String(50), nullable=False, index=True, default="medical")
    severity: Mapped[str] = mapped_column(String(50), nullable=False, index=True, default="medium")
    status: Mapped[str] = mapped_column(String(50), nullable=False, index=True, default="reported")

    latitude: Mapped[float] = mapped_column(Float, nullable=False)
    longitude: Mapped[float] = mapped_column(Float, nullable=False)
    
    # PostGIS Location column
    location = mapped_column(Geometry('POINT', srid=4326), nullable=True)
    
    address: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)

    reporter_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True
    )
    assigned_responder_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True
    )

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now, nullable=False)

    reporter: Mapped[Optional["User"]] = relationship("User", foreign_keys=[reporter_id])
    assigned_responder: Mapped[Optional["User"]] = relationship("User", foreign_keys=[assigned_responder_id])
    
    # 1-to-many relation to reports
    reports: Mapped[list["IncidentReport"]] = relationship(
        "IncidentReport", back_populates="incident", cascade="all, delete-orphan"
    )
    
    # 1-to-many relation to responders
    responders: Mapped[list["IncidentResponder"]] = relationship(
        "IncidentResponder", back_populates="incident", cascade="all, delete-orphan"
    )
    
    # 1-to-many relation to evidence
    evidence_items: Mapped[list["IncidentEvidence"]] = relationship(
        "IncidentEvidence", back_populates="incident", cascade="all, delete-orphan"
    )

class IncidentReport(Base):
    """
    Represents an individual report of an emergency incident.
    Future-proofs for RIDDA incident fusion.
    """
    __tablename__ = "incident_reports"
    
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4, index=True)
    
    incident_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("incidents.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    reporter_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    
    description: Mapped[str] = mapped_column(Text, nullable=False)
    
    # Could also add latitude/longitude here if reports differ, but for Phase 4 we just link it to the incident
    
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)
    
    incident: Mapped["Incident"] = relationship("Incident", back_populates="reports")
    reporter: Mapped["User"] = relationship("User", foreign_keys=[reporter_id])
