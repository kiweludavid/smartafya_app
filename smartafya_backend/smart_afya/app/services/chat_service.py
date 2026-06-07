from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, status
from sqlalchemy.orm import Session as DBSession

from app.models.booking import Booking
from app.models.chat import ChatMessage, Conversation, ConversationType
from app.models.session import Session as SessionModel, SessionStatus
from app.models.user import User, UserRole
from app.repositories.booking_repository import BookingRepository
from app.repositories.chat_repository import ChatRepository
from app.repositories.session_repository import SessionRepository
from app.repositories.user_repository import UserRepository
from app.schemas.chat import ChatMessageCreate, ChatMessageOut, ConversationKind, ConversationListItem


def _compute_session_expiry(session: SessionModel, booking: Booking | None) -> datetime | None:
    now = datetime.now(timezone.utc)
    if session.status == SessionStatus.cancelled:
        return now
    if session.status == SessionStatus.completed:
        base = session.updated_at or now
        return base + timedelta(hours=24)
    if session.scheduled_at and booking:
        mins = booking.duration_minutes or 60
        session_end = session.scheduled_at + timedelta(minutes=mins)
        return session_end + timedelta(hours=48)
    return now + timedelta(days=14)


class ChatService:
    def __init__(self, db: DBSession):
        self.db = db
        self.repo = ChatRepository(db)
        self.session_repo = SessionRepository(db)
        self.booking_repo = BookingRepository(db)
        self.user_repo = UserRepository(db)

    def ensure_session_conversation(self, session_id: str) -> Conversation:
        existing = self.repo.get_by_session_id(session_id)
        if existing:
            self.refresh_session_conversation_expiry(session_id)
            return existing
        session = self.session_repo.get_by_id(session_id)
        if not session:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")
        booking = self.booking_repo.get_by_id(session.booking_id)
        exp = _compute_session_expiry(session, booking)
        conv = Conversation(
            type=ConversationType.session_thread,
            session_id=session_id,
            client_id=session.client_id,
            expires_at=exp,
        )
        return self.repo.create_conversation(conv)

    def refresh_session_conversation_expiry(self, session_id: str) -> None:
        conv = self.repo.get_by_session_id(session_id)
        if not conv:
            return
        session = self.session_repo.get_by_id(session_id)
        if not session:
            return
        booking = self.booking_repo.get_by_id(session.booking_id)
        conv.expires_at = _compute_session_expiry(session, booking)
        self.repo.update_conversation(conv)

    def ensure_admin_conversation(self, client_id: str) -> Conversation:
        existing = self.repo.get_admin_for_client(client_id)
        if existing:
            return existing
        conv = Conversation(
            type=ConversationType.admin_client,
            session_id=None,
            client_id=client_id,
            expires_at=None,
        )
        return self.repo.create_conversation(conv)

    def _user_display_name(self, user_id: str) -> str:
        u = self.user_repo.get_by_id(user_id)
        if not u:
            return "Member"
        name = (u.full_name or "").strip()
        return name if name else "Member"

    def _assert_conv_access(self, conv: Conversation, user: User) -> None:
        if user.role == UserRole.admin:
            if conv.type == ConversationType.admin_client:
                return
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admins use admin threads only")
        if conv.type == ConversationType.admin_client:
            if user.role == UserRole.client and conv.client_id == user.id:
                return
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your conversation")
        # session thread
        session = self.session_repo.get_by_id(conv.session_id) if conv.session_id else None
        if not session:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session missing")
        if user.role == UserRole.client and session.client_id == user.id:
            return
        if user.role == UserRole.doctor and session.doctor_id == user.id:
            return
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a participant")

    def _is_expired(self, conv: Conversation) -> bool:
        if conv.type == ConversationType.admin_client:
            return False
        if conv.expires_at is None:
            return False
        return datetime.now(timezone.utc) > conv.expires_at

    def _to_list_item(self, conv: Conversation, viewer: User) -> ConversationListItem:
        if conv.type == ConversationType.admin_client:
            title = "Care team (Admin)" if viewer.role == UserRole.client else self._user_display_name(conv.client_id)
            kind = ConversationKind.admin
            sid = None
        else:
            session = self.session_repo.get_by_id(conv.session_id) if conv.session_id else None
            if viewer.role == UserRole.client:
                title = (
                    self._user_display_name(session.doctor_id)
                    if session and session.doctor_id
                    else "Your specialist"
                )
            elif viewer.role == UserRole.doctor:
                title = self._user_display_name(session.client_id) if session else "Patient"
            else:
                title = "Session chat"
            kind = ConversationKind.session
            sid = conv.session_id
        expired = self._is_expired(conv)
        return ConversationListItem(
            id=conv.id,
            kind=kind,
            title=title,
            last_message_preview=conv.last_message_preview,
            last_message_at=conv.last_message_at,
            expires_at=conv.expires_at,
            is_expired=expired,
            session_id=sid,
        )

    def list_conversations(self, user: User) -> list[ConversationListItem]:
        items: list[ConversationListItem] = []
        if user.role == UserRole.client:
            for s in self.session_repo.get_by_client(user.id):
                self.ensure_session_conversation(s.id)
            self.ensure_admin_conversation(user.id)
            admin_c = self.repo.get_admin_for_client(user.id)
            if admin_c:
                items.append(self._to_list_item(admin_c, user))
            for c in self.repo.list_session_conversations_for_client(user.id):
                if c.session_id:
                    self.refresh_session_conversation_expiry(c.session_id)
                fresh = self.repo.get_conversation(c.id)
                if fresh:
                    items.append(self._to_list_item(fresh, user))
        elif user.role == UserRole.doctor:
            for s in self.session_repo.get_by_doctor(user.id):
                self.ensure_session_conversation(s.id)
            for c in self.repo.list_session_conversations_for_doctor(user.id):
                if c.session_id:
                    self.refresh_session_conversation_expiry(c.session_id)
                fresh = self.repo.get_conversation(c.id)
                if fresh:
                    items.append(self._to_list_item(fresh, user))
        elif user.role == UserRole.admin:
            for c in self.repo.list_admin_conversations():
                items.append(self._to_list_item(c, user))
        return items

    def list_messages(self, conversation_id: str, user: User) -> list[ChatMessageOut]:
        conv = self.repo.get_conversation(conversation_id)
        if not conv:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Conversation not found")
        self._assert_conv_access(conv, user)
        msgs = self.repo.list_messages(conversation_id, limit=200)
        return [ChatMessageOut.model_validate(m) for m in msgs]

    def send_message(self, conversation_id: str, user: User, data: ChatMessageCreate) -> ChatMessageOut:
        conv = self.repo.get_conversation(conversation_id)
        if not conv:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Conversation not found")
        self._assert_conv_access(conv, user)
        if conv.type == ConversationType.session_thread and self._is_expired(conv):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="This session chat has closed. Start a new booking if you need more help.",
            )
        body = data.body.strip()
        if not body:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Message cannot be empty")
        msg = ChatMessage(conversation_id=conv.id, sender_id=user.id, body=body)
        msg = self.repo.create_message(msg)
        now = datetime.now(timezone.utc)
        conv.last_message_at = now
        conv.last_message_preview = body[:180] + ("…" if len(body) > 180 else "")
        self.repo.update_conversation(conv)
        return ChatMessageOut.model_validate(msg)
