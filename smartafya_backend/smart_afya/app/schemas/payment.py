from datetime import datetime

from pydantic import BaseModel, field_validator

from app.models.payment import PaymentStatus, PaymentType


class PaymentCreate(BaseModel):
    session_id: str
    amount: float | None = None
    payment_type: PaymentType = PaymentType.fixed
    reference: str | None = None
    instructions_text: str | None = None


class PaymentUpdate(BaseModel):
    amount: float | None = None
    status: PaymentStatus | None = None
    reference: str | None = None
    instructions_text: str | None = None


class PaymentProofSubmit(BaseModel):
    proof_base64: str
    filename: str | None = None

    @field_validator("proof_base64")
    @classmethod
    def size_cap(cls, v: str) -> str:
        if len(v) > 2_200_000:
            raise ValueError("Proof file is too large; please upload a smaller image or PDF snapshot")
        return v


class PaymentOut(BaseModel):
    model_config = {"from_attributes": True}

    id: str
    session_id: str
    amount: float | None
    status: PaymentStatus
    reference: str | None
    payment_type: PaymentType
    instructions_text: str | None = None
    proof_submitted_at: datetime | None = None
    proof_filename: str | None = None
    confirmed_at: datetime | None = None
    created_at: datetime
    updated_at: datetime
