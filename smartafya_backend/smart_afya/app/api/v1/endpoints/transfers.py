from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user, require_admin
from app.db.session import get_db
from app.models.user import User, UserRole
from app.schemas.care_actions import PatientTransferRequestCreate, PatientTransferRequestOut, PatientTransferRespond
from app.schemas.transfer import TransferLogOut
from app.services.patient_transfer_request_service import PatientTransferRequestService
from app.services.transfer_service import TransferService

router = APIRouter(prefix="/transfers", tags=["Transfers"])


@router.post("/sessions/{session_id}", response_model=PatientTransferRequestOut, status_code=201)
def request_patient_transfer(
    session_id: str,
    data: PatientTransferRequestCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Doctor requests a transfer to another specialist. Patient must accept or decline.
    Reason is required. Admin is notified. Session data and notes are kept; on approval a transfer log is created.
    """
    from fastapi import HTTPException, status

    if current_user.role != UserRole.doctor:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only doctors can request a transfer")
    svc = PatientTransferRequestService(db)
    return svc.create_request(session_id, current_user.id, data)


@router.get("/sessions/{session_id}/pending-request", response_model=PatientTransferRequestOut | None)
def pending_transfer_request_for_session(
    session_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    from fastapi import HTTPException, status

    if current_user.role != UserRole.doctor:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only doctors can view this")
    svc = PatientTransferRequestService(db)
    row = svc.get_pending_for_session(session_id, current_user.id)
    return row


@router.post("/patient-requests/{request_id}/respond", response_model=PatientTransferRequestOut)
def respond_to_transfer_request(
    request_id: str,
    body: PatientTransferRespond,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    from fastapi import HTTPException, status

    if current_user.role != UserRole.client:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only the patient can respond")
    svc = PatientTransferRequestService(db)
    return svc.respond(request_id, current_user.id, body.accept)


@router.get("/sessions/{session_id}/history", response_model=list[TransferLogOut])
def transfer_history(
    session_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get the full transfer history for a session."""
    svc = TransferService(db)
    return svc.get_transfer_history(session_id)


@router.get("/", response_model=list[TransferLogOut], dependencies=[Depends(require_admin)])
def all_transfers(db: Session = Depends(get_db)):
    """Admin: list all transfers across the platform."""
    svc = TransferService(db)
    return svc.list_all()
