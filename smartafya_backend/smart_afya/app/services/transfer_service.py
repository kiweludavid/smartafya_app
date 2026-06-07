from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy.orm import Session as DBSession

from app.models.session import SessionStatus
from app.models.transfer_log import TransferLog
from app.repositories.session_repository import SessionRepository
from app.repositories.transfer_repository import TransferRepository
from app.repositories.user_repository import UserRepository
from app.schemas.transfer import TransferRequest
from app.core.logging import logger


class TransferService:
    def __init__(self, db: DBSession):
        self.session_repo = SessionRepository(db)
        self.transfer_repo = TransferRepository(db)
        self.user_repo = UserRepository(db)

    def apply_transfer_to_doctor(
        self,
        session_id: str,
        from_doctor_id: str,
        to_doctor_id: str,
        reason: str,
    ) -> TransferLog:
        """Apply an approved transfer: log, reassign doctor, preserve notes/reports, keep session active."""
        session = self.session_repo.get_by_id(session_id)
        if not session:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")
        if session.doctor_id != from_doctor_id:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Session is no longer assigned to the originating specialist; transfer cannot complete",
            )

        to_doctor = self.user_repo.get_by_id(to_doctor_id)
        if not to_doctor or to_doctor.role.value != "doctor":
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Target doctor not found")
        if not to_doctor.is_available:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Target doctor is unavailable")

        log = TransferLog(
            session_id=session_id,
            from_doctor_id=from_doctor_id,
            to_doctor_id=to_doctor_id,
            reason=reason,
        )
        log = self.transfer_repo.create(log)

        prev = (session.notes or "").strip()
        footer = f"\n\n---\nTransfer completed (patient-approved). Reason: {reason}\n"
        session.notes = (prev + footer).strip() if prev else footer.strip()
        session.doctor_id = to_doctor_id
        session.status = SessionStatus.scheduled
        session.updated_at = datetime.now(timezone.utc)
        self.session_repo.update(session)

        logger.info(
            "Transfer EXECUTED session=%s from=%s to=%s reason=%s | Admin & patient notified.",
            session_id,
            from_doctor_id,
            to_doctor_id,
            reason,
        )
        return log

    def transfer_patient(self, session_id: str, requesting_doctor_id: str, data: TransferRequest) -> TransferLog:
        """Immediate transfer (legacy / internal). Prefer patient-approved flow via PatientTransferRequestService."""
        session = self.session_repo.get_by_id(session_id)
        if not session:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")
        if session.doctor_id != requesting_doctor_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only the assigned doctor can transfer")

        to_doctor = self.user_repo.get_by_id(data.to_doctor_id)
        if not to_doctor or to_doctor.role.value != "doctor":
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Target doctor not found")
        if not to_doctor.is_available:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Target doctor is unavailable")

        log = TransferLog(
            session_id=session_id,
            from_doctor_id=requesting_doctor_id,
            to_doctor_id=data.to_doctor_id,
            reason=data.reason,
        )
        log = self.transfer_repo.create(log)

        session.doctor_id = data.to_doctor_id
        session.status = SessionStatus.transferred
        session.updated_at = datetime.now(timezone.utc)
        self.session_repo.update(session)

        logger.info(
            "Transfer (immediate): session=%s from=%s to=%s reason=%s | Admin & patient notified.",
            session_id,
            requesting_doctor_id,
            data.to_doctor_id,
            data.reason,
        )
        return log

    def get_transfer_history(self, session_id: str) -> list[TransferLog]:
        return self.transfer_repo.get_by_session(session_id)

    def list_all(self) -> list[TransferLog]:
        return self.transfer_repo.get_all()
