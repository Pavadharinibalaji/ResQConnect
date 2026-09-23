import logging
import sys

def setup_logging():
    logging.basicConfig(
        stream=sys.stdout,
        level=logging.INFO,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    )
    # Ensure uvicorn logs are formatted similarly or leave them as default
    # This acts as a foundation for more complex structured logging (e.g., structlog) later
    logger = logging.getLogger("resqconnect")
    logger.setLevel(logging.INFO)
    return logger

logger = logging.getLogger("resqconnect")
