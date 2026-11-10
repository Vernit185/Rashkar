from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field

class CropHeatAssessmentRequest(BaseModel):
    farm_id: str = Field(..., description="Unique farm identifier")
    plot_id: Optional[str] = Field(None, description="Optional plot identifier")
    farmer_confirmed_stage: Optional[str] = Field(None, description="Farmer confirmed/corrected growth stage")
    forecast_tmax_c: Optional[float] = Field(None, description="Forecasted maximum day temperature (°C)")
    forecast_tmin_c: Optional[float] = Field(None, description="Forecasted minimum night temperature (°C)")
    forecast_sun_hours: Optional[float] = Field(None, description="Forecasted hours of direct sunlight")

class CropHeatIntervention(BaseModel):
    intervention_id: str
    title_en: str
    title_mr: str
    description_en: str
    description_mr: str
    why_appropriate: str
    evidence_citation: str
    source_page_or_table: Optional[str] = "Package of Practices, Table 3.1"
    agronomist_reviewer: Optional[str] = "ICAR-SAU Agrometeorological Review Panel"
    application_method: Optional[str] = "Foliar / Soil Application"
    application_dose: Optional[str] = "Specified dose per hectare"
    infrastructure_requirements: Optional[str] = "Drip / Sprinkler / Knapsack Sprayer"
    trigger_condition: Optional[str] = "Assessed Heat Stress Condition"
    evidence_status: str = "VERIFIED_PUBLISHED"
    category: str = "VERIFIED_AGRONOMIC"  # VERIFIED_AGRONOMIC, PREVENTATIVE_MANAGEMENT, EXPERIMENTAL_SCREENING

class DailyCropHeatOutlook(BaseModel):
    date: str
    day_label: str
    tmax_c: float
    tmin_c: float
    hours_above_critical: float
    risk_category: str
    explanation: str

class CropHeatAssessmentResponse(BaseModel):
    assessment_id: str
    farm_id: str
    farm_name: str
    plot_name: str
    crop_code: str
    crop_common_name: str
    crop_variety: Optional[str] = "Variety not recorded"
    sowing_date: str
    days_after_sowing: int
    crop_area_acres: float
    irrigation_status: str
    soil_texture: str
    soil_provenance_label: str = "CropNet Model Estimate (Unsampled Farm Coordinate)"
    is_soil_synthetic: bool = True
    
    # Season status
    is_season_expired: bool = False
    season_status: str = "ACTIVE"
    requires_season_update: bool = False
    season_expiry_message: Optional[str] = None
    
    # Section 1: Growth stage & overrides
    growth_stage_code: Optional[str] = None
    growth_stage_name_en: Optional[str] = None
    growth_stage_name_mr: Optional[str] = None
    supported_stages: List[Dict[str, Any]]
    farmer_confirmed_stage: Optional[str] = None
    
    # Section 2: Crop Thermal Analysis
    base_temp_c: float
    optimal_temp_min_c: float
    optimal_temp_max_c: float
    critical_tmax_threshold_c: float
    critical_tmin_threshold_c: float
    tmax_forecast_c: float
    tmin_forecast_c: float
    hours_above_critical: float
    consecutive_hot_days: int
    daytime_exposure_hours: float
    warm_night_respiration_hazard: bool
    warm_night_penalty_score: float
    cumulative_heat_units_gdd: float
    evidence_citation: str
    evidence_status: str = "VERIFIED_PUBLISHED"
    institution_attribution: Optional[str] = "ICAR-CRIDA / State Agricultural Universities (SAU)"
    thermal_analysis: Optional[Dict[str, Any]] = None
    personalized_crop_vulnerability_score: Optional[Dict[str, Any]] = None
    topographic_downscaling: Optional[Dict[str, Any]] = None
    
    # Section 3: Multi-day outlook
    daily_outlook: List[DailyCropHeatOutlook]
    four_day_outlook: Optional[List[DailyCropHeatOutlook]] = None
    
    # Section 4: Agronomic risk explanation
    generated_at_ist: str
    daytime_heat_stress_level: str
    overall_crop_heat_risk: str
    physiological_mechanism: str
    stage_biological_vulnerability: str
    
    # Section 5: Field recommendations
    recommended_interventions: List[CropHeatIntervention]
    field_recommendations: List[CropHeatIntervention] = Field(default_factory=list)
    
    # Section 6: Historical trends
    assessment_history: List[Dict[str, Any]]
    audit_logged: bool = True
