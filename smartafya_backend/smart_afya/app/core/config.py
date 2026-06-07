from pydantic_settings import BaseSettings, SettingsConfigDict
from functools import lru_cache


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    APP_NAME: str = "Smart Afya Solution"
    APP_ENV: str = "development"
    DEBUG: bool = True

    # Dev-only: allow creating doctor accounts from public registration.
    # Keep this False in production.
    ALLOW_DOCTOR_SELF_SIGNUP: bool = True

    SECRET_KEY: str = "change-me-to-a-long-random-secret-key-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60

    DATABASE_URL: str = "sqlite:///./smart_afya.db"

    ADMIN_EMAIL: str = "admin@smartafya.com"
    ADMIN_PASSWORD: str = "Admin@1234"
    ADMIN_FULL_NAME: str = "System Admin"


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
