from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.feedback import Feedback
from app.repositories.feedback_repository import FeedbackRepository
from app.repositories.session_repository import SessionRepository
from app.schemas.feedback import FeedbackCreate


class FeedbackService:
    def __init__(self, db: Session):
        self.repo = FeedbackRepository(db)
        self.session_repo = SessionRepository(db)

    def submit_feedback(self, client_id: str, data: FeedbackCreate) -> Feedback:
        session = self.session_repo.get_by_id(data.session_id)
        if not session:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")
        if session.client_id != client_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your session")
        if self.repo.get_by_session(data.session_id):
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Feedback already submitted for this session")

        feedback = Feedback(
            session_id=data.session_id,
            client_id=client_id,
            treatment_rating=data.treatment_rating,
            doctor_feedback=data.doctor_feedback,
            app_rating=data.app_rating,
            app_feedback=data.app_feedback,
            suggestions=data.suggestions,
            family_rating=data.family_rating,
            family_comments=data.family_comments,
        )
        return self.repo.create(feedback)

    def get_feedback(self, feedback_id: str) -> Feedback:
        f = self.repo.get_by_id(feedback_id)
        if not f:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Feedback not found")
        return f

    def list_all(self) -> list[Feedback]:
        return self.repo.get_all()

    def list_for_client(self, client_id: str) -> list[Feedback]:
        return self.repo.get_by_client(client_id)
