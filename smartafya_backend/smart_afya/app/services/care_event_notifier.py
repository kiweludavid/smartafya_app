from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy.orm import Session as DBSession

from app.models.chat import ChatMessage, Conversation
from app.repositories.chat_repository import ChatRepository
from app.repositories.user_repository import UserRepository
from app.services.chat_service import ChatService


class CareEventNotifier:
    """
    Internal helper to emit "automatic messages" into chat threads.

    - Session thread: doctor ↔ patient
    - Admin thread: admin ↔ patient (operational events)
    """

    def __init__(self, db: DBSession):
        self.db = db
        self.chat_repo = ChatRepository(db)
        self.chat_svc = ChatService(db)
        self.user_repo = UserRepository(db)

    def _post_message(self, conv: Conversation, sender_id: str, body: str) -> None:
        text = (body or "").strip()
        if not text:
            return
        msg = ChatMessage(conversation_id=conv.id, sender_id=sender_id, body=text)
        self.db.add(msg)
        now = datetime.now(timezone.utc)
        conv.last_message_at = now
        conv.last_message_preview = text[:180] + ("…" if len(text) > 180 else "")
        self.db.add(conv)
        self.db.commit()

    def _admin_sender_id(self) -> str | None:
        admin = self.user_repo.get_first_admin()
        return admin.id if admin else None

    def notify_admin(self, client_id: str, body: str) -> None:
        admin_id = self._admin_sender_id()
        if not admin_id:
            return
        conv = self.chat_svc.ensure_admin_conversation(client_id)
        self._post_message(conv, sender_id=admin_id, body=body)

    def notify_session(self, session_id: str, sender_id: str, body: str) -> None:
        conv = self.chat_svc.ensure_session_conversation(session_id)
        self._post_message(conv, sender_id=sender_id, body=body)

