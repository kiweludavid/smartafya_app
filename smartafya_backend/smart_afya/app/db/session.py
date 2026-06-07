from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session

from app.core.config import settings

connect_args = {}
if settings.DATABASE_URL.startswith("sqlite"):
    connect_args = {"check_same_thread": False}

engine = create_engine(settings.DATABASE_URL, connect_args=connect_args, echo=settings.DEBUG)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Ensure every model is registered before any query (relationship string resolution).
import app.db.models  # noqa: E402, F401


def get_db():
    db: Session = SessionLocal()
    try:
        yield db
    finally:
        db.close()
