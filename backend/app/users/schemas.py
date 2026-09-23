from typing import Optional
from datetime import datetime
from uuid import UUID
from pydantic import BaseModel, EmailStr, ConfigDict

class UserBase(BaseModel):
    phone_number: str
    display_name: Optional[str] = None
    email: Optional[EmailStr] = None
    photo_url: Optional[str] = None

class UserCreate(UserBase):
    firebase_uid: str

class UserUpdate(BaseModel):
    display_name: Optional[str] = None
    email: Optional[EmailStr] = None
    photo_url: Optional[str] = None

class UserResponse(UserBase):
    id: UUID
    role: str
    status: str
    last_login: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
