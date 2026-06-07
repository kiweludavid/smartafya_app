import uuid
from datetime import datetime, timezone
from enum import Enum as PyEnum

from sqlalchemy import DateTime, Enum, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class PatientTransferRequestStatus(str, PyEnum):
    requested = "requested"
    declined = "declined"
    completed = "completed"


class PatientTransferRequest(Base):
    __tablename__ = "patient_transfer_requests"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    session_id: Mapped[str] = mapped_column(String, ForeignKey("sessions.id"), nullable=False, index=True)
    from_doctor_id: Mapped[str] = mapped_column(String, ForeignKey("users.id"), nullable=False, index=True)
    to_doctor_id: Mapped[str] = mapped_column(String, ForeignKey("users.id"), nullable=False, index=True)
    reason: Mapped[str] = mapped_column(Text, nullable=False)
    status: Mapped[PatientTransferRequestStatus] = mapped_column(
        Enum(PatientTransferRequestStatus), default=PatientTransferRequestStatus.requested
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    session = relationship("Session", back_populates="patient_transfer_requests")
    from_doctor = relationship("User", foreign_keys=[from_doctor_id])
    to_doctor = relationship("User", foreign_keys=[to_doctor_id])
