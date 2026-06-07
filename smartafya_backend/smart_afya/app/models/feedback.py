import uuid
from datetime import datetime, timezone

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class Feedback(Base):
    __tablename__ = "feedback"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    session_id: Mapped[str] = mapped_column(String, ForeignKey("sessions.id"), nullable=False, unique=True, index=True)
    client_id: Mapped[str] = mapped_column(String, ForeignKey("users.id"), nullable=False, index=True)

    # Treatment / doctor performance
    treatment_rating: Mapped[int | None] = mapped_column(Integer, nullable=True)   # 1-5
    doctor_feedback: Mapped[str | None] = mapped_column(Text, nullable=True)

    # App UX feedback
    app_rating: Mapped[int | None] = mapped_column(Integer, nullable=True)         # 1-5
    app_feedback: Mapped[str | None] = mapped_column(Text, nullable=True)

    # General / extensible
    suggestions: Mapped[str | None] = mapped_column(Text, nullable=True)

    family_rating: Mapped[int | None] = mapped_column(Integer, nullable=True)
    family_comments: Mapped[str | None] = mapped_column(Text, nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    # relationships
    session = relationship("Session", back_populates="feedback")
    client = relationship("User", back_populates="feedbacks")
