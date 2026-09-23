import uuid
from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, Field, field_validator, ConfigDict

class ProfileUpdateRequest(BaseModel):
    display_name: str = Field(..., min_length=2, max_length=100, description="User full display name")
    username: Optional[str] = Field(None, min_length=3, max_length=30, description="Unique username handle")
    bio: Optional[str] = Field(None, max_length=255, description="Short bio")
    avatar_url: Optional[str] = Field(None, max_length=1024, description="Profile avatar URL")
    location: Optional[str] = Field(None, max_length=255, description="Primary location")

    emergency_role: str = Field(..., description="Selected emergency role")
    skills: List[str] = Field(default_factory=list, description="Capabilities & skills list")
    response_radius_km: float = Field(10.0, ge=1.0, le=50.0, description="Coverage radius in kilometers")

    emergency_alerts_enabled: bool = Field(True, description="Enable emergency push alerts")
    nearby_alerts_enabled: bool = Field(True, description="Enable nearby incident alerts")
    critical_override_enabled: bool = Field(True, description="Enable critical tone override")
    availability_enabled: bool = Field(True, description="Default availability toggle")
    high_urgency_sound_enabled: bool = Field(True, description="Enable high urgency sound & vibration")

    # emergency_role is authorised in ProfileService.update_profile (app.core.roles):
    # whether a role is allowed depends on the user's admin-granted roles.

    @field_validator('username')
    @classmethod
    def validate_username(cls, v: Optional[str]) -> Optional[str]:
        if v is None or not v.strip():
            return None
        cleaned = v.strip().lstrip('@')
        import re
        if not re.match(r'^[a-zA-Z0-9_]{3,30}$', cleaned):
            raise ValueError("Username must be 3-30 characters long and contain only letters, numbers, and underscores.")
        return cleaned

class ProfileResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    display_name: Optional[str] = None
    username: Optional[str] = None
    bio: Optional[str] = None
    avatar_url: Optional[str] = None
    location: Optional[str] = None

    emergency_role: str
    skills: List[str] = []
    response_radius_km: float

    emergency_alerts_enabled: bool
    nearby_alerts_enabled: bool
    critical_override_enabled: bool
    availability_enabled: bool
    high_urgency_sound_enabled: bool

    profile_completed: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)

class ProfileCompletionStatusResponse(BaseModel):
    user_id: uuid.UUID
    is_completed: bool
    emergency_role: str
