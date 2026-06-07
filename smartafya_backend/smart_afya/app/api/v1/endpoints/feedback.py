from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user, require_admin, require_client
from app.db.session import get_db
from app.models.user import User
from app.schemas.feedback import FeedbackCreate, FeedbackOut
from app.services.feedback_service import FeedbackService

router = APIRouter(prefix="/feedback", tags=["Feedback"])


@router.post("/", response_model=FeedbackOut, status_code=201)
def submit_feedback(
    data: FeedbackCreate,
    current_user: User = Depends(require_client),
    db: Session = Depends(get_db),
):
    """
    Client submits feedback after a completed session.
    Includes treatment rating, doctor feedback, app rating, and suggestions.

    **Request body example:**
    ```json
    {
      "session_id": "<uuid>",
      "treatment_rating": 5,
      "doctor_feedback": "Very professional and empathetic.",
      "app_rating": 4,
      "app_feedback": "Smooth experience, could use dark mode.",
      "suggestions": "Add in-app messaging between sessions."
    }
    ```
    """
    svc = FeedbackService(db)
    return svc.submit_feedback(client_id=current_user.id, data=data)


@router.get("/my", response_model=list[FeedbackOut])
def my_feedback(current_user: User = Depends(require_client), db: Session = Depends(get_db)):
    """Client: list all feedback I've submitted."""
    svc = FeedbackService(db)
    return svc.list_for_client(current_user.id)


@router.get("/", response_model=list[FeedbackOut], dependencies=[Depends(require_admin)])
def list_all_feedback(db: Session = Depends(get_db)):
    """Admin: view all feedback (read-only — cannot edit or delete)."""
    svc = FeedbackService(db)
    return svc.list_all()


@router.get("/{feedback_id}", response_model=FeedbackOut)
def get_feedback(
    feedback_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get a specific feedback record."""
    svc = FeedbackService(db)
    return svc.get_feedback(feedback_id)
