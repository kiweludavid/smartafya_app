import uuid
from datetime import datetime, timezone
from enum import Enum as PyEnum

from sqlalchemy import DateTime, Enum, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class SessionStatus(str, PyEnum):
    requested = "requested"  # physical: awaiting admin assignment / scheduling
    pending = "pending"
    scheduled = "scheduled"
    completed = "completed"
    transferred = "transferred"
    cancelled = "cancelled"


class Session(Base):
    __tablename__ = "sessions"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    booking_id: Mapped[str] = mapped_column(String, ForeignKey("bookings.id"), nullable=False, unique=True, index=True)
    client_id: Mapped[str] = mapped_column(String, ForeignKey("users.id"), nullable=False, index=True)
    doctor_id: Mapped[str | None] = mapped_column(String, ForeignKey("users.id"), nullable=True, index=True)

    status: Mapped[SessionStatus] = mapped_column(Enum(SessionStatus), default=SessionStatus.pending)
    meeting_link: Mapped[str | None] = mapped_column(String(512), nullable=True)
    scheduled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    check_in_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    check_out_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    # relationships
    booking = relationship("Booking", back_populates="session")
    doctor = relationship("User", foreign_keys=[doctor_id], back_populates="sessions_as_doctor")
    client = relationship("User", foreign_keys=[client_id], back_populates="sessions_as_client")
    transfer_logs = relationship("TransferLog", back_populates="session")
    payment = relationship("Payment", back_populates="session", uselist=False)
    feedback = relationship("Feedback", back_populates="session", uselist=False)
    conversation = relationship("Conversation", back_populates="session", uselist=False)
    patient_transfer_requests = relationship("PatientTransferRequest", back_populates="session")
    unavailability_impacts = relationship("UnavailabilitySessionImpact", back_populates="session")
