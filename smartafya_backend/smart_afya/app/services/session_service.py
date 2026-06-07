from datetime import datetime, timezone
from urllib.parse import quote

from fastapi import HTTPException, status
from sqlalchemy.orm import Session as DBSession

from app.models.booking import SessionType
from app.models.session import Session, SessionStatus
from app.repositories.session_repository import SessionRepository
from app.repositories.user_repository import UserRepository
from app.schemas.session import SessionAssign, SessionUpdate
from app.core.logging import logger


class SessionService:
    def __init__(self, db: DBSession):
        self.db = db
        self.repo = SessionRepository(db)
        self.user_repo = UserRepository(db)

    def _refresh_chat_expiry(self, session_id: str) -> None:
        from app.services.chat_service import ChatService

        ChatService(self.db).refresh_session_conversation_expiry(session_id)

    def get_session(self, session_id: str) -> Session:
        s = self.repo.get_by_id(session_id)
        if not s:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")
        return s

    def assign_doctor(self, session_id: str, data: SessionAssign) -> Session:
        s = self.get_session(session_id)
        doctor = self.user_repo.get_by_id(data.doctor_id)
        if not doctor or doctor.role.value != "doctor":
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Doctor not found")

        booking = s.booking
        is_physical = booking.session_type == SessionType.physical

        if not is_physical and not doctor.is_available:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Doctor is currently unavailable. Consider transferring or rescheduling.",
            )

        s.doctor_id = data.doctor_id
        s.scheduled_at = data.scheduled_at
        s.status = SessionStatus.scheduled
        if is_physical:
            addr = (booking.physical_location_address or "").strip()
            s.meeting_link = data.meeting_link or (
                f"https://www.google.com/maps/search/?api=1&query={quote(addr)}" if addr else None
            )
        else:
            s.meeting_link = data.meeting_link or f"https://meet.smartafya.com/session/{s.id}"
        logger.info("Session %s assigned to doctor %s (physical=%s)", session_id, data.doctor_id, is_physical)
        out = self.repo.update(s)
        self._refresh_chat_expiry(session_id)
        return out

    def update_session(self, session_id: str, data: SessionUpdate, actor_role: str) -> Session:
        s = self.get_session(session_id)
        if data.status:
            s.status = data.status
        if data.meeting_link is not None:
            s.meeting_link = data.meeting_link
        if data.scheduled_at is not None:
            s.scheduled_at = data.scheduled_at
        if data.notes is not None:
            s.notes = data.notes
        s.updated_at = datetime.now(timezone.utc)
        out = self.repo.update(s)
        self._refresh_chat_expiry(session_id)
        return out

    def physical_check_in(self, session_id: str, doctor_id: str) -> Session:
        s = self.get_session(session_id)
        if s.doctor_id != doctor_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your session")
        booking = s.booking
        if booking.session_type != SessionType.physical:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Not a physical session")
        if s.check_in_at is not None:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Already checked in")
        s.check_in_at = datetime.now(timezone.utc)
        s.updated_at = datetime.now(timezone.utc)
        return self.repo.update(s)

    def physical_check_out(self, session_id: str, doctor_id: str) -> Session:
        s = self.get_session(session_id)
        if s.doctor_id != doctor_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your session")
        booking = s.booking
        if booking.session_type != SessionType.physical:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Not a physical session")
        if s.check_in_at is None:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Check in first")
        if s.check_out_at is not None:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Already checked out")
        s.check_out_at = datetime.now(timezone.utc)
        s.updated_at = datetime.now(timezone.utc)
        return self.repo.update(s)

    def doctor_mark_unavailable(self, session_id: str, doctor_id: str) -> dict:
        """Doctor marks themselves unavailable for a session."""
        s = self.get_session(session_id)
        if s.doctor_id != doctor_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your session")

        doctor = self.user_repo.get_by_id(doctor_id)
        doctor.is_available = False
        self.user_repo.update(doctor)

        logger.info(
            "Doctor %s marked unavailable for session %s. Patient %s notified.",
            doctor_id, session_id, s.client_id,
        )
        return {
            "message": "Marked unavailable. Patient notified.",
            "options": ["transfer_to_another_specialist", "reschedule_session"],
            "session_id": session_id,
        }

    def list_sessions_for_client(self, client_id: str) -> list[Session]:
        return self.repo.get_by_client(client_id)

    def list_sessions_for_doctor(self, doctor_id: str) -> list[Session]:
        return self.repo.get_by_doctor(doctor_id)

    def list_all(self) -> list[Session]:
        return self.repo.get_all()
