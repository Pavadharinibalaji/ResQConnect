from fastapi import Request, status
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
import logging
import math

logger = logging.getLogger("resqconnect")

class ResQConnectException(Exception):
    """Base exception for application errors."""
    def __init__(self, message: str, status_code: int = status.HTTP_400_BAD_REQUEST):
        self.message = message
        self.status_code = status_code
        super().__init__(self.message)

class NotFoundException(ResQConnectException):
    def __init__(self, message: str = "Resource not found"):
        super().__init__(message=message, status_code=status.HTTP_404_NOT_FOUND)

async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Global exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "Internal server error", "success": False},
    )

async def app_exception_handler(request: Request, exc: ResQConnectException):
    logger.warning(f"App exception: {exc.message}")
    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": exc.message, "success": False},
    )

def _json_safe(value):
    """
    Reduces validation error details to plain JSON values. Custom validators put the
    raw exception in ctx["error"], and the JSON parser accepts NaN/Infinity, which
    JSONResponse refuses to encode; either would turn a 422 into a 500.
    """
    if isinstance(value, float):
        return value if math.isfinite(value) else str(value)
    if value is None or isinstance(value, (str, int, bool)):
        return value
    if isinstance(value, dict):
        return {str(key): _json_safe(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [_json_safe(item) for item in value]
    return str(value)

async def validation_exception_handler(request: Request, exc: RequestValidationError):
    errors = _json_safe(exc.errors())
    # Log locations and error types only: submitted values may contain credentials.
    logger.warning("Validation error: %s", [(error.get("loc"), error.get("type")) for error in errors])
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
        content={"detail": errors, "success": False},
    )
