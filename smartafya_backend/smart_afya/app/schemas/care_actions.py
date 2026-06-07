from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

from app.models.patient_transfer_request import PatientTransferRequestStatus


class PatientTransferRequestCreate(BaseModel):
    to_doctor_id: str
    reason: str = Field(..., min_length=1)


class PatientTransferRequestOut(BaseModel):
    model_config = {"from_attributes": True, "use_enum_values": True}

    id: str
    session_id: str
    from_doctor_id: str
    to_doctor_id: str
    reason: str
    status: PatientTransferRequestStatus
    created_at: datetime
    updated_at: datetime


class PatientTransferRespond(BaseModel):
    accept: bool


class DoctorSuggestionOut(BaseModel):
    id: str
    full_name: str
    specialist_type: str | None


class TimeSlotSuggestionOut(BaseModel):
    scheduled_at: datetime


class UnavailabilityImpactActionOut(BaseModel):
    id: str
    session_id: str
    block_starts_at: datetime
    block_ends_at: datetime
    doctor_name: str
    session_scheduled_at: datetime | None
    message: str
    suggested_doctors: list[DoctorSuggestionOut]
    suggested_slots: list[TimeSlotSuggestionOut]


class PendingTransferActionOut(BaseModel):
    id: str
    session_id: str
    from_doctor_name: str
    to_doctor_name: str
    reason: str
    created_at: datetime


class CareActionsOut(BaseModel):
    pending_transfers: list[PendingTransferActionOut]
    unavailability_impacts: list[UnavailabilityImpactActionOut]


class ResolveUnavailabilityBody(BaseModel):
    resolution: Literal["transfer", "reschedule"]
    to_doctor_id: str | None = None
    new_scheduled_at: datetime | None = None


class DoctorUnavailabilityCreate(BaseModel):
    starts_at: datetime
    ends_at: datetime


class DoctorUnavailabilityResultOut(BaseModel):
    block_id: str
    affected_session_count: int
    affected_session_ids: list[str]
    message: str


class UnavailabilityImpactAdminOut(BaseModel):
    impact_id: str
    session_id: str
    client_id: str
    doctor_id: str
    status: str
    block_starts_at: datetime
    block_ends_at: datetime
    session_scheduled_at: datetime | None


class AdminSessionManagementSummaryOut(BaseModel):
    pending_transfer_requests: list[PatientTransferRequestOut]
    pending_unavailability_impacts: list[UnavailabilityImpactAdminOut]


class DoctorDashboardSummaryOut(BaseModel):
    pending_transfer_requests_count: int
    pending_unavailability_impacts_count: int
    total_needing_patient_action: int
