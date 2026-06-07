from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session as DBSession

from app.core.dependencies import get_current_user, require_admin, require_doctor
from app.db.session import get_db
from app.models.user import User, UserRole
from app.schemas.session import SessionAssign, SessionOut, SessionUpdate
from app.services.session_service import SessionService

router = APIRouter(prefix="/sessions", tags=["Sessions"])


@router.get("/", response_model=list[SessionOut])
def list_sessions(
    current_user: User = Depends(get_current_user),
    db: DBSession = Depends(get_db),
):
    """
    - Doctor: their assigned sessions
    - Client: their sessions
    - Admin: all sessions
    """
    svc = SessionService(db)
    if current_user.role == UserRole.doctor:
        return svc.list_sessions_for_doctor(current_user.id)
    if current_user.role == UserRole.admin:
        return svc.list_all()
    return svc.list_sessions_for_client(current_user.id)


@router.get("/{session_id}", response_model=SessionOut)
def get_session(
    session_id: str,
    current_user: User = Depends(get_current_user),
    db: DBSession = Depends(get_db),
):
    """Get session details."""
    from fastapi import HTTPException, status
    svc = SessionService(db)
    s = svc.get_session(session_id)
    if current_user.role == UserRole.client and s.client_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")
    if current_user.role == UserRole.doctor and s.doctor_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")
    return s


@router.post("/{session_id}/assign", response_model=SessionOut, dependencies=[Depends(require_admin)])
def assign_doctor(
    session_id: str,
    data: SessionAssign,
    db: DBSession = Depends(get_db),
):
    """
    Admin assigns a doctor to a session and sets the schedule.

    **Request body example:**
    ```json
    {
      "doctor_id": "<uuid>",
      "scheduled_at": "2024-07-02T10:00:00Z",
      "meeting_link": null
    }
    ```
    """
    svc = SessionService(db)
    return svc.assign_doctor(session_id, data)


@router.patch("/{session_id}", response_model=SessionOut)
def update_session(
    session_id: str,
    data: SessionUpdate,
    current_user: User = Depends(require_doctor),
    db: DBSession = Depends(get_db),
):
    """Doctor updates session status/notes."""
    svc = SessionService(db)
    return svc.update_session(session_id, data, actor_role=current_user.role.value)


@router.post("/{session_id}/physical/check-in", response_model=SessionOut)
def physical_check_in(
    session_id: str,
    current_user: User = Depends(get_current_user),
    db: DBSession = Depends(get_db),
):
    """Doctor checks in at the physical visit location."""
    from fastapi import HTTPException, status as http_status
    if current_user.role != UserRole.doctor:
        raise HTTPException(status_code=http_status.HTTP_403_FORBIDDEN, detail="Only doctors can check in")
    svc = SessionService(db)
    return svc.physical_check_in(session_id, current_user.id)


@router.post("/{session_id}/physical/check-out", response_model=SessionOut)
def physical_check_out(
    session_id: str,
    current_user: User = Depends(get_current_user),
    db: DBSession = Depends(get_db),
):
    """Doctor checks out after completing the physical visit."""
    from fastapi import HTTPException, status as http_status
    if current_user.role != UserRole.doctor:
        raise HTTPException(status_code=http_status.HTTP_403_FORBIDDEN, detail="Only doctors can check out")
    svc = SessionService(db)
    return svc.physical_check_out(session_id, current_user.id)


@router.post("/{session_id}/unavailable", response_model=dict)
def mark_unavailable(
    session_id: str,
    current_user: User = Depends(get_current_user),
    db: DBSession = Depends(get_db),
):
    """
    Doctor marks themselves unavailable for a session.
    System notifies patient and returns available options.

    **Response example:**
    ```json
    {
      "message": "Marked unavailable. Patient notified.",
      "options": ["transfer_to_another_specialist", "reschedule_session"],
      "session_id": "<uuid>"
    }
    ```
    """
    from fastapi import HTTPException, status as http_status
    if current_user.role != UserRole.doctor:
        raise HTTPException(status_code=http_status.HTTP_403_FORBIDDEN, detail="Only doctors can use this endpoint")
    svc = SessionService(db)
    return svc.doctor_mark_unavailable(session_id, current_user.id)
