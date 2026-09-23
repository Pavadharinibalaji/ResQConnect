from sqlalchemy import Column, String, DateTime
from app.database.base import Base
from app.database.mixins import UUIDMixin, TimestampMixin, SoftDeleteMixin

class User(Base, UUIDMixin, TimestampMixin, SoftDeleteMixin):
    __tablename__ = "users"

    firebase_uid = Column(String, unique=True, index=True, nullable=False)
    phone_number = Column(String, unique=True, index=True, nullable=False)
    display_name = Column(String, nullable=True)
    email = Column(String, unique=True, index=True, nullable=True)
    photo_url = Column(String, nullable=True)
    role = Column(String, default="user", nullable=False)
    status = Column(String, default="active", nullable=False)
    last_login = Column(DateTime, nullable=True)
