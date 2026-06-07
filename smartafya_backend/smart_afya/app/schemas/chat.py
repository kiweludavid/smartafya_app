from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field


class ConversationKind(str, Enum):
    session = "session"
    admin = "admin"


class ConversationListItem(BaseModel):
    id: str
    kind: ConversationKind
    title: str
    last_message_preview: str | None
    last_message_at: datetime | None
    expires_at: datetime | None
    is_expired: bool
    session_id: str | None = None


class ChatMessageOut(BaseModel):
    model_config = {"from_attributes": True}

    id: str
    conversation_id: str
    sender_id: str
    body: str
    created_at: datetime


class ChatMessageCreate(BaseModel):
    body: str = Field(min_length=1, max_length=8000)
