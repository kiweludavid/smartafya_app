from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, status
from sqlalchemy.orm import Session as DBSession

from app.core.logging import logger
from app.models.booking import Booking
from app.models.doctor_unavailability import (
    DoctorUnavailabilityBlock,
    UnavailabilityImpactStatus,
    UnavailabilityResolution,
    UnavailabilitySessionImpact,
)
from app.models.session import Session as CareSession
from app.models.session import SessionStatus
from app.models.user import SpecialistType, UserRole
from app.repositories.session_repository import SessionRepository
from app.repositories.unavailability_repository import UnavailabilityRepository
from app.repositories.user_repository import UserRepository
from app.schemas.care_actions import DoctorUnavailabilityCreate, ResolveUnavailabilityBody
from app.services.care_event_notifier import CareEventNotifier


def _session_window_end(scheduled_at: datetime, duration_minutes: int) -> datetime:
    return scheduled_at + timedelta(minutes=max(1, duration_minutes))


def _intervals_overlap(a_start: datetime, a_end: datetime, b_start: datetime, b_end: datetime) -> bool:
    return a_start < b_end and a_end > b_start


class UnavailabilityService:
    def __init__(self, db: DBSession):
        self.db = db
        self.repo = UnavailabilityRepository(db)
        self.session_repo = SessionRepository(db)
        self.user_repo = UserRepository(db)
        self.notifier = CareEventNotifier(db)

    def create_block(self, doctor_id: str, data: DoctorUnavailabilityCreate) -> tuple[DoctorUnavailabilityBlock, list[str]]:
        if data.ends_at <= data.starts_at:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="End time must be after start time")

        rows = (
            self.db.query(CareSession, Booking)
            .join(Booking, CareSession.booking_id == Booking.id)
            .filter(CareSession.doctor_id == doctor_id)
            .filter(
                CareSession.status.in_(
                    [SessionStatus.requested, SessionStatus.pending, SessionStatus.scheduled],
                )
            )
            .filter(CareSession.scheduled_at.isnot(None))
            .all()
        )

        impacts: list[UnavailabilitySessionImpact] = []
        affected_ids: list[str] = []

        for session, booking in rows:
            assert session.scheduled_at is not None
            sess_end = _session_window_end(session.scheduled_at, booking.duration_minutes)
            if not _intervals_overlap(session.scheduled_at, sess_end, data.starts_at, data.ends_at):
                continue

            existing = (
                self.db.query(UnavailabilitySessionImpact)
                .filter(
                    UnavailabilitySessionImpact.session_id == session.id,
                    UnavailabilitySessionImpact.status == UnavailabilityImpactStatus.awaiting_patient,
                )
                .first()
            )
            if existing:
                continue

            impacts.append(UnavailabilitySessionImpact(session_id=session.id))
            affected_ids.append(session.id)

        block = DoctorUnavailabilityBlock(doctor_id=doctor_id, starts_at=data.starts_at, ends_at=data.ends_at)
        block = self.repo.save_block_with_impacts(block, impacts)

        # Automatic messages: admin thread + each affected session chat.
        doctor = self.user_repo.get_by_id(doctor_id)
        doctor_name = (doctor.full_name if doctor else "Specialist").strip() or "Specialist"
        for session_id in affected_ids:
            sess = self.session_repo.get_by_id(session_id)
            if not sess:
                continue
            self.notifier.notify_admin(
                client_id=sess.client_id,
                body=(
                    f"[Specialist unavailable] session={session_id} doctor={doctor_name} "
                    f"window={data.starts_at.isoformat()}–{data.ends_at.isoformat()}. "
                    "Patient must choose: transfer or reschedule."
                ),
            )
            self.notifier.notify_session(
                session_id=session_id,
                sender_id=doctor_id,
                body=(
                    f"Notice: {doctor_name} will be unavailable during your scheduled window.\n"
                    "In the app, choose one option:\n"
                    "1) Transfer to another specialist\n"
                    "2) Reschedule your appointment date"
                ),
            )

        logger.info(
            "Doctor UNAVAILABILITY block=%s doctor=%s %s–%s | Affected sessions: %s | Admin & patients notified.",
            block.id,
            doctor_id,
            data.starts_at,
            data.ends_at,
            affected_ids,
        )
        return block, affected_ids

    def resolve_impact(self, impact_id: str, client_id: str, body: ResolveUnavailabilityBody) -> UnavailabilitySessionImpact:
        impact = self.repo.get_impact_by_id(impact_id)
        if not impact:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Action not found")
        if impact.status != UnavailabilityImpactStatus.awaiting_patient:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="This item is already resolved")

        session = self.session_repo.get_by_id(impact.session_id)
        if not session or session.client_id != client_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not allowed")

        block = impact.block
        unavailable_doctor_id = block.doctor_id

        if body.resolution == "transfer":
            if not body.to_doctor_id:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="to_doctor_id is required for transfer")
            to_doc = self.user_repo.get_by_id(body.to_doctor_id)
            if not to_doc or to_doc.role != UserRole.doctor:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Specialist not found")
            if not to_doc.is_available:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Specialist is not available")
            if to_doc.id == unavailable_doctor_id:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Choose a different specialist")

            orig = self.user_repo.get_by_id(unavailable_doctor_id)
            o_spec = orig.specialist_type if orig else None
            t_spec = to_doc.specialist_type
            if o_spec is not None and t_spec is not None:
                if o_spec != SpecialistType.general and t_spec != SpecialistType.general and o_spec != t_spec:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Replacement specialist must match the original specialty",
                    )

            session.doctor_id = body.to_doctor_id
            session.status = SessionStatus.scheduled
            prev = session.notes or ""
            note = (
                f"\n\n---\nSession reassigned due to specialist unavailability "
                f"({unavailable_doctor_id} → {body.to_doctor_id}).\n"
            )
            session.notes = (prev + note).strip()
            self.session_repo.update(session)

            impact.resolution = UnavailabilityResolution.transfer
            impact.chosen_doctor_id = body.to_doctor_id
        else:
            if not body.new_scheduled_at:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="new_scheduled_at is required to reschedule")
            session.scheduled_at = body.new_scheduled_at
            session.status = SessionStatus.scheduled
            self.session_repo.update(session)

            impact.resolution = UnavailabilityResolution.reschedule
            impact.new_scheduled_at = body.new_scheduled_at

        impact.status = UnavailabilityImpactStatus.resolved
        impact.resolved_at = datetime.now(timezone.utc)
        self.repo.update_impact(impact)

        self.notifier.notify_admin(
            client_id=client_id,
            body=(
                f"[Unavailability resolved] impact={impact_id} session={impact.session_id} "
                f"resolution={body.resolution}"
            ),
        )

        logger.info(
            "Patient RESOLVED unavailability impact=%s session=%s resolution=%s | Admin notified.",
            impact_id,
            impact.session_id,
            body.resolution,
        )
        return impact
