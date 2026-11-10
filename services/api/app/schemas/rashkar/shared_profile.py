"""
Schemas bridging CropNet's single farm/user registration with Rashkar's
Worker Heat Risk, Crop Heat Risk, and Extra Income engines.
"""
from datetime import date, datetime
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field

from cropnet.services.api.app.schemas.rashkar.worker_heat import WorkerHeatAssessmentResponse
from cropnet.services.api.app.schemas.rashkar.crop_heat import CropHeatAssessmentResponse
from cropnet.services.api.app.schemas.rashkar.income import (
    FarmerResourceProfile,
    DiscoveredOpportunity,
    EnterpriseFinancialAnalysis,
    OpportunityComparisonItem,
    SavedIncomePlan,
)


class SharedFarmerProfileData(BaseModel):
    farmer_id: Optional[str] = None
    full_name: Optional[str] = None
    phone_number: Optional[str] = None
    preferred_language: str = "en"
    age_range: Optional[str] = None
    work_preference: Optional[str] = None
    payback_horizon: Optional[str] = None
    family_management_role: Optional[str] = None
    default_workload_category: Optional[str] = None
    default_clothing_type: Optional[str] = None
    default_is_acclimatised: Optional[bool] = None
    default_sun_exposure: Optional[str] = None
    default_exposure_duration_hours: Optional[float] = None


class FarmPlotResponse(BaseModel):
    plot_id: str
    farm_id: str
    plot_name: str
    area_acres: float
    irrigation_type: Optional[str] = None
    created_at: Optional[datetime] = None


class CropCycleResponse(BaseModel):
    cycle_id: str
    plot_id: str
    plot_name: str
    farm_id: str
    crop_code: str
    variety_name: Optional[str] = None
    season: str
    sowing_date: date
    planted_area_acres: Optional[float] = None
    irrigation_type: Optional[str] = None
    current_stage_code: Optional[str] = None
    estimated_stage_code: Optional[str] = None
    estimated_stage_name: Optional[str] = None
    days_after_sowing: Optional[int] = None
    is_active: bool = True


class FarmPlotUpsertRequest(BaseModel):
    plot_name: str = Field(..., min_length=1, max_length=100)
    area_acres: float = Field(..., gt=0.0)
    irrigation_type: Optional[str] = None


class CropCycleUpsertRequest(BaseModel):
    plot_id: Optional[str] = None
    plot_name: Optional[str] = "Main Plot 1"
    crop_code: str = Field(..., min_length=1, max_length=50)
    variety_name: Optional[str] = None
    season: str = Field(default="kharif")
    sowing_date: date
    planted_area_acres: Optional[float] = None
    irrigation_type: Optional[str] = None
    farmer_confirmed_stage: Optional[str] = None


class CropCycleStageUpdateRequest(BaseModel):
    farmer_confirmed_stage: str


class SharedResourceProfileDTO(BaseModel):
    """Nullable view of resource profile so unconfirmed fields stay genuinely unknown."""
    farm_id: str
    farmer_id: Optional[str] = None
    profile_completed: bool = False
    missing_fields: List[str] = Field(default_factory=list)

    available_investment_inr: Optional[float] = None
    monthly_operating_budget_inr: Optional[float] = None
    max_risk_capital_inr: Optional[float] = None
    willing_to_borrow: Optional[bool] = None

    total_farm_acres: Optional[float] = None
    cultivated_acres: Optional[float] = None
    available_land_acres: Optional[float] = None
    unused_land_acres: Optional[float] = None
    field_bunds_available: Optional[bool] = None

    has_animal_shed: Optional[bool] = None
    has_storage_room: Optional[bool] = None
    has_shaded_space: Optional[bool] = None

    water_availability: Optional[str] = None
    water_months_available: List[int] = Field(default_factory=list)

    family_labor_hours_day: Optional[float] = None
    hired_labor_possible: Optional[bool] = None

    existing_livestock: Optional[str] = None
    existing_assets: List[str] = Field(default_factory=list)
    crop_byproducts: List[str] = Field(default_factory=list)
    byproduct_surplus_available: Optional[bool] = None

    interests: List[str] = Field(default_factory=list)
    has_transport: Optional[bool] = None
    has_fpo_access: Optional[bool] = None
    distance_to_apmc_km: Optional[float] = None

    risk_tolerance: Optional[str] = None
    category_preference: Optional[str] = None

    age_range: Optional[str] = None
    work_preference: Optional[str] = None
    payback_horizon: Optional[str] = None
    family_management_role: Optional[str] = None
    current_crop_code: Optional[str] = None
    current_crop_stage: Optional[str] = None


class SharedFarmContextUpdateRequest(BaseModel):
    farmer_profile: Optional[SharedFarmerProfileData] = None
    resource_profile: Optional[FarmerResourceProfile] = None


class SharedFarmContextResponse(BaseModel):
    farm_id: str
    farm_name: str
    taluka: str
    district: str
    state: str
    village: Optional[str] = None
    latitude: float
    longitude: float
    total_area_acres: float
    total_area_hectares: float
    irrigation_type: Optional[str] = None
    water_source: Optional[str] = None

    farmer_profile: SharedFarmerProfileData
    plots: List[FarmPlotResponse] = Field(default_factory=list)
    crop_cycles: List[CropCycleResponse] = Field(default_factory=list)
    resource_profile: SharedResourceProfileDTO

    worker_heat_missing_fields: List[str] = Field(default_factory=list)
    crop_heat_missing_fields: List[str] = Field(default_factory=list)
    extra_income_missing_fields: List[str] = Field(default_factory=list)


class FarmWorkerHeatAssessRequest(BaseModel):
    workload_category: Optional[str] = None
    clothing_type: Optional[str] = None
    is_acclimatised: Optional[bool] = None
    sun_exposure: Optional[str] = None
    exposure_duration_hours: Optional[float] = Field(default=None, ge=0.5, le=12.0)
    save_as_default: bool = True


class FarmCropHeatAssessRequest(BaseModel):
    plot_id: Optional[str] = None
    cycle_id: Optional[str] = None
    farmer_confirmed_stage: Optional[str] = None
    forecast_tmax_c: Optional[float] = None
    forecast_tmin_c: Optional[float] = None
    forecast_sun_hours: Optional[float] = None
