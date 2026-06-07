from fastapi import APIRouter

from app.api.v1.endpoints import (
    admin_auth,
    auth,
    bookings,
    care_actions,
    chat,
    feedback,
    payments,
    sessions,
    transfers,
    users,
)

api_router = APIRouter(prefix="/api/v1")

api_router.include_router(auth.router)
api_router.include_router(admin_auth.router)
api_router.include_router(users.router)
api_router.include_router(bookings.router)
api_router.include_router(sessions.router)
api_router.include_router(transfers.router)
api_router.include_router(care_actions.router)
api_router.include_router(payments.router)
api_router.include_router(feedback.router)
api_router.include_router(chat.router)
