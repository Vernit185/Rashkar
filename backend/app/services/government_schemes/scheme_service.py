"""Government Schemes — service for listing, searching, filtering, CRUD and seeding."""
import uuid
import logging
from datetime import datetime
from typing import Optional, List
from sqlalchemy import or_
from sqlalchemy.orm import Session

from cropnet.services.api.app.models.government_schemes import GovernmentSchemeModel
from cropnet.services.api.app.schemas.government_scheme import (
    GovernmentSchemeCreate,
    GovernmentSchemeUpdate,
    SCHEME_CATEGORIES,
    SCHEME_STATUSES,
    VERIFICATION_STATUSES,
)
from cropnet.services.api.app.services.government_schemes.seed_data import (
    SEED_SCHEMES,
    VERIFIED_AS_OF,
)

logger = logging.getLogger(__name__)


class GovernmentSchemesService:
    """Queries and mutations for the government_schemes reference table."""

    @staticmethod
    def list_schemes(
        db: Session,
        search: Optional[str] = None,
        category: Optional[str] = None,
        government_level: Optional[str] = None,
        state: Optional[str] = None,
        status: Optional[str] = None,
        verification_status: Optional[str] = None,
        skip: int = 0,
        limit: int = 50,
    ) -> List[GovernmentSchemeModel]:
        query = db.query(GovernmentSchemeModel)

        if search and search.strip():
            term = f"%{search.strip()}%"
            query = query.filter(
                or_(
                    GovernmentSchemeModel.scheme_name.ilike(term),
                    GovernmentSchemeModel.description.ilike(term),
                    GovernmentSchemeModel.department.ilike(term),
                )
            )
        if category:
            query = query.filter(GovernmentSchemeModel.category == category)
        if government_level:
            query = query.filter(GovernmentSchemeModel.government_level == government_level)
        if state:
            query = query.filter(GovernmentSchemeModel.state == state)
        if status:
            query = query.filter(GovernmentSchemeModel.status == status)
        if verification_status:
            query = query.filter(GovernmentSchemeModel.verification_status == verification_status)

        return (
            query.order_by(GovernmentSchemeModel.scheme_name.asc())
            .offset(skip)
            .limit(limit)
            .all()
        )

    @staticmethod
    def get_scheme(db: Session, scheme_id: str) -> Optional[GovernmentSchemeModel]:
        return db.query(GovernmentSchemeModel).filter(GovernmentSchemeModel.id == scheme_id).first()

    @staticmethod
    def create_scheme(db: Session, payload: GovernmentSchemeCreate) -> GovernmentSchemeModel:
        scheme = GovernmentSchemeModel(
            id=str(uuid.uuid4()),
            **payload.model_dump(),
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow(),
        )
        db.add(scheme)
        db.commit()
        db.refresh(scheme)
        return scheme

    @staticmethod
    def update_scheme(
        db: Session, scheme: GovernmentSchemeModel, payload: GovernmentSchemeUpdate
    ) -> GovernmentSchemeModel:
        updates = payload.model_dump(exclude_unset=True)
        for field, value in updates.items():
            setattr(scheme, field, value)
        scheme.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(scheme)
        return scheme

    @staticmethod
    def set_status(
        db: Session,
        scheme: GovernmentSchemeModel,
        status: Optional[str] = None,
        verification_status: Optional[str] = None,
    ) -> GovernmentSchemeModel:
        """Publish / deactivate / verify a scheme via status mutation."""
        if status:
            if status not in SCHEME_STATUSES:
                raise ValueError(f"Invalid status '{status}'. Allowed: {SCHEME_STATUSES}")
            scheme.status = status
        if verification_status:
            if verification_status not in VERIFICATION_STATUSES:
                raise ValueError(
                    f"Invalid verification_status '{verification_status}'. Allowed: {VERIFICATION_STATUSES}"
                )
            scheme.verification_status = verification_status
            scheme.last_verified_date = datetime.utcnow()
        scheme.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(scheme)
        return scheme

    @staticmethod
    def delete_scheme(db: Session, scheme: GovernmentSchemeModel) -> None:
        db.delete(scheme)
        db.commit()

    @staticmethod
    def seed(db: Session) -> int:
        """Insert seed records that are not already present (idempotent by scheme name)."""
        existing_names = {
            name for (name,) in db.query(GovernmentSchemeModel.scheme_name).all()
        }
        created = 0
        for record in SEED_SCHEMES:
            if record["scheme_name"] in existing_names:
                continue
            db.add(
                GovernmentSchemeModel(
                    id=str(uuid.uuid4()),
                    last_verified_date=VERIFIED_AS_OF,
                    created_at=datetime.utcnow(),
                    updated_at=datetime.utcnow(),
                    **record,
                )
            )
            created += 1
        db.commit()
        logger.info("Seeded %s new government schemes (%s already present).", created, len(SEED_SCHEMES) - created)
        return created
