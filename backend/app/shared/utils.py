import re
from datetime import datetime, timezone


def utc_now() -> datetime:
    """Current time as a timezone-aware UTC datetime.

    Use this instead of datetime.utcnow(): asyncpg interprets naive datetimes bound
    to timestamptz columns in the host's local timezone, which shifts stored values.
    """
    return datetime.now(timezone.utc)

def is_valid_email(email: str) -> bool:
    """Basic email validation utility."""
    pattern = r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$"
    return re.match(pattern, email) is not None
