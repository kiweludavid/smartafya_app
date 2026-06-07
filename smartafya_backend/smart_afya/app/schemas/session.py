from datetime import datetime
from pydantic import BaseModel

from app.models.session import SessionStatus


class SessionAssign(BaseModel):
    doctor_id: str
    scheduled_at: datetime
    meeting_link: str | None = None


class SessionUpdate(BaseModel):
    status: SessionStatus | None = None
    meeting_link: str | None = None
    scheduled_at: datetime | None = None
    notes: str | None = None


class SessionOut(BaseModel):
    model_config = {"from_attributes": True}

    id: str
    booking_id: str
    client_id: str
    doctor_id: str | None
    status: SessionStatus
    meeting_link: str | None
    scheduled_at: datetime | None
    notes: str | None
    check_in_at: datetime | None = None
    check_out_at: datetime | None = None
    created_at: datetime
    updated_at: datetime
