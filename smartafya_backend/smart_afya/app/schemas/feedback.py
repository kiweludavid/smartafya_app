from datetime import datetime
from pydantic import BaseModel, field_validator


class FeedbackCreate(BaseModel):
    session_id: str
    treatment_rating: int | None = None
    doctor_feedback: str | None = None
    app_rating: int | None = None
    app_feedback: str | None = None
    suggestions: str | None = None
    family_rating: int | None = None
    family_comments: str | None = None

    @field_validator("treatment_rating", "app_rating", "family_rating", mode="before")
    @classmethod
    def rating_range(cls, v):
        if v is not None and not (1 <= v <= 5):
            raise ValueError("Rating must be between 1 and 5")
        return v


class FeedbackOut(BaseModel):
    model_config = {"from_attributes": True}

    id: str
    session_id: str
    client_id: str
    treatment_rating: int | None
    doctor_feedback: str | None
    app_rating: int | None
    app_feedback: str | None
    suggestions: str | None
    family_rating: int | None = None
    family_comments: str | None = None
    created_at: datetime
