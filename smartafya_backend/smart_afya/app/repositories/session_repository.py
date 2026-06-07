from sqlalchemy.orm import Session as DBSession

from app.models.session import Session, SessionStatus


class SessionRepository:
    def __init__(self, db: DBSession):
        self.db = db

    def get_by_id(self, session_id: str) -> Session | None:
        return self.db.query(Session).filter(Session.id == session_id).first()

    def get_by_booking(self, booking_id: str) -> Session | None:
        return self.db.query(Session).filter(Session.booking_id == booking_id).first()

    def get_by_client(self, client_id: str) -> list[Session]:
        return self.db.query(Session).filter(Session.client_id == client_id).all()

    def get_by_doctor(self, doctor_id: str) -> list[Session]:
        return self.db.query(Session).filter(Session.doctor_id == doctor_id).all()

    def get_all(self, skip: int = 0, limit: int = 100) -> list[Session]:
        return self.db.query(Session).offset(skip).limit(limit).all()

    def create(self, session: Session) -> Session:
        self.db.add(session)
        self.db.commit()
        self.db.refresh(session)
        return session

    def update(self, session: Session) -> Session:
        self.db.commit()
        self.db.refresh(session)
        return session
