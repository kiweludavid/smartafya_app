from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.schemas.token import Token
from app.schemas.user import UserLogin
from app.services.auth_service import AuthService

router = APIRouter(prefix="/admin", tags=["Admin"])


@router.post("/login", response_model=Token)
def admin_login(data: UserLogin, db: Session = Depends(get_db)):
    """
    Admin-only login endpoint.
    """
    svc = AuthService(db)
    return svc.admin_login(data)

