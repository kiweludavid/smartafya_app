import json
from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.booking import Booking, BookingStatus, SessionType
from app.models.session import Session as SessionModel, SessionStatus
from app.repositories.booking_repository import BookingRepository
from app.repositories.payment_repository import PaymentRepository
from app.repositories.session_repository import SessionRepository
from app.repositories.user_repository import UserRepository
from app.schemas.booking import BookingCreate, BookingRescheduleRequest


class BookingService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = BookingRepository(db)
        self.session_repo = SessionRepository(db)
        self.payment_repo = PaymentRepository(db)
        self.user_repo = UserRepository(db)

    def create_booking(self, client_id: str, data: BookingCreate) -> Booking:
        # Validate preferred specialist exists and is a doctor
        if data.preferred_specialist_id:
            specialist = self.user_repo.get_by_id(data.preferred_specialist_id)
            if not specialist or specialist.role.value != "doctor":
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Preferred specialist not found or is not a doctor",
                )

        booking = Booking(
            client_id=client_id,
            mental_health_description=data.mental_health_description,
            consent_given=data.consent_given,
            consent_timestamp=datetime.now(timezone.utc),
            session_type=data.session_type,
            duration_minutes=data.duration_minutes,
            preferred_dates=json.dumps(data.preferred_dates),
            preferred_specialist_id=data.preferred_specialist_id,
            preferred_specialist_type=data.preferred_specialist_type,
            physical_location_address=data.physical_location_address,
            physical_location_lat=data.physical_location_lat,
            physical_location_lng=data.physical_location_lng,
            physical_venue=data.physical_venue,
            physical_notes=data.physical_notes,
        )
        booking = self.repo.create(booking)

        # Create the linked session right away (admin will schedule it).
        if data.session_type == SessionType.physical:
            session = SessionModel(
                booking_id=booking.id,
                client_id=client_id,
                doctor_id=None,
                status=SessionStatus.requested,
            )
        else:
            session = SessionModel(
                booking_id=booking.id,
                client_id=client_id,
                doctor_id=data.preferred_specialist_id,
                status=SessionStatus.pending,
            )
        self.session_repo.create(session)

        # Ensure a payment record exists so the client can submit proof immediately.
        # (Admin later confirms and schedules.)
        from app.models.payment import Payment, PaymentType

        existing_payment = self.payment_repo.get_by_session(session.id)
        if not existing_payment:
            amount = None
            payment_type = PaymentType.negotiated if data.session_type == SessionType.physical else PaymentType.fixed
            if payment_type == PaymentType.fixed:
                # Default pricing rule used across the app.
                amount = 20000.0 if int(data.duration_minutes) == 30 else 30000.0
            self.payment_repo.create(
                Payment(
                    session_id=session.id,
                    amount=amount,
                    payment_type=payment_type,
                    instructions_text=(
                        "Submit payment proof after paying via Mobile Money / Bank. "
                        "Admin will confirm and schedule your appointment."
                    ),
                )
            )

        from app.services.chat_service import ChatService

        ChatService(self.db).ensure_session_conversation(session.id)
        return booking

    def get_booking(self, booking_id: str) -> Booking:
        booking = self.repo.get_by_id(booking_id)
        if not booking:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Booking not found")
        return booking

    def list_bookings_for_client(self, client_id: str) -> list[Booking]:
        return self.repo.get_by_client(client_id)

    def list_all_bookings(self) -> list[Booking]:
        return self.repo.get_all()

    def cancel_booking(self, booking_id: str, client_id: str) -> Booking:
        booking = self.get_booking(booking_id)
        if booking.client_id != client_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your booking")
        if booking.status == BookingStatus.cancelled:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Booking already cancelled")
        booking.status = BookingStatus.cancelled
        booking = self.repo.update(booking)
        sess = self.session_repo.get_by_booking(booking_id)
        if sess:
            sess.status = SessionStatus.cancelled
            self.session_repo.update(sess)
        return booking

    def request_reschedule(self, booking_id: str, client_id: str, data: BookingRescheduleRequest) -> Booking:
        booking = self.get_booking(booking_id)
        if booking.client_id != client_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your booking")
        if booking.status == BookingStatus.cancelled:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cancelled booking cannot be rescheduled")
        booking.reschedule_request_dates = json.dumps(data.preferred_dates)
        booking.reschedule_request_note = (data.note or "").strip() or None
        booking.reschedule_requested_at = datetime.now(timezone.utc)
        return self.repo.update(booking)
