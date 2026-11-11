"""Government Schemes — FastAPI endpoints.

Public read access (list / search / filter / detail) mirrors the public crops
knowledge base. Write access (create / edit / verify / publish / deactivate /
seed) is restricted to administrators via `require_admin`.
"""
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session

from cropnet.services.api.app.core.database import get_db
from cropnet.services.api.app.core.security import get_current_user, require_admin, CurrentUser
from cropnet.services.api.app.models.government_schemes import GovernmentSchemeModel
from cropnet.services.api.app.schemas.government_scheme import (
    GovernmentSchemeCreate,
    GovernmentSchemeUpdate,
    GovernmentSchemeResponse,
    GovernmentSchemeSummary,
    SchemeFilterOptions,
    SCHEME_CATEGORIES,
)
from cropnet.services.api.app.services.government_schemes.scheme_service import GovernmentSchemesService

router = APIRouter()
scheme_service = GovernmentSchemesService()


@router.get("", response_model=List[GovernmentSchemeSummary])
async def list_schemes(
    search: Optional[str] = Query(None, description="Search across scheme name, description and department"),
    category: Optional[str] = Query(None, description="Scheme category"),
    government_level: Optional[str] = Query(None, description="Central | State"),
    state: Optional[str] = Query(None, description="State name (e.g. Maharashtra)"),
    status: Optional[str] = Query(None, description="ACTIVE | INACTIVE | DRAFT"),
    verification_status: Optional[str] = Query(None, description="VERIFIED | NOT_VERIFIED | PENDING_REVIEW"),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    db: Session = Depends(get_db),
):
    """List, search and filter Government Schemes."""
    schemes = scheme_service.list_schemes(
        db=db,
        search=search,
        category=category,
        government_level=government_level,
        state=state,
        status=status,
        verification_status=verification_status,
        skip=skip,
        limit=limit,
    )
    return [GovernmentSchemeSummary.model_validate(s) for s in schemes]


@router.get("/filters", response_model=SchemeFilterOptions)
async def list_scheme_filter_options(db: Session = Depends(get_db)):
    """Return available filter values (categories, levels, distinct states)."""
    states = [
        s for (s,) in db.query(GovernmentSchemeModel.state)
        .filter(GovernmentSchemeModel.state.isnot(None))
        .distinct()
        .all()
        if s
    ]
    return SchemeFilterOptions(states=sorted(states))


@router.get("/admin/status")
async def admin_status(current_user: CurrentUser = Depends(get_current_user)):
    """Report whether the authenticated user has Government Schemes admin rights."""
    return {"is_admin": current_user.is_admin}


@router.get("/{scheme_id}", response_model=GovernmentSchemeResponse)
async def get_scheme(scheme_id: str, db: Session = Depends(get_db)):
    """Retrieve a single Government Scheme by id."""
    scheme = scheme_service.get_scheme(db, scheme_id)
    if not scheme:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Scheme '{scheme_id}' not found")
    return GovernmentSchemeResponse.model_validate(scheme)


@router.post("", response_model=GovernmentSchemeResponse, status_code=status.HTTP_201_CREATED)
async def create_scheme(
    payload: GovernmentSchemeCreate,
    _admin: CurrentUser = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """Admin: create a new Government Scheme record."""
    if payload.category not in SCHEME_CATEGORIES:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Invalid category. Allowed: {SCHEME_CATEGORIES}",
        )
    return GovernmentSchemeResponse.model_validate(scheme_service.create_scheme(db, payload))


@router.put("/{scheme_id}", response_model=GovernmentSchemeResponse)
async def update_scheme(
    scheme_id: str,
    payload: GovernmentSchemeUpdate,
    _admin: CurrentUser = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """Admin: update an existing Government Scheme record."""
    scheme = scheme_service.get_scheme(db, scheme_id)
    if not scheme:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Scheme '{scheme_id}' not found")
    return GovernmentSchemeResponse.model_validate(scheme_service.update_scheme(db, scheme, payload))


@router.patch("/{scheme_id}/status", response_model=GovernmentSchemeResponse)
async def set_scheme_status(
    scheme_id: str,
    status: Optional[str] = Query(None),
    verification_status: Optional[str] = Query(None),
    _admin: CurrentUser = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """Admin: publish / deactivate / verify a scheme."""
    scheme = scheme_service.get_scheme(db, scheme_id)
    if not scheme:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Scheme '{scheme_id}' not found")
    try:
        updated = scheme_service.set_status(db, scheme, status=status, verification_status=verification_status)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc))
    return GovernmentSchemeResponse.model_validate(updated)


@router.delete("/{scheme_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_scheme(
    scheme_id: str,
    _admin: CurrentUser = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """Admin: delete a Government Scheme record."""
    scheme = scheme_service.get_scheme(db, scheme_id)
    if not scheme:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Scheme '{scheme_id}' not found")
    scheme_service.delete_scheme(db, scheme)
    return None


@router.post("/seed", status_code=status.HTTP_200_OK)
async def seed_schemes(
    _admin: CurrentUser = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """Admin: seed the verified Central Government and Maharashtra scheme records."""
    count = scheme_service.seed(db)
    return {
        "status": "success",
        "message": f"Seeded {count} new Government Scheme records.",
    }
