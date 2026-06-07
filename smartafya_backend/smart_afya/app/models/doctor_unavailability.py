import uuid
from datetime import datetime, timezone
from enum import Enum as PyEnum

from sqlalchemy import DateTime, Enum, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class UnavailabilityImpactStatus(str, PyEnum):
    awaiting_patient = "awaiting_patient"
    resolved = "resolved"


class UnavailabilityResolution(str, PyEnum):
    transfer = "transfer"
    reschedule = "reschedule"


class DoctorUnavailabilityBlock(Base):
    __tablename__ = "doctor_unavailability_blocks"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    doctor_id: Mapped[str] = mapped_column(String, ForeignKey("users.id"), nullable=False, index=True)
    starts_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    ends_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    doctor = relationship("User", foreign_keys=[doctor_id])
    impacts = relationship("UnavailabilitySessionImpact", back_populates="block", cascade="all, delete-orphan")


class UnavailabilitySessionImpact(Base):
    __tablename__ = "unavailability_session_impacts"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    block_id: Mapped[str] = mapped_column(
        String, ForeignKey("doctor_unavailability_blocks.id", ondelete="CASCADE"), nullable=False, index=True
    )
    session_id: Mapped[str] = mapped_column(String, ForeignKey("sessions.id"), nullable=False, index=True)
    status: Mapped[UnavailabilityImpactStatus] = mapped_column(
        Enum(UnavailabilityImpactStatus), default=UnavailabilityImpactStatus.awaiting_patient
    )
    resolution: Mapped[UnavailabilityResolution | None] = mapped_column(Enum(UnavailabilityResolution), nullable=True)
    chosen_doctor_id: Mapped[str | None] = mapped_column(String, ForeignKey("users.id"), nullable=True)
    new_scheduled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    block = relationship("DoctorUnavailabilityBlock", back_populates="impacts")
    session = relationship("Session", back_populates="unavailability_impacts")
    chosen_doctor = relationship("User", foreign_keys=[chosen_doctor_id])
