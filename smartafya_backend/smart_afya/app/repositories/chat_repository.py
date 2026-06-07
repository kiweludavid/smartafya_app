from sqlalchemy.orm import Session as DBSession

from app.models.chat import ChatMessage, Conversation, ConversationType


class ChatRepository:
    def __init__(self, db: DBSession):
        self.db = db

    def get_conversation(self, conversation_id: str) -> Conversation | None:
        return self.db.query(Conversation).filter(Conversation.id == conversation_id).first()

    def get_by_session_id(self, session_id: str) -> Conversation | None:
        return self.db.query(Conversation).filter(Conversation.session_id == session_id).first()

    def get_admin_for_client(self, client_id: str) -> Conversation | None:
        return (
            self.db.query(Conversation)
            .filter(
                Conversation.type == ConversationType.admin_client,
                Conversation.client_id == client_id,
            )
            .first()
        )

    def list_messages(self, conversation_id: str, limit: int = 100) -> list[ChatMessage]:
        return (
            self.db.query(ChatMessage)
            .filter(ChatMessage.conversation_id == conversation_id)
            .order_by(ChatMessage.created_at.asc())
            .limit(limit)
            .all()
        )

    def create_conversation(self, c: Conversation) -> Conversation:
        self.db.add(c)
        self.db.commit()
        self.db.refresh(c)
        return c

    def update_conversation(self, c: Conversation) -> Conversation:
        self.db.commit()
        self.db.refresh(c)
        return c

    def create_message(self, m: ChatMessage) -> ChatMessage:
        self.db.add(m)
        self.db.commit()
        self.db.refresh(m)
        return m

    def list_session_conversations_for_client(self, client_id: str) -> list[Conversation]:
        return (
            self.db.query(Conversation)
            .filter(
                Conversation.type == ConversationType.session_thread,
                Conversation.client_id == client_id,
            )
            .order_by(Conversation.updated_at.desc())
            .all()
        )

    def list_session_conversations_for_doctor(self, doctor_id: str) -> list[Conversation]:
        from app.models.session import Session

        return (
            self.db.query(Conversation)
            .join(Session, Conversation.session_id == Session.id)
            .filter(
                Conversation.type == ConversationType.session_thread,
                Session.doctor_id == doctor_id,
            )
            .order_by(Conversation.updated_at.desc())
            .all()
        )

    def list_admin_conversations(self) -> list[Conversation]:
        return (
            self.db.query(Conversation)
            .filter(Conversation.type == ConversationType.admin_client)
            .order_by(Conversation.updated_at.desc())
            .all()
        )
