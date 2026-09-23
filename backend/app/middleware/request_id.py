import contextvars
import time
import uuid
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware

# Thread-safe context variable for Request ID propagation
request_id_context = contextvars.ContextVar("request_id", default="-")

class RequestIDMiddleware(BaseHTTPMiddleware):
    """
    Middleware that assigns a unique X-Request-ID to every request.
    Stores the ID in a context variable for logging and propagation.
    Measures processing duration and appends the ID to the response headers.
    """
    async def dispatch(self, request: Request, call_next):
        # Check if client sent X-Request-ID header, otherwise generate new UUID
        request_id = request.headers.get("X-Request-ID") or str(uuid.uuid4())
        
        # Set request_id in contextvars token
        token = request_id_context.set(request_id)
        
        # Record start time for timing execution (Task 4 & 5)
        start_time = time.perf_counter()
        
        try:
            response = await call_next(request)
        except Exception as exc:
            # Let exceptions bubble up to be formatted by exception handlers
            raise exc
        finally:
            # Calculate execution duration
            process_time_ms = (time.perf_counter() - start_time) * 1000.0
            
            # Save duration on request state so logging formatter or exception handlers can read it
            request.state.process_time_ms = process_time_ms
            
            # Reset contextvars token to avoid memory leaks
            request_id_context.reset(token)

        # Attach request ID to response header
        response.headers["X-Request-ID"] = request_id
        return response
