from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.schemas.token import Token, AuthResponse
from app.schemas.user import UserRegister, UserLogin, UserOut
from app.services.auth_service import AuthService

router = APIRouter(prefix="/auth", tags=["Auth"])


@router.post("/register", response_model=AuthResponse, status_code=201)
def register(
    data: UserRegister,
    db: Session = Depends(get_db),
):
    """
    Register a new client or doctor account.

    **Request body example:**
    ```json
    {
      "full_name": "Jane Doe",
      "email": "jane@example.com",
      "phone": "+255700000000",
      "password": "Secret@123",
      "role": "client"
    }
    ```
    """
    svc = AuthService(db)
    return svc.register(data)


@router.post("/login", response_model=Token)
def login(data: UserLogin, db: Session = Depends(get_db)):
    """
    Authenticate and receive a JWT access token.

    **Request body example:**
    ```json
    {
      "email": "jane@example.com",
      "password": "Secret@123"
    }
    ```

    **Response example:**
    ```json
    {
      "access_token": "<jwt>",
      "token_type": "bearer"
    }
    ```
    """
    svc = AuthService(db)
    return svc.login(data)
