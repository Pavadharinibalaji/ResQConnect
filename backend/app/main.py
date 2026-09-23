import os
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError
from app.core.config import settings
from app.core.logging import setup_logging
from app.core.firebase_auth import ensure_firebase_configured
from app.core.exceptions import (
    ResQConnectException,
    app_exception_handler,
    global_exception_handler,
    validation_exception_handler,
)
from app.common.middleware import setup_middlewares
from app.health.router import router as health_router

# Setup structured logging
logger = setup_logging()

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Fail fast: a non-development server must not run without verified Firebase auth.
    ensure_firebase_configured()
    os.makedirs("static/uploads/evidence", exist_ok=True)
    logger.info(f"Starting {settings.PROJECT_NAME} v{settings.VERSION} in {settings.ENVIRONMENT} mode")
    yield
    logger.info("Shutting down application")

def create_app() -> FastAPI:
    app = FastAPI(
        title=settings.PROJECT_NAME,
        version=settings.VERSION,
        openapi_url=f"{settings.API_V1_STR}/openapi.json",
        lifespan=lifespan,
    )

    # Middlewares
    setup_middlewares(app)

    # Exception Handlers
    app.add_exception_handler(Exception, global_exception_handler)
    app.add_exception_handler(ResQConnectException, app_exception_handler)
    app.add_exception_handler(RequestValidationError, validation_exception_handler)

    # No public static mount: the only static content was uploaded evidence, which is now
    # served exclusively by the authorised GET /api/v1/incidents/{id}/evidence/{evidence_id}.

    # Routers
    from app.api.router import api_router
    
    app.include_router(api_router, prefix=settings.API_V1_STR)
    
    # Base health router
    app.include_router(health_router)

    return app

app = create_app()
