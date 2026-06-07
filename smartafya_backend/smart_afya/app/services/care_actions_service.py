from datetime import datetime, timedelta

from sqlalchemy.orm import Session as DBSession

from app.models.doctor_unavailability import UnavailabilitySessionImpact
from app.models.patient_transfer_request import PatientTransferRequest
from app.repositories.patient_transfer_request_repository import PatientTransferRequestRepository
from app.repositories.session_repository import SessionRepository
from app.repositories.unavailability_repository import UnavailabilityRepository
from app.repositories.user_repository import UserRepository
from app.schemas.care_actions import (
    CareActionsOut,
    DoctorSuggestionOut,
    PendingTransferActionOut,
    TimeSlotSuggestionOut,
    UnavailabilityImpactActionOut,
)


def _suggest_slots(session_scheduled: datetime | None, block_end: datetime) -> list[datetime]:
    if not session_scheduled:
        return [block_end + timedelta(days=1), block_end + timedelta(days=3), block_end + timedelta(days=7)]
    return [
        session_scheduled + timedelta(days=7),
        session_scheduled + timedelta(days=14),
        block_end + timedelta(days=1),
    ][:3]


class CareActionsService:
    def __init__(self, db: DBSession):
        self.db = db
        self.transfer_req_repo = PatientTransferRequestRepository(db)
        self.unavail_repo = UnavailabilityRepository(db)
        self.user_repo = UserRepository(db)
        self.session_repo = SessionRepository(db)

    def _transfer_row_to_action(self, r: PatientTransferRequest) -> PendingTransferActionOut:
        fd = self.user_repo.get_by_id(r.from_doctor_id)
        td = self.user_repo.get_by_id(r.to_doctor_id)
        return PendingTransferActionOut(
            id=r.id,
            session_id=r.session_id,
            from_doctor_name=fd.full_name if fd else "Specialist",
            to_doctor_name=td.full_name if td else "Specialist",
            reason=r.reason,
            created_at=r.created_at,
        )

    def _impact_to_action(self, imp: UnavailabilitySessionImpact) -> UnavailabilityImpactActionOut:
        session = self.session_repo.get_by_id(imp.session_id)
        block = imp.block
        doctor = self.user_repo.get_by_id(block.doctor_id)

        spec = doctor.specialist_type if doctor else None
        doctors = self.user_repo.get_doctors(
            available_only=True,
            specialist_type=spec,
            exclude_doctor_id=block.doctor_id,
        )
        suggested = [
            DoctorSuggestionOut(
                id=d.id,
                full_name=d.full_name,
                specialist_type=d.specialist_type.value if d.specialist_type else None,
            )
            for d in doctors[:8]
        ]
        slots = _suggest_slots(session.scheduled_at if session else None, block.ends_at)
        slot_out = [TimeSlotSuggestionOut(scheduled_at=s) for s in slots]

        return UnavailabilityImpactActionOut(
            id=imp.id,
            session_id=imp.session_id,
            block_starts_at=block.starts_at,
            block_ends_at=block.ends_at,
            doctor_name=doctor.full_name if doctor else "Your specialist",
            session_scheduled_at=session.scheduled_at if session else None,
            message=(
                f"{doctor.full_name if doctor else 'Your specialist'} is unavailable during this period. "
                "You can transfer to another specialist or pick a new time."
            ),
            suggested_doctors=suggested,
            suggested_slots=slot_out,
        )

    def get_client_actions(self, client_id: str) -> CareActionsOut:
        pending_t = [self._transfer_row_to_action(r) for r in self.transfer_req_repo.list_pending_for_client(client_id)]
        impacts = [self._impact_to_action(i) for i in self.unavail_repo.list_awaiting_for_client(client_id)]
        return CareActionsOut(pending_transfers=pending_t, unavailability_impacts=impacts)
