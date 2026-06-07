import uuid
from datetime import datetime, timezone
from enum import Enum as PyEnum

from sqlalchemy import Boolean, DateTime, Enum, Float, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.user import SpecialistType


class SessionType(str, PyEnum):
    audio = "audio"
    video = "video"
    physical = "physical"


class BookingStatus(str, PyEnum):
    pending = "pending"
    confirmed = "confirmed"
    cancelled = "cancelled"


class PhysicalVenue(str, PyEnum):
    home = "home"
    office = "office"


class Booking(Base):
    __tablename__ = "bookings"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    client_id: Mapped[str] = mapped_column(String, ForeignKey("users.id"), nullable=False, index=True)
    preferred_specialist_id: Mapped[str | None] = mapped_column(String, ForeignKey("users.id"), nullable=True)
    preferred_specialist_type: Mapped[SpecialistType | None] = mapped_column(Enum(SpecialistType), nullable=True)

    mental_health_description: Mapped[str] = mapped_column(Text, nullable=False)
    consent_given: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    consent_timestamp: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    session_type: Mapped[SessionType] = mapped_column(Enum(SessionType), nullable=False)
    duration_minutes: Mapped[int] = mapped_column(default=60)

    # Store at least 3 preferred dates as comma-separated ISO strings
    preferred_dates: Mapped[str] = mapped_column(Text, nullable=False)  # JSON-encoded list

    physical_location_address: Mapped[str | None] = mapped_column(Text, nullable=True)
    physical_location_lat: Mapped[float | None] = mapped_column(Float, nullable=True)
    physical_location_lng: Mapped[float | None] = mapped_column(Float, nullable=True)
    physical_venue: Mapped[PhysicalVenue | None] = mapped_column(Enum(PhysicalVenue), nullable=True)
    physical_notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    reschedule_request_dates: Mapped[str | None] = mapped_column(Text, nullable=True)  # JSON list
    reschedule_request_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    reschedule_requested_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    status: Mapped[BookingStatus] = mapped_column(Enum(BookingStatus), default=BookingStatus.pending)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    # relationships
    client = relationship("User", foreign_keys=[client_id], back_populates="bookings_as_client")
    preferred_specialist = relationship("User", foreign_keys=[preferred_specialist_id], back_populates="bookings_as_doctor")
    session = relationship("Session", back_populates="booking", uselist=False)
