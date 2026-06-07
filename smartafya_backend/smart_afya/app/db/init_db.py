from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import hash_password
from app.models.user import User, UserRole


def _sqlite_add_columns(db: Session, table: str, columns: list[tuple[str, str]]) -> None:
    bind = db.get_bind()
    if bind.dialect.name != "sqlite":
        return
    existing = {row[1] for row in db.execute(text(f"PRAGMA table_info({table})")).fetchall()}
    for name, ddl in columns:
        if name not in existing:
            db.execute(text(f"ALTER TABLE {table} ADD COLUMN {name} {ddl}"))
    db.commit()


def _ensure_user_schema(db: Session) -> None:
    bind = db.get_bind()
    dialect = bind.dialect.name

    if dialect == "sqlite":
        cols = {row[1] for row in db.execute(text("PRAGMA table_info(users)")).fetchall()}
        if "is_verified" not in cols:
            db.execute(text("ALTER TABLE users ADD COLUMN is_verified BOOLEAN NOT NULL DEFAULT 1"))
            db.commit()

    _sqlite_add_columns(
        db,
        "users",
        [
            ("base_latitude", "FLOAT"),
            ("base_longitude", "FLOAT"),
        ],
    )


def _ensure_booking_session_payment_feedback_schema(db: Session) -> None:
    _sqlite_add_columns(
        db,
        "bookings",
        [
            ("physical_location_address", "TEXT"),
            ("physical_location_lat", "FLOAT"),
            ("physical_location_lng", "FLOAT"),
            ("physical_venue", "TEXT"),
            ("physical_notes", "TEXT"),
            ("reschedule_request_dates", "TEXT"),
            ("reschedule_request_note", "TEXT"),
            ("reschedule_requested_at", "DATETIME"),
            ("preferred_specialist_type", "TEXT"),
        ],
    )
    _sqlite_add_columns(
        db,
        "sessions",
        [
            ("check_in_at", "DATETIME"),
            ("check_out_at", "DATETIME"),
        ],
    )
    _sqlite_add_columns(
        db,
        "payments",
        [
            ("instructions_text", "TEXT"),
            ("proof_submitted_at", "DATETIME"),
            ("proof_attachment", "TEXT"),
            ("proof_filename", "TEXT"),
            ("confirmed_at", "DATETIME"),
        ],
    )
    _sqlite_add_columns(
        db,
        "feedback",
        [
            ("family_rating", "INTEGER"),
            ("family_comments", "TEXT"),
        ],
    )


def seed_admin(db: Session) -> None:
    """Seed a default admin account (env: ADMIN_*)."""
    existing = db.query(User).filter(User.email == settings.ADMIN_EMAIL).first()
    if existing:
        return
    admin = User(
        full_name=settings.ADMIN_FULL_NAME,
        email=settings.ADMIN_EMAIL,
        hashed_password=hash_password(settings.ADMIN_PASSWORD),
        role=UserRole.admin,
        is_verified=True,
        is_active=True,
    )
    db.add(admin)
    db.commit()


def create_tables_and_seed() -> None:
    from app.db.base import Base
    from app.db.session import engine, SessionLocal
    import app.db.models  # noqa: F401

    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        _ensure_user_schema(db)
        _ensure_booking_session_payment_feedback_schema(db)
        seed_admin(db)
    finally:
        db.close()
