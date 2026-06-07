from datetime import datetime
from pydantic import BaseModel, EmailStr, field_validator

from app.models.user import UserRole, SpecialistType


class UserRegister(BaseModel):
    full_name: str
    email: EmailStr
    phone: str | None = None
    password: str
    role: UserRole = UserRole.client
    specialist_type: SpecialistType | None = None

    @field_validator("password")
    @classmethod
    def password_strength(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        return v


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserOut(BaseModel):
    model_config = {"from_attributes": True}

    id: str
    full_name: str
    email: str
    phone: str | None
    role: UserRole
    specialist_type: SpecialistType | None
    is_active: bool
    is_verified: bool
    is_available: bool
    base_latitude: float | None = None
    base_longitude: float | None = None
    created_at: datetime


class UserUpdate(BaseModel):
    full_name: str | None = None
    phone: str | None = None
    specialist_type: SpecialistType | None = None


class DoctorAvailabilityUpdate(BaseModel):
    is_available: bool


class DoctorBaseLocationUpdate(BaseModel):
    base_latitude: float
    base_longitude: float
