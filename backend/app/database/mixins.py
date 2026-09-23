import uuid
from datetime import datetime
from sqlalchemy import Column, DateTime, Boolean, String
from sqlalchemy.dialects.postgresql import UUID

class UUIDMixin:
    """Mixin that adds a UUID primary key to a model."""
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)

class TimestampMixin:
    """Mixin that adds created_at and updated_at timestamps to a model."""
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

class SoftDeleteMixin:
    """Mixin that adds soft delete capabilities."""
    is_deleted = Column(Boolean, default=False, nullable=False)
    deleted_at = Column(DateTime, nullable=True)
