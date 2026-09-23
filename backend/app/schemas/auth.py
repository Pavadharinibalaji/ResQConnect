import uuid
from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, Field, ConfigDict

class FirebaseVerifyRequest(BaseModel):
    id_token: str = Field(..., description="Firebase Auth Phone OTP ID Token")

class TokenRefreshRequest(BaseModel):
    refresh_token: str = Field(..., description="Active session Refresh Token")

class TokenResponseData(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"

class RoleResponse(BaseModel):
    id: uuid.UUID
    name: str
    description: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)

class UserProfileResponse(BaseModel):
    id: uuid.UUID
    firebase_uid: str
    phone_number: str
    full_name: Optional[str] = None
    email: Optional[str] = None
    profile_photo: Optional[str] = None
    role: str
    is_verified: bool
    is_active: bool
    last_login: Optional[datetime] = None
    created_at: datetime
    roles: List[RoleResponse] = []

    model_config = ConfigDict(from_attributes=True)

class ProfileUpdateRequest(BaseModel):
    full_name: str = Field(..., min_length=2, max_length=100)
    profile_photo: Optional[str] = Field(None, max_length=1024)
    role: str = Field(..., description="Requested user role name")
