"""Government Schemes — Pydantic request/response schemas."""
from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel, Field


# Canonical scheme categories (kept stable for frontend filter chips).
SCHEME_CATEGORIES: List[str] = [
    "Crop Insurance",
    "Financial Assistance",
    "Loans",
    "Irrigation",
    "Soil Health",
    "Machinery",
    "Seeds & Fertilizers",
    "Infrastructure",
    "State Schemes",
]

SCHEME_STATUSES: List[str] = ["ACTIVE", "INACTIVE", "DRAFT"]
VERIFICATION_STATUSES: List[str] = ["VERIFIED", "NOT_VERIFIED", "PENDING_REVIEW"]
GOVERNMENT_LEVELS: List[str] = ["Central", "State"]


class GovernmentSchemeBase(BaseModel):
    scheme_name: str = Field(..., min_length=1, max_length=200)
    category: str = Field(..., max_length=50)
    government_level: str = Field(..., max_length=20)
    state: Optional[str] = Field(None, max_length=60)
    description: Optional[str] = None
    benefits: Optional[List[str]] = None
    eligibility: Optional[List[str]] = None
    required_documents: Optional[List[str]] = None
    application_steps: Optional[List[str]] = None
    department: Optional[str] = Field(None, max_length=200)
    application_url: Optional[str] = None
    source_url: Optional[str] = None
    status: str = Field("ACTIVE", max_length=30)
    verification_status: str = Field("VERIFIED", max_length=30)
    last_verified_date: Optional[datetime] = None


class GovernmentSchemeCreate(GovernmentSchemeBase):
    pass


class GovernmentSchemeUpdate(BaseModel):
    scheme_name: Optional[str] = Field(None, min_length=1, max_length=200)
    category: Optional[str] = Field(None, max_length=50)
    government_level: Optional[str] = Field(None, max_length=20)
    state: Optional[str] = Field(None, max_length=60)
    description: Optional[str] = None
    benefits: Optional[List[str]] = None
    eligibility: Optional[List[str]] = None
    required_documents: Optional[List[str]] = None
    application_steps: Optional[List[str]] = None
    department: Optional[str] = Field(None, max_length=200)
    application_url: Optional[str] = None
    source_url: Optional[str] = None
    status: Optional[str] = Field(None, max_length=30)
    verification_status: Optional[str] = Field(None, max_length=30)
    last_verified_date: Optional[datetime] = None


class GovernmentSchemeResponse(GovernmentSchemeBase):
    id: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class GovernmentSchemeSummary(BaseModel):
    id: str
    scheme_name: str
    category: str
    government_level: str
    state: Optional[str] = None
    status: str
    verification_status: str
    description: Optional[str] = None
    department: Optional[str] = None

    model_config = {"from_attributes": True}


class SchemeFilterOptions(BaseModel):
    categories: List[str] = SCHEME_CATEGORIES
    government_levels: List[str] = GOVERNMENT_LEVELS
    states: List[str] = []
    statuses: List[str] = SCHEME_STATUSES
    verification_statuses: List[str] = VERIFICATION_STATUSES
