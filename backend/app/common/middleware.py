import time
import uuid
from fastapi import FastAPI, Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.middleware.cors import CORSMiddleware
from starlette.middleware.trustedhost import TrustedHostMiddleware
from starlette.middleware.gzip import GZipMiddleware
from app.core.config import settings
import logging

logger = logging.getLogger("resqconnect")

class RequestIDMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))
        request.state.request_id = request_id
        response = await call_next(request)
        response.headers["X-Request-ID"] = request_id
        return response

class RequestLogMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        start_time = time.time()
        
        # Avoid logging noisy health checks heavily
        is_health_check = request.url.path.startswith("/health")
        if not is_health_check:
            logger.info(f"Request started: {request.method} {request.url.path}")
            
        response = await call_next(request)
        process_time = (time.time() - start_time) * 1000
        
        if not is_health_check:
            logger.info(
                f"Request completed: {request.method} {request.url.path} "
                f"- Status: {response.status_code} - Time: {process_time:.2f}ms"
            )
            
        response.headers["X-Process-Time"] = str(process_time)
        return response

def setup_middlewares(app: FastAPI):
    # Request logging and IDs (Outer layers)
    app.add_middleware(RequestLogMiddleware)
    app.add_middleware(RequestIDMiddleware)
    
    # GZip compression
    app.add_middleware(GZipMiddleware, minimum_size=1000)
    
    # CORS setup
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.CORS_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    
    # Trusted hosts
    if settings.ALLOWED_HOSTS and settings.ALLOWED_HOSTS != ["*"]:
        app.add_middleware(
            TrustedHostMiddleware, allowed_hosts=settings.ALLOWED_HOSTS
        )
