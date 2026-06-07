from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.chat import ChatMessageCreate, ChatMessageOut, ConversationListItem
from app.services.chat_service import ChatService

router = APIRouter(prefix="/chat", tags=["Chat"])


@router.get("/conversations", response_model=list[ConversationListItem])
def list_conversations(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """List chats: client sees coordination + session threads; doctor sees their session threads and all coordination threads."""
    svc = ChatService(db)
    return svc.list_conversations(current_user)


@router.get("/conversations/{conversation_id}/messages", response_model=list[ChatMessageOut])
def list_messages(
    conversation_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    svc = ChatService(db)
    return svc.list_messages(conversation_id, current_user)


@router.post("/conversations/{conversation_id}/messages", response_model=ChatMessageOut, status_code=201)
def send_message(
    conversation_id: str,
    data: ChatMessageCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    svc = ChatService(db)
    return svc.send_message(conversation_id, current_user, data)
