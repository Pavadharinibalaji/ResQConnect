import uuid
from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, Field, ConfigDict

class ResponderUserResponse(BaseModel):
    id: uuid.UUID
    full_name: Optional[str] = None
    phone_number: str
    profile_photo: Optional[str] = None
    role: str = "citizen"
    emergency_role: Optional[str] = "citizen"

    model_config = ConfigDict(from_attributes=True)

class IncidentResponderCreate(BaseModel):
    notes: Optional[str] = Field(None, max_length=512, json_schema_extra={"example": "On my way with first aid kit."})

class IncidentResponderUpdate(BaseModel):
    status: str = Field(..., json_schema_extra={"example": "arrived"}) # responding, arrived, assisting, completed, withdrawn
    notes: Optional[str] = Field(None, max_length=512)

class IncidentResponderResponse(BaseModel):
    id: uuid.UUID
    incident_id: uuid.UUID
    user_id: uuid.UUID
    status: str
    joined_at: datetime
    updated_at: datetime
    completed_at: Optional[datetime] = None
    notes: Optional[str] = None
    user: Optional[ResponderUserResponse] = None

    model_config = ConfigDict(from_attributes=True)

class EvidenceResponse(BaseModel):
    id: uuid.UUID
    incident_id: uuid.UUID
    type: str # photo, video
    file_url: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

class IncidentCreate(BaseModel):
    title: str = Field(..., max_length=255, json_schema_extra={"example": "Structure Fire Reported"})
    description: str = Field(..., json_schema_extra={"example": "Heavy smoke coming from 2nd floor apartment."})
    category: str = Field("medical", json_schema_extra={"example": "fire"}) # fire, medical, flood, crime, rescue
    severity: str = Field("medium", json_schema_extra={"example": "high"}) # low, medium, high, critical
    latitude: float = Field(..., json_schema_extra={"example": 37.7749})
    longitude: float = Field(..., json_schema_extra={"example": -122.4194})
    address: Optional[str] = Field(None, json_schema_extra={"example": "123 Main St, San Francisco, CA"})

class IncidentUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = None
    severity: Optional[str] = None
    status: Optional[str] = None # reported, in_progress, verified, active, resolved, cancelled
    assigned_responder_id: Optional[uuid.UUID] = None

class IncidentResponse(BaseModel):
    id: uuid.UUID
    title: str
    description: str
    category: str
    severity: str
    status: str
    latitude: float
    longitude: float
    address: Optional[str] = None
    distance_km: Optional[float] = None
    reporter_id: Optional[uuid.UUID] = None
    assigned_responder_id: Optional[uuid.UUID] = None
    responder_count: int = 0
    user_responder_status: Optional[str] = None
    responders: Optional[List[IncidentResponderResponse]] = None
    evidence: List[EvidenceResponse] = Field(default_factory=list)
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)

class IncidentListResponse(BaseModel):
    total: int
    incidents: List[IncidentResponse]
