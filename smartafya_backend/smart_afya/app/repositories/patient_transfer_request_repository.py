from sqlalchemy.orm import Session as DBSession

from app.models.patient_transfer_request import PatientTransferRequest, PatientTransferRequestStatus


class PatientTransferRequestRepository:
    def __init__(self, db: DBSession):
        self.db = db

    def get_by_id(self, request_id: str) -> PatientTransferRequest | None:
        return self.db.query(PatientTransferRequest).filter(PatientTransferRequest.id == request_id).first()

    def get_pending_for_session(self, session_id: str) -> PatientTransferRequest | None:
        return (
            self.db.query(PatientTransferRequest)
            .filter(
                PatientTransferRequest.session_id == session_id,
                PatientTransferRequest.status == PatientTransferRequestStatus.requested,
            )
            .order_by(PatientTransferRequest.created_at.desc())
            .first()
        )

    def list_pending_for_client(self, client_id: str) -> list[PatientTransferRequest]:
        from app.models.session import Session as CareSession

        return (
            self.db.query(PatientTransferRequest)
            .join(CareSession, PatientTransferRequest.session_id == CareSession.id)
            .filter(
                CareSession.client_id == client_id,
                PatientTransferRequest.status == PatientTransferRequestStatus.requested,
            )
            .order_by(PatientTransferRequest.created_at.desc())
            .all()
        )

    def list_all_requested(self) -> list[PatientTransferRequest]:
        return (
            self.db.query(PatientTransferRequest)
            .filter(PatientTransferRequest.status == PatientTransferRequestStatus.requested)
            .order_by(PatientTransferRequest.created_at.desc())
            .all()
        )

    def create(self, row: PatientTransferRequest) -> PatientTransferRequest:
        self.db.add(row)
        self.db.commit()
        self.db.refresh(row)
        return row

    def update(self, row: PatientTransferRequest) -> PatientTransferRequest:
        self.db.commit()
        self.db.refresh(row)
        return row
