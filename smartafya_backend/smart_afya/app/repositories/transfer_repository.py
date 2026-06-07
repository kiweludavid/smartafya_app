from sqlalchemy.orm import Session

from app.models.transfer_log import TransferLog


class TransferRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_by_session(self, session_id: str) -> list[TransferLog]:
        return self.db.query(TransferLog).filter(TransferLog.session_id == session_id).all()

    def get_all(self, skip: int = 0, limit: int = 100) -> list[TransferLog]:
        return self.db.query(TransferLog).offset(skip).limit(limit).all()

    def create(self, log: TransferLog) -> TransferLog:
        self.db.add(log)
        self.db.commit()
        self.db.refresh(log)
        return log
