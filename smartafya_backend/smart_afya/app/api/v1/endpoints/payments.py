from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user, require_admin, require_client
from app.db.session import get_db
from app.models.user import User, UserRole
from app.schemas.payment import PaymentCreate, PaymentOut, PaymentProofSubmit, PaymentUpdate
from app.services.payment_service import PaymentService

router = APIRouter(prefix="/payments", tags=["Payments"])


@router.post("/", response_model=PaymentOut, status_code=201, dependencies=[Depends(require_admin)])
def create_payment(data: PaymentCreate, db: Session = Depends(get_db)):
    """
    Admin creates a payment record for a session.
    For physical sessions the amount may be null (negotiated manually).

    **Request body example:**
    ```json
    {
      "session_id": "<uuid>",
      "amount": 50000,
      "payment_type": "fixed",
      "reference": null
    }
    ```
    """
    svc = PaymentService(db)
    return svc.create_payment(data)


@router.patch("/{payment_id}", response_model=PaymentOut, dependencies=[Depends(require_admin)])
def update_payment(payment_id: str, data: PaymentUpdate, db: Session = Depends(get_db)):
    """Admin updates payment amount, status, or reference."""
    svc = PaymentService(db)
    return svc.update_payment(payment_id, data)


@router.get("/session/{session_id}", response_model=PaymentOut)
def get_payment_by_session(
    session_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get payment details for a specific session (client or assigned doctor)."""
    svc = PaymentService(db)
    return svc.get_payment_by_session(session_id, current_user)


@router.patch("/{payment_id}/proof", response_model=PaymentOut)
def submit_payment_proof(
    payment_id: str,
    data: PaymentProofSubmit,
    current_user: User = Depends(require_client),
    db: Session = Depends(get_db),
):
    """Client uploads payment proof (base64)."""
    svc = PaymentService(db)
    return svc.submit_proof(payment_id, current_user.id, data)


@router.get("/{payment_id}", response_model=PaymentOut)
def get_payment(
    payment_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get a payment record by ID."""
    svc = PaymentService(db)
    return svc.get_payment(payment_id)


@router.get("/", response_model=list[PaymentOut], dependencies=[Depends(require_admin)])
def list_payments(db: Session = Depends(get_db)):
    """Admin: list all payments."""
    svc = PaymentService(db)
    return svc.list_all()
