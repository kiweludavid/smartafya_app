from sqlalchemy.orm import Session

from app.models.user import SpecialistType, User, UserRole


class UserRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_by_id(self, user_id: str) -> User | None:
        return self.db.query(User).filter(User.id == user_id).first()

    def get_by_email(self, email: str) -> User | None:
        return self.db.query(User).filter(User.email == email).first()

    def get_all(self, skip: int = 0, limit: int = 100) -> list[User]:
        return self.db.query(User).offset(skip).limit(limit).all()

    def get_doctors(
        self,
        available_only: bool = False,
        specialist_type: SpecialistType | None = None,
        exclude_doctor_id: str | None = None,
    ) -> list[User]:
        q = self.db.query(User).filter(User.role == UserRole.doctor)
        if available_only:
            q = q.filter(User.is_available == True)
        if specialist_type is not None:
            q = q.filter(User.specialist_type == specialist_type)
        if exclude_doctor_id:
            q = q.filter(User.id != exclude_doctor_id)
        return q.all()

    def get_first_admin(self) -> User | None:
        return (
            self.db.query(User)
            .filter(User.role == UserRole.admin, User.is_active == True)  # noqa: E712
            .order_by(User.created_at.asc())
            .first()
        )

    def create(self, user: User) -> User:
        self.db.add(user)
        self.db.commit()
        self.db.refresh(user)
        return user

    def update(self, user: User) -> User:
        self.db.commit()
        self.db.refresh(user)
        return user

    def delete(self, user: User) -> None:
        self.db.delete(user)
        self.db.commit()
