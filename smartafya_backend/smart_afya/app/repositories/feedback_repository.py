from sqlalchemy.orm import Session

from app.models.feedback import Feedback


class FeedbackRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_by_id(self, feedback_id: str) -> Feedback | None:
        return self.db.query(Feedback).filter(Feedback.id == feedback_id).first()

    def get_by_session(self, session_id: str) -> Feedback | None:
        return self.db.query(Feedback).filter(Feedback.session_id == session_id).first()

    def get_by_client(self, client_id: str) -> list[Feedback]:
        return self.db.query(Feedback).filter(Feedback.client_id == client_id).all()

    def get_all(self, skip: int = 0, limit: int = 100) -> list[Feedback]:
        return self.db.query(Feedback).offset(skip).limit(limit).all()

    def create(self, feedback: Feedback) -> Feedback:
        self.db.add(feedback)
        self.db.commit()
        self.db.refresh(feedback)
        return feedback
