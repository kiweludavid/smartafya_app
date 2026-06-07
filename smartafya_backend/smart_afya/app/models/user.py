import uuid
from datetime import datetime, timezone
from enum import Enum as PyEnum

from sqlalchemy import Boolean, DateTime, Enum, Float, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class UserRole(str, PyEnum):
    client = "client"
    doctor = "doctor"
    admin = "admin"


class SpecialistType(str, PyEnum):
    psychologist = "psychologist"
    psychiatrist = "psychiatrist"
    therapist = "therapist"
    cleric = "cleric"
    influencer = "influencer"
    general = "general"


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    full_name: Mapped[str] = mapped_column(String(255), nullable=False)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    phone: Mapped[str | None] = mapped_column(String(50), nullable=True)
    role: Mapped[UserRole] = mapped_column(Enum(UserRole), nullable=False, default=UserRole.client)
    specialist_type: Mapped[SpecialistType | None] = mapped_column(Enum(SpecialistType), nullable=True)
    hashed_password: Mapped[str] = mapped_column(String(255), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    is_verified: Mapped[bool] = mapped_column(Boolean, default=True)
    is_available: Mapped[bool] = mapped_column(Boolean, default=True)  # for doctors
    base_latitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    base_longitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    # relationships
    bookings_as_client = relationship("Booking", foreign_keys="Booking.client_id", back_populates="client")
    bookings_as_doctor = relationship("Booking", foreign_keys="Booking.preferred_specialist_id", back_populates="preferred_specialist")
    sessions_as_doctor = relationship("Session", foreign_keys="Session.doctor_id", back_populates="doctor")
    sessions_as_client = relationship("Session", foreign_keys="Session.client_id", back_populates="client")
    transfers_from = relationship("TransferLog", foreign_keys="TransferLog.from_doctor_id", back_populates="from_doctor")
    transfers_to = relationship("TransferLog", foreign_keys="TransferLog.to_doctor_id", back_populates="to_doctor")
    feedbacks = relationship("Feedback", back_populates="client")
