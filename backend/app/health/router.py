from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
import logging

from app.core.config import settings
from app.dependencies.database import get_db
from app.health.schemas import HealthResponse, DatabaseHealthResponse
from app.common.responses import BaseResponse, success_response, error_response

logger = logging.getLogger("resqconnect")

router = APIRouter(prefix="/health", tags=["Health"])

@router.get("", response_model=BaseResponse[HealthResponse])
async def health_check():
    """Basic health check endpoint."""
    return success_response(
        data=HealthResponse(
            status="ok",
            version=settings.VERSION,
            environment=settings.ENVIRONMENT
        ),
        message="Service is healthy"
    )

@router.get("/database", response_model=BaseResponse[DatabaseHealthResponse])
async def database_health_check(db: AsyncSession = Depends(get_db)):
    """Health check for database connection."""
    try:
        # Execute a simple query to verify connection
        await db.execute(text("SELECT 1"))
        return success_response(
            data=DatabaseHealthResponse(status="ok", database_connected=True),
            message="Database connection successful"
        )
    except Exception as e:
        logger.error(f"Database health check failed: {e}")
        return error_response(
            message="Database connection failed",
            data=DatabaseHealthResponse(status="error", database_connected=False)
        )

@router.get("/ready", response_model=BaseResponse[str])
async def readiness_check():
    """
    Readiness check endpoint. 
    Can be expanded to check other dependencies like Redis, external APIs, etc.
    """
    return success_response(data="ready", message="Service is ready to accept traffic")
