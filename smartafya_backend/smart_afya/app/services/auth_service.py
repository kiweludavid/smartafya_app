from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import hash_password, verify_password, create_access_token
from app.models.user import User, UserRole
from app.repositories.user_repository import UserRepository
from app.schemas.user import UserRegister, UserLogin
from app.schemas.token import Token, AuthResponse


class AuthService:
    def __init__(self, db: Session):
        self.repo = UserRepository(db)

    def register(self, data: UserRegister) -> AuthResponse:
        if self.repo.get_by_email(data.email):
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email already registered")

        requested_role = data.role or UserRole.client
        is_dev = (settings.APP_ENV or "").lower() == "development"

        allow_doctor_self_signup = bool(settings.ALLOW_DOCTOR_SELF_SIGNUP) and is_dev
        if requested_role == UserRole.doctor and not allow_doctor_self_signup:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Doctor self-registration is disabled.",
            )

        if requested_role == UserRole.doctor and data.specialist_type is None:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="specialist_type is required when role is doctor",
            )

        user = User(
            full_name=data.full_name,
            email=data.email,
            phone=data.phone,
            role=requested_role,
            specialist_type=data.specialist_type,
            hashed_password=hash_password(data.password),
            is_verified=(False if (requested_role == UserRole.doctor and allow_doctor_self_signup) else True),
        )
        user = self.repo.create(user)
        token = create_access_token(
            subject=user.id,
            claims={"user_id": user.id, "role": user.role.value},
        )
        return AuthResponse(
            user_id=user.id,
            email=user.email,
            role=user.role.value,
            access_token=token,
        )

    def login(self, data: UserLogin) -> Token:
        user = self.repo.get_by_email(data.email)
        if not user or not verify_password(data.password, user.hashed_password):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password",
            )
        if not user.is_active:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account is deactivated")
        if user.role == UserRole.admin:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Admins must log in through the web dashboard",
            )

        token = create_access_token(subject=user.id, claims={"user_id": user.id, "role": user.role.value})
        return Token(access_token=token)

    def admin_login(self, data: UserLogin) -> Token:
        user = self.repo.get_by_email(data.email)
        if not user or not verify_password(data.password, user.hashed_password):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password",
            )
        if not user.is_active:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account is deactivated")
        if user.role != UserRole.admin:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admins only")

        token = create_access_token(subject=user.id, claims={"user_id": user.id, "role": user.role.value})
        return Token(access_token=token)
