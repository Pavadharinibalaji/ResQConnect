import uuid
from typing import List, Optional
from fastapi import HTTPException, status
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.auth import User
from app.models.incidents import Incident
from app.models.responders import IncidentResponder
from app.models.profiles import Profile
from app.schemas.incidents import IncidentResponderResponse, ResponderUserResponse
from app.shared.utils import utc_now

VALID_RESPONDER_STATUSES = {"responding", "arrived", "assisting", "completed", "withdrawn"}
VALID_INCIDENT_STATUSES = {"reported", "verified", "active", "resolved", "cancelled"}

ALLOWED_INCIDENT_TRANSITIONS = {
    "reported": {"verified", "active", "cancelled"},
    "verified": {"active", "cancelled"},
    "active": {"resolved", "cancelled"},
    "resolved": set(),
    "cancelled": set(),
}

def validate_incident_status_transition(current_status: str, new_status: str) -> None:
    current = current_status.lower()
    target = new_status.lower()

    if current == target:
        return

    if current not in ALLOWED_INCIDENT_TRANSITIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unknown current incident status '{current_status}'."
        )

    allowed = ALLOWED_INCIDENT_TRANSITIONS[current]
    if target not in allowed:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid incident status transition from '{current_status}' to '{new_status}'. Allowed transitions: {sorted(list(allowed))}."
        )

class ResponderService:

    @staticmethod
    async def join_incident(
        db: AsyncSession,
        incident_id: uuid.UUID,
        current_user: User,
        notes: Optional[str] = None
    ) -> IncidentResponder:
        # Check incident exists
        stmt = select(Incident).where(Incident.id == incident_id)
        result = await db.execute(stmt)
        incident = result.scalars().first()

        if not incident:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Incident not found."
            )

        if incident.status in {"resolved", "cancelled"}:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Cannot respond to an incident that is already {incident.status}."
            )

        # Check existing responder record
        resp_stmt = select(IncidentResponder).where(
            IncidentResponder.incident_id == incident_id,
            IncidentResponder.user_id == current_user.id
        )
        resp_result = await db.execute(resp_stmt)
        existing = resp_result.scalars().first()

        if existing:
            if existing.status != "withdrawn":
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="You are already responding to this incident."
                )
            # Re-activate response if previously withdrawn
            existing.status = "responding"
            existing.notes = notes or existing.notes
            existing.updated_at = utc_now()
            existing.completed_at = None
            responder = existing
        else:
            responder = IncidentResponder(
                incident_id=incident_id,
                user_id=current_user.id,
                status="responding",
                notes=notes
            )
            db.add(responder)

        # Automatically transition incident from 'reported' to 'active'
        if incident.status == "reported":
            incident.status = "active"

        await db.flush()
        return responder

    @staticmethod
    async def update_responder_status(
        db: AsyncSession,
        incident_id: uuid.UUID,
        current_user: User,
        new_status: str,
        notes: Optional[str] = None
    ) -> IncidentResponder:
        target_status = new_status.lower()
        if target_status not in VALID_RESPONDER_STATUSES:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Invalid responder status '{new_status}'. Allowed values: {sorted(list(VALID_RESPONDER_STATUSES))}."
            )

        resp_stmt = select(IncidentResponder).where(
            IncidentResponder.incident_id == incident_id,
            IncidentResponder.user_id == current_user.id
        )
        resp_result = await db.execute(resp_stmt)
        responder = resp_result.scalars().first()

        if not responder:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="You have not joined this incident as a responder."
            )

        responder.status = target_status
        if notes is not None:
            responder.notes = notes
        responder.updated_at = utc_now()

        if target_status == "completed":
            responder.completed_at = utc_now()

        await db.flush()
        return responder

    @staticmethod
    async def withdraw_response(
        db: AsyncSession,
        incident_id: uuid.UUID,
        current_user: User
    ) -> IncidentResponder:
        return await ResponderService.update_responder_status(
            db=db,
            incident_id=incident_id,
            current_user=current_user,
            new_status="withdrawn"
        )

    @staticmethod
    async def get_incident_responders(
        db: AsyncSession,
        incident_id: uuid.UUID
    ) -> List[IncidentResponderResponse]:
        stmt = (
            select(IncidentResponder)
            .options(
                selectinload(IncidentResponder.user).selectinload(User.profile)
            )
            .where(
                IncidentResponder.incident_id == incident_id,
                IncidentResponder.status != "withdrawn"
            )
            .order_by(IncidentResponder.joined_at.asc())
        )
        result = await db.execute(stmt)
        responders = result.scalars().all()

        response_list = []
        for r in responders:
            user_data = None
            if r.user:
                prof = r.user.profile
                user_data = ResponderUserResponse(
                    id=r.user.id,
                    full_name=r.user.full_name or (prof.display_name if prof else "Responder"),
                    phone_number=r.user.phone_number,
                    profile_photo=r.user.profile_photo or (prof.avatar_url if prof else None),
                    role=r.user.role,
                    emergency_role=prof.emergency_role if prof else "citizen"
                )
            res_dto = IncidentResponderResponse(
                id=r.id,
                incident_id=r.incident_id,
                user_id=r.user_id,
                status=r.status,
                joined_at=r.joined_at,
                updated_at=r.updated_at,
                completed_at=r.completed_at,
                notes=r.notes,
                user=user_data
            )
            response_list.append(res_dto)

        return response_list

    @staticmethod
    async def get_my_responder_status(
        db: AsyncSession,
        incident_id: uuid.UUID,
        current_user: User
    ) -> Optional[IncidentResponderResponse]:
        stmt = (
            select(IncidentResponder)
            .options(
                selectinload(IncidentResponder.user).selectinload(User.profile)
            )
            .where(
                IncidentResponder.incident_id == incident_id,
                IncidentResponder.user_id == current_user.id
            )
        )
        result = await db.execute(stmt)
        r = result.scalars().first()

        if not r:
            return None

        user_data = None
        if r.user:
            prof = r.user.profile
            user_data = ResponderUserResponse(
                id=r.user.id,
                full_name=r.user.full_name or (prof.display_name if prof else "Responder"),
                phone_number=r.user.phone_number,
                profile_photo=r.user.profile_photo or (prof.avatar_url if prof else None),
                role=r.user.role,
                emergency_role=prof.emergency_role if prof else "citizen"
            )

        return IncidentResponderResponse(
            id=r.id,
            incident_id=r.incident_id,
            user_id=r.user_id,
            status=r.status,
            joined_at=r.joined_at,
            updated_at=r.updated_at,
            completed_at=r.completed_at,
            notes=r.notes,
            user=user_data
        )
