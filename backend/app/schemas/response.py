from typing import Any, Generic, TypeVar, Optional
from pydantic import BaseModel, Field
from app.middleware.request_id import request_id_context
from app.shared.utils import utc_now

T = TypeVar("T")

class StandardResponse(BaseModel, Generic[T]):
    """
    Unified API success response wrapper (Task 2).
    """
    success: bool = True
    message: str = "Request completed successfully."
    data: Optional[T] = None
    timestamp: str = Field(default_factory=lambda: utc_now().isoformat())
    request_id: str = Field(default_factory=lambda: request_id_context.get("-"))

class ErrorResponse(BaseModel):
    """
    Unified API error response wrapper (Task 3).
    """
    success: bool = False
    message: str
    error_code: str
    timestamp: str = Field(default_factory=lambda: utc_now().isoformat())
    request_id: str = Field(default_factory=lambda: request_id_context.get("-"))

# Reusable response helper instantiators
def success_response(data: Any = None, message: str = "Operation successful") -> dict:
    return {
        "success": True,
        "message": message,
        "data": data,
        "timestamp": utc_now().isoformat(),
        "request_id": request_id_context.get("-")
    }

def error_response(message: str, error_code: str) -> dict:
    return {
        "success": False,
        "message": message,
        "error_code": error_code,
        "timestamp": utc_now().isoformat(),
        "request_id": request_id_context.get("-")
    }
