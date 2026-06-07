from pydantic import BaseModel


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


class TokenData(BaseModel):
    user_id: str | None = None


class AuthResponse(BaseModel):
    user_id: str
    email: str
    role: str
    access_token: str
    token_type: str = "bearer"
