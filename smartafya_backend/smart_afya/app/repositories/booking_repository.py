from sqlalchemy.orm import Session

from app.models.booking import Booking


class BookingRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_by_id(self, booking_id: str) -> Booking | None:
        return self.db.query(Booking).filter(Booking.id == booking_id).first()

    def get_by_client(self, client_id: str) -> list[Booking]:
        return self.db.query(Booking).filter(Booking.client_id == client_id).all()

    def get_all(self, skip: int = 0, limit: int = 100) -> list[Booking]:
        return self.db.query(Booking).offset(skip).limit(limit).all()

    def create(self, booking: Booking) -> Booking:
        self.db.add(booking)
        self.db.commit()
        self.db.refresh(booking)
        return booking

    def update(self, booking: Booking) -> Booking:
        self.db.commit()
        self.db.refresh(booking)
        return booking
