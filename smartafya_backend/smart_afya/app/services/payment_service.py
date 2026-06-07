from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.payment import Payment, PaymentStatus
from app.models.user import User, UserRole
from app.repositories.payment_repository import PaymentRepository
from app.repositories.session_repository import SessionRepository
from app.schemas.payment import PaymentCreate, PaymentProofSubmit, PaymentUpdate


class PaymentService:
    def __init__(self, db: Session):
        self.repo = PaymentRepository(db)
        self.session_repo = SessionRepository(db)

    def _assert_session_payment_access(self, session_id: str, user: User) -> None:
        session = self.session_repo.get_by_id(session_id)
        if not session:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")
        if user.role == UserRole.admin:
            return
        if user.role == UserRole.client and session.client_id == user.id:
            return
        if user.role == UserRole.doctor and session.doctor_id == user.id:
            return
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

    def create_payment(self, data: PaymentCreate) -> Payment:
        session = self.session_repo.get_by_id(data.session_id)
        if not session:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")
        if self.repo.get_by_session(data.session_id):
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Payment record already exists for this session")

        payment = Payment(
            session_id=data.session_id,
            amount=data.amount,
            payment_type=data.payment_type,
            reference=data.reference,
            instructions_text=data.instructions_text,
        )
        return self.repo.create(payment)

    def update_payment(self, payment_id: str, data: PaymentUpdate) -> Payment:
        payment = self.repo.get_by_id(payment_id)
        if not payment:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment not found")
        if data.amount is not None:
            payment.amount = data.amount
        if data.status is not None:
            if data.status == PaymentStatus.paid and payment.status != PaymentStatus.paid:
                payment.confirmed_at = datetime.now(timezone.utc)
            payment.status = data.status
        if data.reference is not None:
            payment.reference = data.reference
        if data.instructions_text is not None:
            payment.instructions_text = data.instructions_text
        return self.repo.update(payment)

    def submit_proof(self, payment_id: str, client_id: str, data: PaymentProofSubmit) -> Payment:
        payment = self.repo.get_by_id(payment_id)
        if not payment:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment not found")
        session = self.session_repo.get_by_id(payment.session_id)
        if not session or session.client_id != client_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your payment")
        if payment.status not in (PaymentStatus.pending, PaymentStatus.proof_submitted):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Payment proof cannot be submitted for this status",
            )
        payment.proof_attachment = data.proof_base64
        payment.proof_filename = data.filename
        payment.proof_submitted_at = datetime.now(timezone.utc)
        payment.status = PaymentStatus.proof_submitted
        return self.repo.update(payment)

    def get_payment(self, payment_id: str) -> Payment:
        p = self.repo.get_by_id(payment_id)
        if not p:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment not found")
        return p

    def get_payment_by_session(self, session_id: str, user: User) -> Payment:
        self._assert_session_payment_access(session_id, user)
        p = self.repo.get_by_session(session_id)
        if not p:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No payment for this session")
        return p

    def list_all(self) -> list[Payment]:
        return self.repo.get_all()
