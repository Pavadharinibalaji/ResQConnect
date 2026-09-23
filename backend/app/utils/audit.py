import logging
import uuid
from typing import Optional
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.auth import AuditLog

logger = logging.getLogger("resqconnect.audit")

async def log_audit_event(
    db: AsyncSession,
    user_id: Optional[uuid.UUID],
    action: str,
    ip_address: Optional[str],
    user_agent: Optional[str],
    details: Optional[dict] = None
) -> None:
    """
    Saves an audit event record to the database (Task 14).
    """
    try:
        log_entry = AuditLog(
            user_id=user_id,
            action=action,
            ip_address=ip_address,
            user_agent=user_agent,
            details=details or {}
        )
        db.add(log_entry)
        await db.flush() # flush to write, transaction commit will persist
        logger.info(f"Audit log captured: Action={action} | UserID={user_id} | IP={ip_address}")
    except Exception as e:
        logger.error(f"Failed to write audit log: {e}")
