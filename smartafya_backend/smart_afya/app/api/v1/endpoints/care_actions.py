from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user, require_admin, require_doctor
from app.db.session import get_db
from app.models.user import User, UserRole
from app.schemas.care_actions import (
    CareActionsOut,
    DoctorUnavailabilityCreate,
    DoctorUnavailabilityResultOut,
    DoctorDashboardSummaryOut,
    ResolveUnavailabilityBody,
)
from app.services.care_actions_service import CareActionsService
from app.services.unavailability_service import UnavailabilityService

router = APIRouter(prefix="/care-actions", tags=["Care actions"])


@router.get("/me", response_model=CareActionsOut)
def my_care_actions(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Patient: pending transfer approvals and unavailability choices."""
    from fastapi import HTTPException, status

    if current_user.role != UserRole.client:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only patients use this endpoint")
    svc = CareActionsService(db)
    return svc.get_client_actions(current_user.id)


@router.post("/unavailability-impacts/{impact_id}/resolve")
def resolve_unavailability_impact(
    impact_id: str,
    body: ResolveUnavailabilityBody,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Patient: transfer to another specialist or reschedule after doctor unavailability."""
    from fastapi import HTTPException, status

    if current_user.role != UserRole.client:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only patients can resolve these actions")
    svc = UnavailabilityService(db)
    svc.resolve_impact(impact_id, current_user.id, body)
    return {"ok": True, "message": "Your choice has been saved. Admin has been notified."}


@router.post("/doctor/unavailability-block", response_model=DoctorUnavailabilityResultOut)
def create_doctor_unavailability_block(
    body: DoctorUnavailabilityCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Doctor: mark a time range unavailable; affected patients receive actionable tasks."""
    from fastapi import HTTPException, status

    if current_user.role != UserRole.doctor:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only doctors can mark unavailability")
    svc = UnavailabilityService(db)
    block, affected = svc.create_block(current_user.id, body)
    return DoctorUnavailabilityResultOut(
        block_id=block.id,
        affected_session_count=len(affected),
        affected_session_ids=affected,
        message=f"Unavailability recorded. {len(affected)} session(s) need patient action. Admin notified.",
    )


@router.get("/doctor/summary", response_model=DoctorDashboardSummaryOut)
def doctor_dashboard_summary(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Doctor: counts for operational follow-ups (transfer requests + unavailability impacts awaiting patient)."""
    from fastapi import HTTPException, status

    from app.models.doctor_unavailability import DoctorUnavailabilityBlock, UnavailabilityImpactStatus, UnavailabilitySessionImpact
    from app.models.patient_transfer_request import PatientTransferRequest, PatientTransferRequestStatus
    from app.models.session import Session as CareSession

    if current_user.role != UserRole.doctor:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only doctors can view this")

    pending_transfer = (
        db.query(PatientTransferRequest)
        .join(CareSession, PatientTransferRequest.session_id == CareSession.id)
        .filter(
            CareSession.doctor_id == current_user.id,
            PatientTransferRequest.status == PatientTransferRequestStatus.requested,
        )
        .count()
    )

    pending_unavailability = (
        db.query(UnavailabilitySessionImpact)
        .join(DoctorUnavailabilityBlock, UnavailabilitySessionImpact.block_id == DoctorUnavailabilityBlock.id)
        .filter(
            DoctorUnavailabilityBlock.doctor_id == current_user.id,
            UnavailabilitySessionImpact.status == UnavailabilityImpactStatus.awaiting_patient,
        )
        .count()
    )

    total = int(pending_transfer) + int(pending_unavailability)
    return DoctorDashboardSummaryOut(
        pending_transfer_requests_count=int(pending_transfer),
        pending_unavailability_impacts_count=int(pending_unavailability),
        total_needing_patient_action=total,
    )


@router.get(
    "/admin/session-management-summary",
    dependencies=[Depends(require_admin)],
)
def admin_session_management_summary(db: Session = Depends(get_db)):
    from app.repositories.patient_transfer_request_repository import PatientTransferRequestRepository
    from app.repositories.session_repository import SessionRepository
    from app.repositories.unavailability_repository import UnavailabilityRepository
    from app.schemas.care_actions import AdminSessionManagementSummaryOut, PatientTransferRequestOut, UnavailabilityImpactAdminOut

    ptr = PatientTransferRequestRepository(db)
    ur = UnavailabilityRepository(db)
    sr = SessionRepository(db)

    pending_tr = [PatientTransferRequestOut.model_validate(r) for r in ptr.list_all_requested()]
    impacts_out: list[UnavailabilityImpactAdminOut] = []
    for imp in ur.list_all_awaiting():
        sess = sr.get_by_id(imp.session_id)
        block = imp.block
        impacts_out.append(
            UnavailabilityImpactAdminOut(
                impact_id=imp.id,
                session_id=imp.session_id,
                client_id=sess.client_id if sess else "",
                doctor_id=block.doctor_id,
                status=imp.status.value,
                block_starts_at=block.starts_at,
                block_ends_at=block.ends_at,
                session_scheduled_at=sess.scheduled_at if sess else None,
            )
        )
    return AdminSessionManagementSummaryOut(
        pending_transfer_requests=pending_tr,
        pending_unavailability_impacts=impacts_out,
    )
