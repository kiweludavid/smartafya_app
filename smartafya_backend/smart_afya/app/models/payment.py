import uuid
from datetime import datetime, timezone
from enum import Enum as PyEnum

from sqlalchemy import DateTime, Enum, Float, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class PaymentStatus(str, PyEnum):
    pending = "pending"
    proof_submitted = "proof_submitted"
    paid = "paid"
    refunded = "refunded"


class PaymentType(str, PyEnum):
    fixed = "fixed"
    negotiated = "negotiated"


class Payment(Base):
    __tablename__ = "payments"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    session_id: Mapped[str] = mapped_column(String, ForeignKey("sessions.id"), nullable=False, unique=True, index=True)

    amount: Mapped[float | None] = mapped_column(Float, nullable=True)  # nullable for negotiated physical sessions
    status: Mapped[PaymentStatus] = mapped_column(Enum(PaymentStatus), default=PaymentStatus.pending)
    reference: Mapped[str | None] = mapped_column(String(255), nullable=True)
    payment_type: Mapped[PaymentType] = mapped_column(Enum(PaymentType), default=PaymentType.fixed)

    instructions_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    proof_submitted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    proof_attachment: Mapped[str | None] = mapped_column(Text, nullable=True)  # base64 (dev / small proofs)
    proof_filename: Mapped[str | None] = mapped_column(String(255), nullable=True)
    confirmed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    # relationships
    session = relationship("Session", back_populates="payment")
