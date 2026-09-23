import uuid
from datetime import datetime
from typing import List, Optional
from sqlalchemy import String, Boolean, DateTime, ForeignKey, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.models.base import Base
from app.shared.utils import utc_now

class UserRole(Base):
    """
    Association table mapping many-to-many relationships between Users and Roles (Task 1).
    """
    __tablename__ = "user_roles"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
        index=True
    )
    role_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("roles.id", ondelete="CASCADE"),
        primary_key=True,
        index=True
    )


class Role(Base):
    """
    Represents system access roles (Task 1 & 3).
    Citizen, Volunteer, NGO, Police, Fire Department, Ambulance, Admin
    """
    __tablename__ = "roles"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4, index=True)
    name: Mapped[str] = mapped_column(String(50), unique=True, nullable=False, index=True)
    description: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)

    users: Mapped[List["User"]] = relationship(
        secondary="user_roles",
        back_populates="roles"
    )


class User(Base):
    """
    Represents the main system users table (Task 1 & 2).
    """
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4, index=True)
    firebase_uid: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    phone_number: Mapped[str] = mapped_column(String(50), unique=True, index=True, nullable=False)
    full_name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    email: Mapped[Optional[str]] = mapped_column(String(255), unique=True, index=True, nullable=True)
    profile_photo: Mapped[Optional[str]] = mapped_column(String(1024), nullable=True)
    
    # Store standard default role name for quick JWT access (citizen, volunteer, etc.)
    role: Mapped[str] = mapped_column(String(50), default="citizen", nullable=False)
    
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    
    last_login: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now, nullable=False)
    deleted_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    # Relationships
    roles: Mapped[List[Role]] = relationship(
        secondary="user_roles",
        back_populates="users"
    )
    devices: Mapped[List["Device"]] = relationship(
        back_populates="user",
        cascade="all, delete-orphan"
    )
    refresh_tokens: Mapped[List["RefreshToken"]] = relationship(
        back_populates="user",
        cascade="all, delete-orphan"
    )
    audit_logs: Mapped[List["AuditLog"]] = relationship(
        back_populates="user",
        cascade="all, delete"
    )
    profile: Mapped[Optional["Profile"]] = relationship(
        "Profile",
        back_populates="user",
        uselist=False,
        cascade="all, delete-orphan"
    )


class Device(Base):
    """
    Represents user connected devices mapping push-tokens (Task 1).
    """
    __tablename__ = "devices"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4, index=True)
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    device_token: Mapped[str] = mapped_column(String(512), nullable=False)
    device_type: Mapped[str] = mapped_column(String(50), nullable=False)  # ios, android, web
    os_version: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    ip_address: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now, nullable=False)
    deleted_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    user: Mapped[User] = relationship(back_populates="devices")


class RefreshToken(Base):
    """
    Represents hashed OAuth Refresh Tokens mapped to users (Task 1 & 5).
    """
    __tablename__ = "refresh_tokens"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4, index=True)
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    token_hash: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    is_revoked: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)

    user: Mapped[User] = relationship(back_populates="refresh_tokens")


class AuditLog(Base):
    """
    Represents system action trails (Task 1 & 14).
    """
    __tablename__ = "audit_logs"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4, index=True)
    user_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True
    )
    action: Mapped[str] = mapped_column(String(100), nullable=False, index=True)  # login, logout, refresh, update, failed_login
    ip_address: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    user_agent: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    details: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    timestamp: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)

    user: Mapped[Optional[User]] = relationship(back_populates="audit_logs")
