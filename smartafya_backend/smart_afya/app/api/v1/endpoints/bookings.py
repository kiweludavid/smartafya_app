from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user, require_admin, require_client
from app.db.session import get_db
from app.models.user import User, UserRole
from app.schemas.booking import BookingCreate, BookingOut, BookingRescheduleRequest
from app.services.booking_service import BookingService

router = APIRouter(prefix="/bookings", tags=["Bookings"])


@router.post("/", response_model=BookingOut, status_code=201)
def create_booking(
    data: BookingCreate,
    current_user: User = Depends(require_client),
    db: Session = Depends(get_db),
):
    """
    Client submits a mental health consultation booking.

    **Consent is required** — `consent_given` must be `true` or the request is rejected.
    At least **3 preferred dates** must be provided.

    **Request body example:**
    ```json
    {
      "mental_health_description": "I have been experiencing anxiety for 3 months...",
      "consent_given": true,
      "session_type": "video",
      "duration_minutes": 60,
      "preferred_dates": ["2024-07-01T10:00:00Z", "2024-07-02T14:00:00Z", "2024-07-03T09:00:00Z"],
      "preferred_specialist_id": null
    }
    ```
    """
    svc = BookingService(db)
    return svc.create_booking(client_id=current_user.id, data=data)


@router.get("/my", response_model=list[BookingOut])
def my_bookings(current_user: User = Depends(require_client), db: Session = Depends(get_db)):
    """Client: list my bookings."""
    svc = BookingService(db)
    return svc.list_bookings_for_client(current_user.id)


@router.get("/", response_model=list[BookingOut], dependencies=[Depends(require_admin)])
def list_all_bookings(db: Session = Depends(get_db)):
    """Admin: list all bookings."""
    svc = BookingService(db)
    return svc.list_all_bookings()


@router.get("/{booking_id}", response_model=BookingOut)
def get_booking(
    booking_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get a booking by ID. Clients can only view their own bookings."""
    from fastapi import HTTPException, status
    svc = BookingService(db)
    booking = svc.get_booking(booking_id)
    if current_user.role == UserRole.client and booking.client_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")
    return booking


@router.post("/{booking_id}/cancel", response_model=BookingOut)
def cancel_booking(
    booking_id: str,
    current_user: User = Depends(require_client),
    db: Session = Depends(get_db),
):
    """Client cancels a booking and linked session."""
    svc = BookingService(db)
    return svc.cancel_booking(booking_id, current_user.id)


@router.post("/{booking_id}/reschedule-request", response_model=BookingOut)
def request_reschedule(
    booking_id: str,
    data: BookingRescheduleRequest,
    current_user: User = Depends(require_client),
    db: Session = Depends(get_db),
):
    """Client requests new preferred dates (admin coordinates)."""
    svc = BookingService(db)
    return svc.request_reschedule(booking_id, current_user.id, data)
