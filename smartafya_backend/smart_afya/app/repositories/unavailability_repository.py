from sqlalchemy.orm import Session as DBSession

from app.models.doctor_unavailability import (
    DoctorUnavailabilityBlock,
    UnavailabilityImpactStatus,
    UnavailabilitySessionImpact,
)


class UnavailabilityRepository:
    def __init__(self, db: DBSession):
        self.db = db

    def create_block(self, block: DoctorUnavailabilityBlock) -> DoctorUnavailabilityBlock:
        self.db.add(block)
        self.db.commit()
        self.db.refresh(block)
        return block

    def save_block_with_impacts(
        self, block: DoctorUnavailabilityBlock, impacts: list[UnavailabilitySessionImpact]
    ) -> DoctorUnavailabilityBlock:
        self.db.add(block)
        self.db.flush()
        for imp in impacts:
            imp.block_id = block.id
            self.db.add(imp)
        self.db.commit()
        self.db.refresh(block)
        return block

    def create_impact(self, impact: UnavailabilitySessionImpact) -> UnavailabilitySessionImpact:
        self.db.add(impact)
        self.db.commit()
        self.db.refresh(impact)
        return impact

    def get_impact_by_id(self, impact_id: str) -> UnavailabilitySessionImpact | None:
        return self.db.query(UnavailabilitySessionImpact).filter(UnavailabilitySessionImpact.id == impact_id).first()

    def list_awaiting_for_client(self, client_id: str) -> list[UnavailabilitySessionImpact]:
        from app.models.session import Session as CareSession

        return (
            self.db.query(UnavailabilitySessionImpact)
            .join(CareSession, UnavailabilitySessionImpact.session_id == CareSession.id)
            .filter(
                CareSession.client_id == client_id,
                UnavailabilitySessionImpact.status == UnavailabilityImpactStatus.awaiting_patient,
            )
            .order_by(UnavailabilitySessionImpact.created_at.desc())
            .all()
        )

    def update_impact(self, impact: UnavailabilitySessionImpact) -> UnavailabilitySessionImpact:
        self.db.commit()
        self.db.refresh(impact)
        return impact

    def list_all_awaiting(self) -> list[UnavailabilitySessionImpact]:
        return (
            self.db.query(UnavailabilitySessionImpact)
            .filter(UnavailabilitySessionImpact.status == UnavailabilityImpactStatus.awaiting_patient)
            .order_by(UnavailabilitySessionImpact.created_at.desc())
            .all()
        )
