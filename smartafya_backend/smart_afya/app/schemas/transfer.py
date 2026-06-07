from datetime import datetime
from pydantic import BaseModel


class TransferRequest(BaseModel):
    to_doctor_id: str
    reason: str | None = None


class TransferLogOut(BaseModel):
    model_config = {"from_attributes": True}

    id: str
    session_id: str
    from_doctor_id: str
    to_doctor_id: str
    reason: str | None
    transferred_at: datetime
