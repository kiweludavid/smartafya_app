import uuid
from datetime import datetime, timezone

from sqlalchemy import DateTime, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class TransferLog(Base):
    __tablename__ = "transfer_logs"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    session_id: Mapped[str] = mapped_column(String, ForeignKey("sessions.id"), nullable=False, index=True)
    from_doctor_id: Mapped[str] = mapped_column(String, ForeignKey("users.id"), nullable=False, index=True)
    to_doctor_id: Mapped[str] = mapped_column(String, ForeignKey("users.id"), nullable=False, index=True)
    reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    transferred_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    # relationships
    session = relationship("Session", back_populates="transfer_logs")
    from_doctor = relationship("User", foreign_keys=[from_doctor_id], back_populates="transfers_from")
    to_doctor = relationship("User", foreign_keys=[to_doctor_id], back_populates="transfers_to")
