"""
Import models to register them with SQLAlchemy metadata.

This module exists to avoid circular imports between `app.db.base` and models.
"""

from app.models.user import User  # noqa: F401
from app.models.booking import Booking  # noqa: F401
from app.models.session import Session  # noqa: F401
from app.models.payment import Payment  # noqa: F401
from app.models.feedback import Feedback  # noqa: F401
from app.models.transfer_log import TransferLog  # noqa: F401
from app.models.chat import Conversation, ChatMessage  # noqa: F401
from app.models.patient_transfer_request import PatientTransferRequest  # noqa: F401
from app.models.doctor_unavailability import (  # noqa: F401
    DoctorUnavailabilityBlock,
    UnavailabilitySessionImpact,
)

