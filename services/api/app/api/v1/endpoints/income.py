"""
Extra Income endpoints integrating Rashkar's complete personalized opportunity discovery,
multi-gate feasibility, 3-scenario financial engine, and saved plans into CropNet.
"""
import uuid
from typing import List, Optional, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from pydantic import BaseModel, Field

from cropnet.services.api.app.core.database import get_db
from cropnet.services.api.app.core.security import get_current_user, CurrentUser
from cropnet.services.api.app.api.v1.endpoints.farms import _get_farm_and_verify_owner
from cropnet.services.api.app.models.soil_and_farm import FarmModel as CropNetFarmModel
from cropnet.services.api.app.models.rashkar_profiles import SavedIncomePlanModel
from cropnet.services.api.app.schemas.rashkar.income import (
    OpportunityCatalogItem,
    FarmerResourceProfile,
    DiscoveredOpportunity,
    EnterpriseFinancialAnalysis,
    OpportunityComparisonItem,
    SavedIncomePlan,
)
from cropnet.services.api.app.schemas.rashkar.shared_profile import SharedResourceProfileDTO
from cropnet.services.api.app.services.rashkar.income_knowledge_catalog import (
    EXTENDED_OPPORTUNITY_CATALOG,
    get_opportunity_by_id,
)
from cropnet.services.api.app.services.rashkar.income_engine import IncomeEngine
from cropnet.services.api.app.services.rashkar.timezone import now_utc
from cropnet.services.api.app.services.rashkar.adapters import (
    MissingSharedContextError,
    build_shared_context_response,
    save_resource_profile_shared,
    build_income_engine_profile,
    get_or_link_farmer_for_user,
)

router = APIRouter()


class ScenarioCalculateRequest(BaseModel):
    opportunity_id: str
    custom_budget_inr: float = Field(default=0.0, ge=0.0)
    available_labour_hours_day: float = Field(default=2.0, ge=0.0, le=16.0)
    available_land_acres: float = Field(default=0.0, ge=0.0)
    water_availability: str = Field(default="seasonal_canal")
    custom_assumptions: Optional[Dict[str, Any]] = None


class CompareOpportunitiesRequest(BaseModel):
    opportunity_ids: List[str]
    custom_budget_inr: float = Field(default=25000.0, ge=0.0)


class SavePlanRequest(BaseModel):
    opportunity_id: str
    chosen_budget_inr: float = Field(default=0.0, ge=0.0)
    notes: Optional[str] = None


def _load_owned_farm(farm_id: uuid.UUID, current_user: CurrentUser, db: Session) -> CropNetFarmModel:
    _get_farm_and_verify_owner(farm_id, current_user, db)
    db_farm = db.query(CropNetFarmModel).filter(CropNetFarmModel.id == str(farm_id)).first()
    if not db_farm:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Farm {farm_id} not found")
    return db_farm


@router.get("/opportunities", response_model=List[OpportunityCatalogItem])
def get_opportunities(
    category: Optional[str] = Query(None, description="zero_cash, very_low_cost, moderate_enterprise, crop_diversification, group_external"),
    crop_code: Optional[str] = Query(None, description="Filter by crop context"),
    max_budget: Optional[float] = Query(None, description="Max budget in INR"),
):
    """Retrieve canonical diversification opportunities across all 5 tiers."""
    opps = EXTENDED_OPPORTUNITY_CATALOG
    if category and category != "all":
        opps = [o for o in opps if o.category == category]
    if crop_code and crop_code != "all":
        opps = [
            o for o in opps
            if not o.target_crops or "all" in o.target_crops or crop_code.lower() in [c.lower() for c in o.target_crops]
        ]
    if max_budget is not None:
        opps = [o for o in opps if o.min_investment_inr <= max_budget]
    return opps


@router.get("/opportunities/{opportunity_id}", response_model=OpportunityCatalogItem)
def get_single_opportunity(opportunity_id: str):
    opp = get_opportunity_by_id(opportunity_id)
    if not opp:
        raise HTTPException(status_code=404, detail=f"Opportunity with ID '{opportunity_id}' not found.")
    return opp


@router.post("/match-opportunities", response_model=List[DiscoveredOpportunity])
def match_opportunities_to_farmer(profile: FarmerResourceProfile):
    return IncomeEngine.match_opportunities(profile)


@router.post("/calculate-scenario", response_model=EnterpriseFinancialAnalysis)
def calculate_income_scenario(request: ScenarioCalculateRequest):
    opp = get_opportunity_by_id(request.opportunity_id)
    if not opp:
        raise HTTPException(status_code=404, detail=f"Opportunity with ID '{request.opportunity_id}' not found.")
    return IncomeEngine.calculate_enterprise_financials(
        opportunity_id=request.opportunity_id,
        custom_budget_inr=request.custom_budget_inr,
        water_availability=request.water_availability,
    )


@router.post("/compare-opportunities", response_model=List[OpportunityComparisonItem])
def compare_selected_opportunities(request: CompareOpportunitiesRequest):
    if not request.opportunity_ids:
        raise HTTPException(status_code=400, detail="Must provide at least one opportunity ID.")
    return IncomeEngine.compare_opportunities(request.opportunity_ids, request.custom_budget_inr)


@router.get("/farms/{farm_id}/profile", response_model=SharedResourceProfileDTO)
def get_farm_resource_profile(
    farm_id: uuid.UUID,
    current_user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Retrieve shared CropNet-prefilled resource profile without fabricating unknown fields."""
    db_farm = _load_owned_farm(farm_id, current_user, db)
    return build_shared_context_response(db=db, current_user=current_user, cropnet_farm=db_farm).resource_profile


@router.put("/farms/{farm_id}/profile", response_model=SharedResourceProfileDTO)
def save_farm_resource_profile(
    farm_id: uuid.UUID,
    profile: FarmerResourceProfile,
    current_user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Save farmer resources once into shared profile tables for reuse across features."""
    db_farm = _load_owned_farm(farm_id, current_user, db)
    return save_resource_profile_shared(db=db, current_user=current_user, cropnet_farm=db_farm, profile=profile)


@router.post("/farms/{farm_id}/discover", response_model=List[DiscoveredOpportunity])
def discover_farm_opportunities(
    farm_id: uuid.UUID,
    profile_override: Optional[FarmerResourceProfile] = None,
    current_user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Discover farm-grounded opportunities using registered CropNet farm + shared farmer resources."""
    db_farm = _load_owned_farm(farm_id, current_user, db)
    try:
        profile = build_income_engine_profile(
            db=db,
            current_user=current_user,
            cropnet_farm=db_farm,
            override=profile_override,
        )
    except MissingSharedContextError as mce:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"code": "MISSING_RESOURCE_PROFILE", "message": mce.message, "missing_fields": mce.missing_fields},
        )
    return IncomeEngine.match_opportunities(profile)


@router.post("/farms/{farm_id}/plans", response_model=SavedIncomePlan)
def save_income_plan(
    farm_id: uuid.UUID,
    req: SavePlanRequest,
    current_user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    db_farm = _load_owned_farm(farm_id, current_user, db)
    farmer = get_or_link_farmer_for_user(db, current_user, farm=db_farm, create_if_missing=True)
    opp = get_opportunity_by_id(req.opportunity_id)
    if not opp:
        raise HTTPException(status_code=404, detail="Opportunity not found.")

    fin = IncomeEngine.calculate_enterprise_financials(req.opportunity_id, req.chosen_budget_inr)
    plan_id = f"plan_{uuid.uuid4().hex[:10]}"
    record = SavedIncomePlanModel(
        plan_id=plan_id,
        farmer_id=farmer.farmer_id,
        farm_id=str(farm_id),
        opportunity_id=opp.opportunity_id,
        opportunity_title=opp.title,
        category=opp.category,
        chosen_budget_inr=req.chosen_budget_inr,
        projected_annual_profit_inr=fin.calculated_net_profit_annual_inr,
        projected_annual_savings_inr=fin.calculated_annual_savings_inr,
        payback_months=fin.calculated_break_even_months,
        break_even_reached=fin.break_even_reached,
        notes=req.notes,
        created_at_utc=now_utc(),
    )
    db.add(record)
    db.commit()
    db.refresh(record)
    return SavedIncomePlan(
        plan_id=record.plan_id,
        farmer_id=record.farmer_id,
        farm_id=record.farm_id,
        opportunity_id=record.opportunity_id,
        opportunity_title=record.opportunity_title,
        category=record.category,
        chosen_budget_inr=record.chosen_budget_inr,
        projected_annual_profit_inr=record.projected_annual_profit_inr,
        projected_annual_savings_inr=record.projected_annual_savings_inr,
        payback_months=record.payback_months,
        break_even_reached=record.break_even_reached,
        notes=record.notes,
        created_at_utc=record.created_at_utc.isoformat(),
    )


@router.get("/farms/{farm_id}/plans", response_model=List[SavedIncomePlan])
def list_saved_income_plans(
    farm_id: uuid.UUID,
    current_user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _load_owned_farm(farm_id, current_user, db)
    records = (
        db.query(SavedIncomePlanModel)
        .filter(SavedIncomePlanModel.farm_id == str(farm_id))
        .order_by(SavedIncomePlanModel.created_at_utc.desc())
        .all()
    )
    return [
        SavedIncomePlan(
            plan_id=r.plan_id,
            farmer_id=r.farmer_id,
            farm_id=r.farm_id,
            opportunity_id=r.opportunity_id,
            opportunity_title=r.opportunity_title,
            category=r.category,
            chosen_budget_inr=r.chosen_budget_inr,
            projected_annual_profit_inr=r.projected_annual_profit_inr,
            projected_annual_savings_inr=r.projected_annual_savings_inr,
            payback_months=r.payback_months,
            break_even_reached=r.break_even_reached,
            notes=r.notes,
            created_at_utc=r.created_at_utc.isoformat(),
        )
        for r in records
    ]


@router.delete("/farms/{farm_id}/plans/{plan_id}")
def delete_saved_income_plan(
    farm_id: uuid.UUID,
    plan_id: str,
    current_user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _load_owned_farm(farm_id, current_user, db)
    record = (
        db.query(SavedIncomePlanModel)
        .filter(SavedIncomePlanModel.farm_id == str(farm_id), SavedIncomePlanModel.plan_id == plan_id)
        .first()
    )
    if not record:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Saved plan not found")
    db.delete(record)
    db.commit()
    return {"deleted": True, "plan_id": plan_id}
