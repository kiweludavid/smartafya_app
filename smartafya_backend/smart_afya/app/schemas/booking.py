from datetime import datetime

from pydantic import BaseModel, field_validator, model_validator

from app.models.booking import BookingStatus, PhysicalVenue, SessionType
from app.models.user import SpecialistType


class BookingCreate(BaseModel):
    mental_health_description: str
    consent_given: bool
    session_type: SessionType
    duration_minutes: int = 60
    preferred_dates: list[str]  # ISO datetime strings, at least 3
    preferred_specialist_id: str | None = None
    preferred_specialist_type: SpecialistType | None = None
    physical_location_address: str | None = None
    physical_location_lat: float | None = None
    physical_location_lng: float | None = None
    physical_venue: PhysicalVenue | None = None
    physical_notes: str | None = None

    @field_validator("consent_given")
    @classmethod
    def must_consent(cls, v: bool) -> bool:
        if not v:
            raise ValueError("You must accept the Terms & Conditions before submitting")
        return v

    @field_validator("preferred_dates")
    @classmethod
    def at_least_three_dates(cls, v: list[str]) -> list[str]:
        if len(v) < 3:
            raise ValueError("Please provide at least 3 preferred dates")
        return v

    @model_validator(mode="after")
    def physical_fields(self):
        if self.session_type == SessionType.physical:
            addr = (self.physical_location_address or "").strip()
            if len(addr) < 5:
                raise ValueError("Physical sessions require a clear visit address or location description")
            if self.physical_venue is None:
                raise ValueError("Select whether the visit is at home or office")
        return self


class BookingOut(BaseModel):
    model_config = {"from_attributes": True}

    id: str
    client_id: str
    preferred_specialist_id: str | None
    preferred_specialist_type: SpecialistType | None = None
    mental_health_description: str
    consent_given: bool
    consent_timestamp: datetime | None
    session_type: SessionType
    duration_minutes: int
    preferred_dates: str
    status: BookingStatus
    created_at: datetime
    physical_location_address: str | None = None
    physical_location_lat: float | None = None
    physical_location_lng: float | None = None
    physical_venue: PhysicalVenue | None = None
    physical_notes: str | None = None
    reschedule_request_dates: str | None = None
    reschedule_request_note: str | None = None
    reschedule_requested_at: datetime | None = None


class BookingRescheduleRequest(BaseModel):
    preferred_dates: list[str]
    note: str | None = None

    @field_validator("preferred_dates")
    @classmethod
    def at_least_three(cls, v: list[str]) -> list[str]:
        if len(v) < 3:
            raise ValueError("Provide at least 3 new preferred dates")
        return v
