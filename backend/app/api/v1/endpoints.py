import time
from datetime import datetime
from fastapi import APIRouter, Depends, status
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.schemas.response import success_response

router = APIRouter()

# Track boot time for calculating server uptime (Task 6)
BOOT_TIME = time.time()

@router.get("/", status_code=status.HTTP_200_OK)
async def get_root():
    """
    Root API status check. Returns application state description.
    """
    payload = {
        "status": "active",
        "version": "1.0.0",
        "environment": settings.ENVIRONMENT
    }
    return success_response(
        data=payload,
        message="ResQConnect API is running."
    )

@router.get("/version", status_code=status.HTTP_200_OK)
async def get_version():
    """
    Returns API versioning metadata details.
    """
    payload = {
        "version": "1.0.0",
        "api_prefix": settings.API_V1_STR,
        "environment": settings.ENVIRONMENT
    }
    return success_response(
        data=payload,
        message="API version fetched successfully."
    )

@router.get("/health", status_code=status.HTTP_200_OK)
async def get_health(db: AsyncSession = Depends(get_db)):
    """
    Upgraded Health Check system (Task 6).
    Checks database link status, environment, version, and server uptime.
    Returns:
    - 'healthy': Database links and API components function perfectly.
    - 'degraded': Web server is operational but database connection is broken.
    """
    database_connected = False
    try:
        # Perform db validation execution
        result = await db.execute(text("SELECT 1"))
        if result.scalar() == 1:
            database_connected = True
    except Exception:
        # Log database error implicitly or pass
        pass

    uptime_seconds = time.time() - BOOT_TIME

    # Determine health state
    if database_connected:
        health_state = "healthy"
        message = "System health check passed."
    else:
        health_state = "degraded"
        message = "System is degraded. Database connection is down."

    payload = {
        "health_status": health_state,
        "database_connected": database_connected,
        "environment": settings.ENVIRONMENT,
        "app_version": "1.0.0",
        "uptime_seconds": round(uptime_seconds, 2)
    }

    return success_response(
        data=payload,
        message=message
    )
