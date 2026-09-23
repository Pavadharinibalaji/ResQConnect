from pydantic import BaseModel

class HealthResponse(BaseModel):
    status: str
    version: str
    environment: str

class DatabaseHealthResponse(BaseModel):
    status: str
    database_connected: bool
