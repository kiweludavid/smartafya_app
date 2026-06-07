from sqlalchemy.orm import Session

from app.models.payment import Payment


class PaymentRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_by_id(self, payment_id: str) -> Payment | None:
        return self.db.query(Payment).filter(Payment.id == payment_id).first()

    def get_by_session(self, session_id: str) -> Payment | None:
        return self.db.query(Payment).filter(Payment.session_id == session_id).first()

    def get_all(self, skip: int = 0, limit: int = 100) -> list[Payment]:
        return self.db.query(Payment).offset(skip).limit(limit).all()

    def create(self, payment: Payment) -> Payment:
        self.db.add(payment)
        self.db.commit()
        self.db.refresh(payment)
        return payment

    def update(self, payment: Payment) -> Payment:
        self.db.commit()
        self.db.refresh(payment)
        return payment
