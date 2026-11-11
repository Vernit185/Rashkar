"""
Additive SQLAlchemy ORM models integrating Rashkar shared farmer/plot/crop/resource
records, knowledge tables, risk audit logs, and income planning into CropNet's Base.

Reuses existing CropNet `farms` table (`farms.id`) as the single Farm entity and
reuses/migrates compatible unattached tables already present in `cropnet_dev.db`.
"""
import uuid
from datetime import datetime
from sqlalchemy import (
    Column, String, Integer, Float, Boolean, DateTime, Date, ForeignKey, Text, JSON
)
from sqlalchemy.orm import relationship

from cropnet.services.api.app.models.soil_and_farm import Base
from cropnet.services.api.app.services.rashkar.timezone import now_utc


class FarmerModel(Base):
    """Shared farmer profile linked 1:1 with CropNet Supabase/Dev user accounts."""
    __tablename__ = "farmers"

    farmer_id = Column(String(50), primary_key=True, index=True)
    full_name = Column(String(100), nullable=False)
    phone_number = Column(String(20), nullable=True, index=True)
    state = Column(String(50), default="Maharashtra")
    district = Column(String(50), nullable=False, index=True)
    taluka = Column(String(50), nullable=False, index=True)
    village = Column(String(100), nullable=True)
    preferred_language = Column(String(10), default="en")

    # Shared personal & worker risk defaults (nullable: unknown until farmer confirms)
    age_range = Column(String(30), nullable=True)
    work_preference = Column(String(40), nullable=True)
    payback_horizon = Column(String(40), nullable=True)
    family_management_role = Column(String(40), nullable=True)
    default_workload_category = Column(String(30), nullable=True)
    default_clothing_type = Column(String(40), nullable=True)
    default_is_acclimatised = Column(Boolean, nullable=True)
    default_sun_exposure = Column(String(30), nullable=True)
    default_exposure_duration_hours = Column(Float, nullable=True)

    created_at = Column(DateTime, default=now_utc)
    updated_at = Column(DateTime, default=now_utc, onupdate=now_utc)


class FarmerUserAccountModel(Base):
    """Maps CropNet authenticated user UUID (Supabase / X-Dev-User-Id) to farmers.farmer_id."""
    __tablename__ = "farmer_user_accounts"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    auth_provider = Column(String(50), nullable=False, default="supabase")
    auth_user_id = Column(String(50), nullable=False, index=True)
    farmer_id = Column(String(50), ForeignKey("farmers.farmer_id", ondelete="CASCADE"), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    verified_at = Column(DateTime, default=datetime.utcnow)


class FarmPlotModel(Base):
    """Sub-plots belonging to a CropNet farm (`farms.id`)."""
    __tablename__ = "farm_plots"

    plot_id = Column(String(50), primary_key=True, index=True)
    farm_id = Column(String(50), ForeignKey("farms.id"), nullable=False, index=True)
    plot_name = Column(String(100), nullable=False)
    area_acres = Column(Float, nullable=False)
    polygon_geojson = Column(JSON, nullable=True)
    irrigation_type = Column(String(50), default="rainfed")
    created_at = Column(DateTime, default=now_utc)

    crop_cycles = relationship("CropCycleModel", back_populates="plot", cascade="all, delete-orphan")


class CropCycleModel(Base):
    """Planted crop cycles on a farm plot with farmer-confirmed phenological stage."""
    __tablename__ = "crop_cycles"

    cycle_id = Column(String(50), primary_key=True, index=True)
    plot_id = Column(String(50), ForeignKey("farm_plots.plot_id"), nullable=False, index=True)
    crop_code = Column(String(50), nullable=False, index=True)
    variety_name = Column(String(100), nullable=True)
    season = Column(String(20), nullable=False)
    sowing_date = Column(Date, nullable=False)
    harvest_date_actual = Column(Date, nullable=True)
    planted_area_acres = Column(Float, nullable=True)
    current_stage_code = Column(String(50), nullable=True)
    stage_updated_at = Column(DateTime, nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=now_utc)

    plot = relationship("FarmPlotModel", back_populates="crop_cycles")


class CanonicalCropMasterModel(Base):
    __tablename__ = "canonical_crops"

    crop_code = Column(String(50), primary_key=True, index=True)
    common_name_en = Column(String(100), nullable=False)
    common_name_mr = Column(String(100), nullable=False)
    botanical_name = Column(String(150), nullable=False)
    crop_category = Column(String(50), nullable=False)
    standard_season = Column(String(50), nullable=False)
    is_pioneer_pilot_crop = Column(Boolean, default=False)
    support_level = Column(String(50), default="data_limited")
    apy_alias_list = Column(JSON, default=list)
    created_at = Column(DateTime, default=now_utc)


class CropStageReferenceModel(Base):
    __tablename__ = "crop_stage_references"

    stage_id = Column(String(50), primary_key=True, index=True)
    crop_code = Column(String(50), nullable=False, index=True)
    stage_code = Column(String(50), nullable=False)
    stage_name_en = Column(String(100), nullable=False)
    stage_name_mr = Column(String(100), nullable=False)
    sequence_order = Column(Integer, nullable=False)
    typical_duration_days = Column(Integer, nullable=False)
    das_start_typical = Column(Integer, nullable=False)
    das_end_typical = Column(Integer, nullable=False)
    heat_sensitivity = Column(String(20), default="low")
    drought_sensitivity = Column(String(20), default="low")
    excess_water_sensitivity = Column(String(20), default="low")
    source_citation = Column(Text, nullable=False)


class AgronomicThresholdRegistryModel(Base):
    __tablename__ = "agronomic_threshold_registry"

    threshold_id = Column(String(50), primary_key=True, index=True)
    crop_code = Column(String(50), nullable=False, index=True)
    applicable_variety = Column(String(100), default="all")
    agro_ecological_zone = Column(String(100), default="Maharashtra Statewide")
    growth_stage = Column(String(50), nullable=False)
    environmental_variable = Column(String(50), nullable=False)
    unit = Column(String(20), nullable=False)
    critical_threshold = Column(Float, nullable=False)
    required_exposure_duration_hours = Column(Integer, default=1)
    comparison_operator = Column(String(10), default=">=")
    physiological_impact = Column(Text, nullable=False)
    source_institution = Column(String(150), nullable=False)
    publication_citation = Column(Text, nullable=False)
    publication_year = Column(Integer, nullable=False)
    evidence_grade = Column(String(50), nullable=False)
    verification_status = Column(String(50), default="verified_by_agronomist")
    created_at = Column(DateTime, default=now_utc)


class AgronomicAdvisoryCatalogueModel(Base):
    __tablename__ = "agronomic_advisory_catalogue"

    action_id = Column(String(50), primary_key=True, index=True)
    crop_code = Column(String(50), nullable=False, index=True)
    risk_dimension = Column(String(50), nullable=False)
    title_en = Column(String(200), nullable=False)
    title_mr = Column(String(200), nullable=False)
    description_en = Column(Text, nullable=False)
    description_mr = Column(Text, nullable=False)
    evidence_citation = Column(Text, nullable=False)
    expert_reviewer = Column(String(100), nullable=True)
    is_active = Column(Boolean, default=True)


class WorkerHazardAuditLogModel(Base):
    __tablename__ = "worker_hazard_audit_log"

    session_id = Column(String(50), primary_key=True, index=True)
    generated_at_utc = Column(DateTime, default=now_utc, nullable=False)
    latitude_rounded = Column(Float, nullable=False)
    longitude_rounded = Column(Float, nullable=False)
    taluka = Column(String(50), nullable=False)
    workload_category = Column(String(50), nullable=False)
    sun_exposure = Column(String(50), nullable=False)
    is_acclimatised = Column(Boolean, default=True)
    max_estimated_wbgt_c = Column(Float, nullable=False)
    hazard_level = Column(String(50), nullable=False)
    weather_provider = Column(String(100), nullable=False)
    weather_observation_time_utc = Column(DateTime, nullable=False)


class CropHeatAssessmentLogModel(Base):
    __tablename__ = "crop_heat_assessment_logs"

    assessment_id = Column(String(50), primary_key=True, index=True)
    farm_id = Column(String(50), nullable=False, index=True)
    crop_code = Column(String(50), nullable=False)
    stage_code = Column(String(50), nullable=False)
    generated_at_utc = Column(DateTime, default=now_utc, nullable=False)
    max_forecast_temp_c = Column(Float, nullable=False)
    critical_threshold_c = Column(Float, nullable=False)
    exceedance_hours = Column(Integer, default=0)
    warm_night_flag = Column(Boolean, default=False)
    risk_level = Column(String(50), nullable=False)
    evidence_citation = Column(Text, nullable=False)


class FarmerResourceProfileModel(Base):
    """Persisted farmer resource profile linked to a CropNet farm (`farms.id`)."""
    __tablename__ = "farmer_resource_profiles"

    farm_id = Column(String(50), primary_key=True, index=True)
    farmer_id = Column(String(50), nullable=False, index=True)
    available_investment_inr = Column(Float, nullable=True)
    monthly_operating_budget_inr = Column(Float, nullable=True)
    max_risk_capital_inr = Column(Float, nullable=True)
    willing_to_borrow = Column(Boolean, nullable=True)

    total_farm_acres = Column(Float, nullable=True)
    cultivated_acres = Column(Float, nullable=True)
    available_land_acres = Column(Float, nullable=True)
    unused_land_acres = Column(Float, nullable=True)
    field_bunds_available = Column(Boolean, nullable=True)

    has_animal_shed = Column(Boolean, nullable=True)
    has_storage_room = Column(Boolean, nullable=True)
    has_shaded_space = Column(Boolean, nullable=True)

    water_availability = Column(String(50), nullable=True)
    water_months_available = Column(JSON, default=list)

    family_labor_hours_day = Column(Float, nullable=True)
    hired_labor_possible = Column(Boolean, nullable=True)

    existing_livestock = Column(String(50), nullable=True)
    existing_assets = Column(JSON, default=list)
    crop_byproducts = Column(JSON, default=list)
    byproduct_surplus_available = Column(Boolean, nullable=True)

    interests = Column(JSON, default=list)
    has_transport = Column(Boolean, nullable=True)
    has_fpo_access = Column(Boolean, nullable=True)
    distance_to_apmc_km = Column(Float, nullable=True)

    risk_tolerance = Column(String(20), nullable=True)
    category_preference = Column(String(50), default="all")

    age_range = Column(String(30), nullable=True)
    work_preference = Column(String(40), nullable=True)
    payback_horizon = Column(String(40), nullable=True)
    family_management_role = Column(String(40), nullable=True)
    current_crop_code = Column(String(50), nullable=True)
    current_crop_stage = Column(String(50), nullable=True)
    profile_completed = Column(Boolean, default=False)

    updated_at_utc = Column(DateTime, default=now_utc, onupdate=now_utc)


class IncomeOpportunityModel(Base):
    __tablename__ = "income_opportunities"

    opportunity_id = Column(String(50), primary_key=True, index=True)
    title = Column(String(150), nullable=False)
    category = Column(String(50), nullable=False)
    is_cost_saving = Column(Boolean, default=False)
    tagline = Column(String(200), default="")
    target_crops = Column(JSON, default=list)
    required_resources = Column(JSON, default=list)
    min_investment_inr = Column(Float, nullable=False, default=0.0)
    max_investment_inr = Column(Float, nullable=False, default=0.0)
    working_capital_required_inr = Column(Float, default=0.0)
    payback_period_months = Column(Integer, nullable=False, default=1)
    potential_annual_profit_inr = Column(Float, nullable=False, default=0.0)
    potential_annual_savings_inr = Column(Float, default=0.0)
    risk_level = Column(String(20), default="moderate")
    summary = Column(Text, nullable=False)
    market_commodity = Column(String(100), default="")
    market_benchmark_price = Column(String(100), default="")
    market_source = Column(String(150), default="")
    key_assumptions = Column(JSON, default=list)
    key_risks = Column(JSON, default=list)
    source_attribution = Column(String(200), nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=now_utc)


class IncomeScenarioModel(Base):
    __tablename__ = "income_scenarios"

    scenario_id = Column(String(50), primary_key=True, index=True)
    farmer_id = Column(String(50), nullable=False, index=True)
    farm_id = Column(String(50), nullable=False, index=True)
    opportunity_id = Column(String(50), ForeignKey("income_opportunities.opportunity_id"), nullable=False)
    custom_budget_inr = Column(Float, nullable=False)
    available_labour_hours_day = Column(Float, default=2.0)
    available_land_acres = Column(Float, default=0.5)
    custom_assumptions = Column(JSON, default=dict)
    calculated_capex_inr = Column(Float, nullable=False)
    calculated_opex_annual_inr = Column(Float, nullable=False)
    calculated_gross_revenue_inr = Column(Float, nullable=False)
    calculated_net_profit_annual_inr = Column(Float, nullable=False)
    calculated_break_even_months = Column(Float, nullable=True)
    sensitivity_analysis = Column(JSON, default=dict)
    monthly_cash_flows = Column(JSON, default=list)
    generated_at_utc = Column(DateTime, default=now_utc)


class SavedIncomePlanModel(Base):
    __tablename__ = "saved_income_plans"

    plan_id = Column(String(50), primary_key=True, index=True)
    farmer_id = Column(String(50), nullable=False, index=True)
    farm_id = Column(String(50), nullable=False, index=True)
    opportunity_id = Column(String(50), nullable=False)
    opportunity_title = Column(String(150), nullable=False)
    category = Column(String(50), nullable=False)
    chosen_budget_inr = Column(Float, nullable=False)
    projected_annual_profit_inr = Column(Float, nullable=False)
    projected_annual_savings_inr = Column(Float, default=0.0)
    payback_months = Column(Float, nullable=True)
    break_even_reached = Column(Boolean, default=True)
    notes = Column(Text, nullable=True)
    created_at_utc = Column(DateTime, default=now_utc)
