from fastapi import HTTPException, status
from sqlalchemy.orm import Session as DBSession

from app.core.logging import logger
from app.models.patient_transfer_request import PatientTransferRequest, PatientTransferRequestStatus
from app.models.user import SpecialistType, UserRole
from app.repositories.patient_transfer_request_repository import PatientTransferRequestRepository
from app.repositories.session_repository import SessionRepository
from app.repositories.user_repository import UserRepository
from app.schemas.care_actions import PatientTransferRequestCreate
from app.services.care_event_notifier import CareEventNotifier
from app.services.transfer_service import TransferService


class PatientTransferRequestService:
    def __init__(self, db: DBSession):
        self.db = db
        self.repo = PatientTransferRequestRepository(db)
        self.session_repo = SessionRepository(db)
        self.user_repo = UserRepository(db)
        self.transfer_svc = TransferService(db)
        self.notifier = CareEventNotifier(db)

    @staticmethod
    def _specialties_compatible(from_spec, to_spec) -> bool:
        if from_spec is None or to_spec is None:
            return True
        if from_spec == SpecialistType.general or to_spec == SpecialistType.general:
            return True
        return from_spec == to_spec

    def create_request(self, session_id: str, requesting_doctor_id: str, data: PatientTransferRequestCreate) -> PatientTransferRequest:
        reason = (data.reason or "").strip()
        if not reason:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Reason for transfer is required")

        session = self.session_repo.get_by_id(session_id)
        if not session:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")
        if session.doctor_id != requesting_doctor_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only the assigned doctor can request a transfer")

        if self.repo.get_pending_for_session(session_id):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="A transfer request is already awaiting patient approval for this session",
            )

        from_doctor = self.user_repo.get_by_id(requesting_doctor_id)
        to_doctor = self.user_repo.get_by_id(data.to_doctor_id)
        if not to_doctor or to_doctor.role != UserRole.doctor:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Target specialist not found")
        if not to_doctor.is_available:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Target specialist is not available")
        if to_doctor.id == requesting_doctor_id:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot transfer to yourself")

        if not self._specialties_compatible(from_doctor.specialist_type, to_doctor.specialist_type):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Target specialist must match your specialty for this transfer",
            )

        row = PatientTransferRequest(
            session_id=session_id,
            from_doctor_id=requesting_doctor_id,
            to_doctor_id=data.to_doctor_id,
            reason=reason,
            status=PatientTransferRequestStatus.requested,
        )
        row = self.repo.create(row)

        # Automatic messages: patient (session chat) + admin thread.
        from_doc = self.user_repo.get_by_id(requesting_doctor_id)
        to_doc = self.user_repo.get_by_id(data.to_doctor_id)
        from_name = (from_doc.full_name if from_doc else "Specialist").strip() or "Specialist"
        to_name = (to_doc.full_name if to_doc else "Specialist").strip() or "Specialist"
        self.notifier.notify_session(
            session_id=session_id,
            sender_id=requesting_doctor_id,
            body=(
                f"Transfer request: {from_name} proposes transferring your care to {to_name}.\n"
                f"Reason: {reason}\n"
                "Please review and accept/decline in the app."
            ),
        )
        self.notifier.notify_admin(
            client_id=session.client_id,
            body=(
                f"[Transfer requested] session={session_id} from={from_name} to={to_name}. "
                f"Reason: {reason}"
            ),
        )

        logger.info(
            "Patient transfer REQUESTED session=%s from=%s to=%s reason=%s | Patient must approve. Admin notified.",
            session_id,
            requesting_doctor_id,
            data.to_doctor_id,
            reason,
        )
        return row

    def get_pending_for_session(self, session_id: str, doctor_id: str) -> PatientTransferRequest | None:
        session = self.session_repo.get_by_id(session_id)
        if not session:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")
        if session.doctor_id != doctor_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not allowed to view this session")
        return self.repo.get_pending_for_session(session_id)

    def respond(self, request_id: str, client_id: str, accept: bool) -> PatientTransferRequest:
        req = self.repo.get_by_id(request_id)
        if not req:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transfer request not found")
        if req.status != PatientTransferRequestStatus.requested:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="This transfer request is no longer pending")

        session = self.session_repo.get_by_id(req.session_id)
        if not session or session.client_id != client_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not allowed to respond to this request")

        if not accept:
            req.status = PatientTransferRequestStatus.declined
            self.repo.update(req)
            self.notifier.notify_admin(
                client_id=client_id,
                body=f"[Transfer declined] session={req.session_id} request={req.id}",
            )
            logger.info(
                "Patient DECLINED transfer request=%s session=%s | Admin notified.",
                request_id,
                req.session_id,
            )
            return req

        to_doctor = self.user_repo.get_by_id(req.to_doctor_id)
        if not to_doctor or not to_doctor.is_available:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="The proposed specialist is no longer available; please contact support",
            )

        self.transfer_svc.apply_transfer_to_doctor(
            session_id=req.session_id,
            from_doctor_id=req.from_doctor_id,
            to_doctor_id=req.to_doctor_id,
            reason=req.reason,
        )

        req.status = PatientTransferRequestStatus.completed
        self.repo.update(req)

        self.notifier.notify_admin(
            client_id=client_id,
            body=f"[Transfer approved & applied] session={req.session_id} request={req.id}",
        )

        logger.info(
            "Patient APPROVED transfer request=%s session=%s → completed | Admin notified.",
            request_id,
            req.session_id,
        )
        return req
