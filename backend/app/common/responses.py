from typing import Any, Generic, Optional, TypeVar
from pydantic import BaseModel

T = TypeVar("T")

class BaseResponse(BaseModel, Generic[T]):
    success: bool
    data: Optional[T] = None
    message: Optional[str] = None
    
def success_response(data: Any = None, message: str = "Success") -> BaseResponse:
    return BaseResponse(success=True, data=data, message=message)

def error_response(message: str, data: Any = None) -> BaseResponse:
    return BaseResponse(success=False, data=data, message=message)
