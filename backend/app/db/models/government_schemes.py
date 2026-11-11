"""Government Schemes — SQLAlchemy models.

A single static reference table holding verified Central and State Government
agricultural schemes. Read access is public; write access is admin-only and is
enforced at the API layer (require_admin) and, on Supabase, via Row Level Security.
"""
import uuid
from datetime import datetime
from sqlalchemy import (
    Column, String, Integer, Boolean, DateTime, Text, JSON, Index
)

from cropnet.services.api.app.models.soil_and_farm import Base


class GovernmentSchemeModel(Base):
    """A government agricultural scheme record."""

    __tablename__ = "government_schemes"
    __table_args__ = (
        Index("ix_government_schemes_category_status", "category", "status"),
        Index("ix_government_schemes_level_state_status", "government_level", "state", "status"),
    )

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    scheme_name = Column(String(200), nullable=False, index=True)
    category = Column(String(50), nullable=False, index=True)
    government_level = Column(String(20), nullable=False, index=True)  # Central | State
    state = Column(String(60), nullable=True, index=True)  # null = all-India / central
    description = Column(Text, nullable=True)
    benefits = Column(JSON, nullable=True)              # list[str]
    eligibility = Column(JSON, nullable=True)           # list[str]
    required_documents = Column(JSON, nullable=True)    # list[str]
    application_steps = Column(JSON, nullable=True)     # list[str]
    department = Column(String(200), nullable=True)
    application_url = Column(Text, nullable=True)
    source_url = Column(Text, nullable=True)
    status = Column(String(30), nullable=False, default="ACTIVE", index=True)  # ACTIVE | INACTIVE | DRAFT
    verification_status = Column(String(30), nullable=False, default="VERIFIED", index=True)  # VERIFIED | NOT_VERIFIED | PENDING_REVIEW
    last_verified_date = Column(DateTime, nullable=True)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)
