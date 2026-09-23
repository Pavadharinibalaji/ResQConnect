import uuid
import os
import logging
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File, status
from fastapi.responses import FileResponse
from sqlalchemy import select, func, inspect as sa_inspect
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.core.roles import is_admin
from app.middleware.rbac import get_current_user, get_optional_current_user
from app.models.auth import User
from app.models.incidents import Incident
from app.models.responders import IncidentResponder
from app.models.evidence import IncidentEvidence
from app.schemas.incidents import (
    IncidentCreate,
    IncidentUpdate,
    IncidentResponse,
    EvidenceResponse,
    IncidentResponderCreate,
    IncidentResponderUpdate,
)
from app.schemas.response import success_response
from app.services.responder_service import (
    ResponderService,
    validate_incident_status_transition,
)
from app.utils.evidence import (
    MAX_UPLOAD_BYTES,
    STORED_MEDIA_TYPES,
    EvidenceValidationError,
    check_declared_metadata,
    client_extension,
    normalize_content_type,
    normalize_evidence_type,
    validate_evidence_content,
)
from app.utils.geo import haversine_distance

logger = logging.getLogger("resqconnect.api.incidents")
router = APIRouter(prefix="/incidents", tags=["Emergency Incidents & Responders"])

# Evidence storage (relative to the working directory). Not web-exposed: files are only
# served through GET /incidents/{incident_id}/evidence/{evidence_id}.
EVIDENCE_UPLOAD_DIR = os.path.join("static", "uploads", "evidence")
EVIDENCE_RESPONSE_HEADERS = {
    "X-Content-Type-Options": "nosniff",
    "Cache-Control": "private, no-store",
    "Content-Security-Policy": "default-src 'none'; sandbox",
}

def _is_admin(user: User) -> bool:
    # Single admin definition (app.core.roles), shared with RoleChecker and the admin API.
    return is_admin(user)

def _can_manage_incident(user: User, incident: Incident) -> bool:
    """Only the reporter or an admin may modify an incident. User-selectable roles grant nothing."""
    is_reporter = incident.reporter_id is not None and incident.reporter_id == user.id
    return is_reporter or _is_admin(user)

async def _can_access_incident_evidence(db: AsyncSession, user: User, incident: Incident) -> bool:
    """
    Evidence upload/view: reporter, admin, or a user with a non-withdrawn IncidentResponder
    row for this incident. Profile roles alone never grant access.
    """
    if _can_manage_incident(user, incident):
        return True
    participation = await db.execute(
        select(IncidentResponder.id).where(
            IncidentResponder.incident_id == incident.id,
            IncidentResponder.user_id == user.id,
            IncidentResponder.status != "withdrawn",
        )
    )
    return participation.first() is not None

def _evidence_api_url(incident_id: uuid.UUID, evidence_id: uuid.UUID) -> str:
    return f"{settings.API_V1_STR}/incidents/{incident_id}/evidence/{evidence_id}"

def _evidence_payload(evidence: IncidentEvidence) -> dict:
    # Always point clients at the authorised endpoint (also for rows stored with a legacy URL).
    data = EvidenceResponse.model_validate(evidence).model_dump()
    data["file_url"] = _evidence_api_url(evidence.incident_id, evidence.id)
    return data

async def build_incident_response_dict(
    db: AsyncSession,
    incident: Incident,
    current_user: Optional[User] = None
) -> dict:
    # Validate from column values only. Passing the ORM object would make Pydantic
    # read the lazy `responders` relationship (an implicit async lazy load, which
    # raises MissingGreenlet); relationship-derived fields are filled in below/by callers.
    column_values = {
        attr.key: getattr(incident, attr.key)
        for attr in sa_inspect(incident).mapper.column_attrs
    }
    data = IncidentResponse.model_validate(column_values).model_dump()

    # Query active responder count
    count_stmt = select(func.count()).where(
        IncidentResponder.incident_id == incident.id,
        IncidentResponder.status != "withdrawn"
    )
    count_res = await db.execute(count_stmt)
    data["responder_count"] = count_res.scalar() or 0

    # Query current user's responder status if authenticated
    if current_user:
        user_resp_stmt = select(IncidentResponder.status).where(
            IncidentResponder.incident_id == incident.id,
            IncidentResponder.user_id == current_user.id
        )
        user_resp_res = await db.execute(user_resp_stmt)
        data["user_responder_status"] = user_resp_res.scalar_one_or_none()
    else:
        data["user_responder_status"] = None

    # Query attached evidence
    ev_stmt = select(IncidentEvidence).where(IncidentEvidence.incident_id == incident.id).order_by(IncidentEvidence.created_at.asc())
    ev_res = await db.execute(ev_stmt)
    evidence_list = ev_res.scalars().all()
    data["evidence"] = [_evidence_payload(e) for e in evidence_list]

    return data

@router.post("", status_code=status.HTTP_201_CREATED)
async def create_incident(
    payload: IncidentCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Creates a new emergency incident report (Authenticated User).
    """
    # Safely set reporter_id if user exists in database
    reporter_id = None
    if current_user:
        user_in_db = await db.get(User, current_user.id)
        if user_in_db:
            reporter_id = current_user.id

    incident = Incident(
        title=payload.title,
        description=payload.description,
        category=payload.category.lower(),
        severity=payload.severity.lower(),
        status="reported",
        latitude=payload.latitude,
        longitude=payload.longitude,
        location=f"SRID=4326;POINT({payload.longitude} {payload.latitude})",
        address=payload.address,
        reporter_id=reporter_id
    )
    db.add(incident)
    await db.flush()

    response_data = await build_incident_response_dict(db, incident, current_user)
    return success_response(
        data=response_data,
        message="Emergency incident reported successfully."
    )

@router.get("", status_code=status.HTTP_200_OK)
async def get_incidents_feed(
    category: Optional[str] = Query(None, description="Filter by category"),
    status_filter: Optional[str] = Query(None, alias="status", description="Filter by status"),
    severity: Optional[str] = Query(None, description="Filter by severity"),
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_user: Optional[User] = Depends(get_optional_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Returns live list of emergency incidents for responder feed.
    """
    query = select(Incident)

    if category:
        query = query.where(Incident.category == category.lower())
    if status_filter:
        query = query.where(Incident.status == status_filter.lower())
    if severity:
        query = query.where(Incident.severity == severity.lower())

    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0

    query = query.order_by(Incident.created_at.desc()).offset(offset).limit(limit)
    result = await db.execute(query)
    incidents = result.scalars().all()

    incidents_data = [
        await build_incident_response_dict(db, item, current_user)
        for item in incidents
    ]

    return success_response(
        data={
            "total": total,
            "incidents": incidents_data
        },
        message="Emergency feed incidents retrieved successfully."
    )

@router.get("/nearby", status_code=status.HTTP_200_OK)
async def get_nearby_incidents(
    latitude: float = Query(..., ge=-90.0, le=90.0, description="User current latitude"),
    longitude: float = Query(..., ge=-180.0, le=180.0, description="User current longitude"),
    radius_km: float = Query(10.0, gt=0, le=500.0, description="Search radius in kilometers"),
    category: Optional[str] = Query(None, description="Filter by category"),
    severity: Optional[str] = Query(None, description="Filter by severity"),
    status_filter: Optional[str] = Query(None, alias="status", description="Filter by status"),
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_user: Optional[User] = Depends(get_optional_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Returns emergency incidents ordered by distance from given GPS coordinates within radius_km.
    """
    query = select(Incident)

    if category:
        query = query.where(Incident.category == category.lower())
    if status_filter:
        query = query.where(Incident.status == status_filter.lower())
    if severity:
        query = query.where(Incident.severity == severity.lower())

    result = await db.execute(query)
    all_incidents = result.scalars().all()

    nearby_list = []
    for inc in all_incidents:
        dist = haversine_distance(latitude, longitude, inc.latitude, inc.longitude)
        if dist <= radius_km:
            resp_dict = await build_incident_response_dict(db, inc, current_user)
            resp_dict["distance_km"] = dist
            nearby_list.append((dist, resp_dict))

    nearby_list.sort(key=lambda x: x[0])

    total = len(nearby_list)
    paginated = [item[1] for item in nearby_list[offset : offset + limit]]

    return success_response(
        data={
            "total": total,
            "radius_km": radius_km,
            "incidents": paginated
        },
        message=f"Retrieved {len(paginated)} nearby emergency incidents."
    )

@router.get("/{incident_id}", status_code=status.HTTP_200_OK)
async def get_incident_detail(
    incident_id: uuid.UUID,
    current_user: Optional[User] = Depends(get_optional_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Returns single incident detail by ID with responders and evidence.
    """
    stmt = select(Incident).where(Incident.id == incident_id)
    result = await db.execute(stmt)
    incident = result.scalars().first()

    if not incident:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Incident report not found."
        )

    response_data = await build_incident_response_dict(db, incident, current_user)
    
    # Attach responders list
    responders_dto = await ResponderService.get_incident_responders(db, incident_id)
    response_data["responders"] = [r.model_dump() for r in responders_dto]

    return success_response(
        data=response_data,
        message="Incident details retrieved successfully."
    )

@router.post("/{incident_id}/evidence", status_code=status.HTTP_201_CREATED)
async def upload_incident_evidence(
    incident_id: uuid.UUID,
    file: UploadFile = File(...),
    type: str = Query("photo", description="Evidence type: photo or video"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Uploads photo or video evidence for an incident (reporter, participating responder or admin).
    """
    stmt = select(Incident).where(Incident.id == incident_id)
    result = await db.execute(stmt)
    incident = result.scalars().first()

    if not incident:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Incident report not found."
        )

    # Authorise before validating or reading the upload.
    if not await _can_access_incident_evidence(db, current_user, incident):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not allowed to access evidence for this incident."
        )

    # Validate everything before anything is written to disk.
    try:
        type_clean = normalize_evidence_type(type)
        extension = client_extension(file.filename)
        content_type = normalize_content_type(file.content_type)
        check_declared_metadata(type_clean, extension, content_type)
        # Read at most limit + 1 bytes so an oversized upload is detected without buffering it all.
        data = await file.read(MAX_UPLOAD_BYTES[type_clean] + 1)
        stored_ext = validate_evidence_content(type_clean, extension, content_type, data)
    except EvidenceValidationError as exc:
        raise HTTPException(
            status_code=status.HTTP_413_CONTENT_TOO_LARGE if exc.too_large else status.HTTP_400_BAD_REQUEST,
            detail=exc.message,
        )

    # Server-generated name only (the evidence id); the client filename never influences the path.
    evidence_id = uuid.uuid4()
    unique_filename = f"{evidence_id}{stored_ext}"
    os.makedirs(EVIDENCE_UPLOAD_DIR, exist_ok=True)

    dest_path = os.path.join(EVIDENCE_UPLOAD_DIR, unique_filename)
    with open(dest_path, "xb") as buffer:
        buffer.write(data)

    evidence = IncidentEvidence(
        id=evidence_id,
        incident_id=incident_id,
        type=type_clean,
        file_path=dest_path,
        file_url=_evidence_api_url(incident_id, evidence_id)
    )
    db.add(evidence)
    try:
        await db.flush()
    except Exception:
        os.remove(dest_path)
        raise

    return success_response(
        data=_evidence_payload(evidence),
        message="Emergency evidence uploaded successfully."
    )

@router.get("/{incident_id}/evidence/{evidence_id}", status_code=status.HTTP_200_OK)
async def get_incident_evidence_file(
    incident_id: uuid.UUID,
    evidence_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Streams one evidence file (reporter, participating responder or admin only).
    """
    incident = (await db.execute(select(Incident).where(Incident.id == incident_id))).scalars().first()
    if not incident:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Incident report not found."
        )

    # Authorise before looking the evidence up, so unrelated users cannot probe evidence ids.
    if not await _can_access_incident_evidence(db, current_user, incident):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not allowed to access evidence for this incident."
        )

    evidence = (await db.execute(
        select(IncidentEvidence).where(
            IncidentEvidence.id == evidence_id,
            IncidentEvidence.incident_id == incident_id,
        )
    )).scalars().first()
    not_found = HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Evidence not found.")
    if not evidence:
        raise not_found

    # Only a bare file name inside the evidence directory is ever resolved, whatever is stored.
    filename = os.path.basename(evidence.file_path.replace("\\", "/"))
    media_type = STORED_MEDIA_TYPES.get(os.path.splitext(filename)[1].lower())
    path = os.path.join(os.path.realpath(EVIDENCE_UPLOAD_DIR), filename)
    if media_type is None or not os.path.isfile(path):
        logger.warning("Evidence %s has no readable stored file.", evidence.id)
        raise not_found

    return FileResponse(path, media_type=media_type, headers=EVIDENCE_RESPONSE_HEADERS)

@router.patch("/{incident_id}/status", status_code=status.HTTP_200_OK)
async def update_incident_status(
    incident_id: uuid.UUID,
    payload: IncidentUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Updates incident status with controlled state machine transition validation.
    """
    stmt = select(Incident).where(Incident.id == incident_id)
    result = await db.execute(stmt)
    incident = result.scalars().first()

    if not incident:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Incident report not found."
        )

    if not _can_manage_incident(current_user, incident):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not allowed to update this incident."
        )

    # Checked before any change so an unknown user is a 404, not a foreign-key 500 at flush.
    if payload.assigned_responder_id:
        assignee_id = (await db.execute(
            select(User.id).where(User.id == payload.assigned_responder_id)
        )).scalar_one_or_none()
        if assignee_id is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Assigned responder not found."
            )

    if payload.status:
        validate_incident_status_transition(incident.status, payload.status)
        incident.status = payload.status.lower()

    if payload.title:
        incident.title = payload.title
    if payload.description:
        incident.description = payload.description
    if payload.assigned_responder_id:
        incident.assigned_responder_id = payload.assigned_responder_id

    await db.flush()

    response_data = await build_incident_response_dict(db, incident, current_user)
    return success_response(
        data=response_data,
        message="Incident status updated successfully."
    )

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# RESPONDER ENDPOINTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@router.post("/{incident_id}/respond", status_code=status.HTTP_200_OK)
async def respond_to_incident(
    incident_id: uuid.UUID,
    payload: Optional[IncidentResponderCreate] = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Joins an emergency incident as a responder (Authenticated User).
    """
    notes = payload.notes if payload else None
    await ResponderService.join_incident(db, incident_id, current_user, notes=notes)

    stmt = select(Incident).where(Incident.id == incident_id)
    result = await db.execute(stmt)
    incident = result.scalars().first()

    incident_dict = await build_incident_response_dict(db, incident, current_user)
    responders_dto = await ResponderService.get_incident_responders(db, incident_id)
    incident_dict["responders"] = [r.model_dump() for r in responders_dto]

    return success_response(
        data=incident_dict,
        message="You are now responding to this emergency incident!"
    )

@router.delete("/{incident_id}/respond", status_code=status.HTTP_200_OK)
async def withdraw_responder_status(
    incident_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Withdraws current user from responding to an incident.
    """
    await ResponderService.withdraw_response(db, incident_id, current_user)

    stmt = select(Incident).where(Incident.id == incident_id)
    result = await db.execute(stmt)
    incident = result.scalars().first()

    incident_dict = await build_incident_response_dict(db, incident, current_user)
    responders_dto = await ResponderService.get_incident_responders(db, incident_id)
    incident_dict["responders"] = [r.model_dump() for r in responders_dto]

    return success_response(
        data=incident_dict,
        message="You have withdrawn your response for this emergency."
    )

@router.get("/{incident_id}/responders", status_code=status.HTTP_200_OK)
async def get_incident_responders(
    incident_id: uuid.UUID,
    db: AsyncSession = Depends(get_db)
):
    """
    Lists active responders for an emergency incident.
    """
    responders_dto = await ResponderService.get_incident_responders(db, incident_id)
    return success_response(
        data=[r.model_dump() for r in responders_dto],
        message="Responders list retrieved successfully."
    )

@router.patch("/{incident_id}/responders/me/status", status_code=status.HTTP_200_OK)
async def update_my_responder_status(
    incident_id: uuid.UUID,
    payload: IncidentResponderUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Updates current user's responder status.
    """
    await ResponderService.update_responder_status(
        db, incident_id, current_user, payload.status, payload.notes
    )

    stmt = select(Incident).where(Incident.id == incident_id)
    result = await db.execute(stmt)
    incident = result.scalars().first()

    incident_dict = await build_incident_response_dict(db, incident, current_user)
    responders_dto = await ResponderService.get_incident_responders(db, incident_id)
    incident_dict["responders"] = [r.model_dump() for r in responders_dto]

    return success_response(
        data=incident_dict,
        message=f"Responder status updated to '{payload.status}'."
    )

@router.get("/{incident_id}/responders/me", status_code=status.HTTP_200_OK)
async def get_my_responder_status(
    incident_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Gets current user's responder status for an incident.
    """
    responder_dto = await ResponderService.get_my_responder_status(db, incident_id, current_user)
    return success_response(
        data=responder_dto.model_dump() if responder_dto else None,
        message="Current user responder status retrieved."
    )
