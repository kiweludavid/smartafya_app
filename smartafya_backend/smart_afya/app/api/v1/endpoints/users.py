from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user, require_admin
from app.db.session import get_db
from app.models.user import SpecialistType, User
from app.repositories.user_repository import UserRepository
from app.schemas.user import DoctorBaseLocationUpdate, UserOut, UserUpdate, DoctorAvailabilityUpdate

router = APIRouter(prefix="/users", tags=["Users"])


@router.get("/me", response_model=UserOut)
def get_me(current_user: User = Depends(get_current_user)):
    """Return the authenticated user's profile."""
    return current_user


@router.patch("/me", response_model=UserOut)
def update_me(
    data: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Update authenticated user's profile."""
    if data.full_name is not None:
        current_user.full_name = data.full_name
    if data.phone is not None:
        current_user.phone = data.phone
    if data.specialist_type is not None:
        current_user.specialist_type = data.specialist_type
    repo = UserRepository(db)
    return repo.update(current_user)


@router.patch("/me/availability", response_model=UserOut)
def update_availability(
    data: DoctorAvailabilityUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Doctor updates their availability status."""
    from fastapi import HTTPException, status
    if current_user.role.value != "doctor":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only doctors can update availability")
    current_user.is_available = data.is_available
    repo = UserRepository(db)
    return repo.update(current_user)


@router.get("/doctors", response_model=list[UserOut])
def list_doctors(
    available_only: bool = False,
    specialist_type: SpecialistType | None = None,
    exclude_doctor_id: str | None = None,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    """List doctors; optional filter by availability, specialty match, or exclude one id (e.g. self)."""
    repo = UserRepository(db)
    return repo.get_doctors(
        available_only=available_only,
        specialist_type=specialist_type,
        exclude_doctor_id=exclude_doctor_id,
    )


@router.get("/", response_model=list[UserOut], dependencies=[Depends(require_admin)])
def list_users(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    """Admin: list all users."""
    repo = UserRepository(db)
    return repo.get_all(skip=skip, limit=limit)


@router.get("/{user_id}", response_model=UserOut, dependencies=[Depends(require_admin)])
def get_user(user_id: str, db: Session = Depends(get_db)):
    """Admin: get a specific user."""
    from fastapi import HTTPException, status
    repo = UserRepository(db)
    user = repo.get_by_id(user_id)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return user


@router.patch(
    "/{user_id}/doctor-base-location",
    response_model=UserOut,
    dependencies=[Depends(require_admin)],
)
def set_doctor_base_location(
    user_id: str,
    data: DoctorBaseLocationUpdate,
    db: Session = Depends(get_db),
):
    """Admin sets a doctor's base coordinates for proximity-based assignment."""
    from fastapi import HTTPException, status
    from app.models.user import UserRole

    repo = UserRepository(db)
    user = repo.get_by_id(user_id)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    if user.role != UserRole.doctor:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="User is not a doctor")
    user.base_latitude = data.base_latitude
    user.base_longitude = data.base_longitude
    return repo.update(user)


@router.patch("/{user_id}/deactivate", response_model=UserOut, dependencies=[Depends(require_admin)])
def deactivate_user(user_id: str, db: Session = Depends(get_db)):
    """Admin: deactivate a user account."""
    from fastapi import HTTPException, status
    repo = UserRepository(db)
    user = repo.get_by_id(user_id)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    user.is_active = False
    return repo.update(user)
