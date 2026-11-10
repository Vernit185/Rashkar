"""
Integration Adapter Layer translating CropNet's authoritative farmer, farm,
plot, soil, water, and crop-cycle records into exact request/entity objects
for Rashkar's unmodified Worker Heat Risk, Crop Heat Risk, and Extra Income engines.
"""
import uuid
import logging
from datetime import date, datetime
from types import SimpleNamespace
from typing import Any, Dict, List, Optional, Tuple
from sqlalchemy.orm import Session

from cropnet.services.api.app.core.security import CurrentUser
from cropnet.services.api.app.models.soil_and_farm import (
    FarmModel as CropNetFarmModel,
    FarmSoilProfileModel,
    SoilParameterModel,
)
from cropnet.services.api.app.models.soil_reports import (
    SoilTestReportModel,
    SoilMeasurementModel,
)
from cropnet.services.api.app.models.water import WaterSourceModel
from cropnet.services.api.app.models.rashkar_profiles import (
    FarmerModel,
    FarmerUserAccountModel,
    FarmPlotModel,
    CropCycleModel,
    FarmerResourceProfileModel,
)
from cropnet.services.api.app.schemas.rashkar.worker_heat import (
    WorkerHeatAssessmentRequest,
    WorkerHeatAssessmentResponse,
)
from cropnet.services.api.app.schemas.rashkar.crop_heat import (
    CropHeatAssessmentRequest,
    CropHeatAssessmentResponse,
)
from cropnet.services.api.app.schemas.rashkar.income import FarmerResourceProfile
from cropnet.services.api.app.schemas.rashkar.shared_profile import (
    SharedFarmerProfileData,
    FarmPlotResponse,
    CropCycleResponse,
    FarmPlotUpsertRequest,
    CropCycleUpsertRequest,
    SharedResourceProfileDTO,
    SharedFarmContextResponse,
    SharedFarmContextUpdateRequest,
    FarmWorkerHeatAssessRequest,
    FarmCropHeatAssessRequest,
)
from cropnet.services.api.app.services.rashkar.query_tokens import (
    FarmModel as RashkarFarmToken,
    SoilProfileModel as RashkarSoilToken,
)
from cropnet.services.api.app.services.rashkar.worker_heat_engine import WorkerHeatEngine
from cropnet.services.api.app.services.rashkar.crop_heat_engine import CropHeatEngine
from cropnet.services.api.app.services.rashkar.crop_stage_service import CropStageService
from cropnet.services.api.app.services.rashkar.timezone import now_utc

logger = logging.getLogger(__name__)

WORKER_REQUIRED_FIELDS = [
    "workload_category",
    "sun_exposure",
    "is_acclimatised",
    "clothing_type",
    "exposure_duration_hours",
]

INCOME_REQUIRED_FIELDS = [
    "available_investment_inr",
    "unused_land_acres",
    "water_availability",
    "family_labor_hours_day",
]


class MissingSharedContextError(Exception):
    """Raised cleanly when required farmer-specific context has never been provided."""

    def __init__(self, feature: str, missing_fields: List[str], message: str):
        super().__init__(message)
        self.feature = feature
        self.missing_fields = missing_fields
        self.message = message


class _SingleResultQueryProxy:
    """Minimal SQLAlchemy query proxy returned when CropHeatEngine queries FarmModel/SoilProfileModel."""

    def __init__(self, target_obj: Any):
        self._target_obj = target_obj

    def filter(self, *args, **kwargs):
        return self

    def first(self):
        return self._target_obj

    def all(self):
        return [self._target_obj] if self._target_obj is not None else []


class _CropCycleFilterProxy:
    """Intercepts CropCycle query only when caller requests a specific cycle_id on multi-crop farms."""

    def __init__(self, real_query, specific_cycle_id: Optional[str]):
        self._real_query = real_query
        self._specific_cycle_id = specific_cycle_id

    def join(self, *args, **kwargs):
        self._real_query = self._real_query.join(*args, **kwargs)
        return self

    def filter(self, *args, **kwargs):
        self._real_query = self._real_query.filter(*args, **kwargs)
        if self._specific_cycle_id:
            self._real_query = self._real_query.filter(CropCycleModel.cycle_id == self._specific_cycle_id)
        return self

    def order_by(self, *args, **kwargs):
        self._real_query = self._real_query.order_by(*args, **kwargs)
        return self

    def first(self):
        return self._real_query.first()

    def all(self):
        return self._real_query.all()


class RashkarAdaptedSession:
    """
    Translates CropNet's `farms` and soil models for Rashkar's unmodified
    `CropHeatEngine.assess_crop_heat_risk(db, request)` while delegating all other
    ORM reads/writes straight to CropNet's SQLAlchemy Session.
    """

    def __init__(self, real_db: Session, cropnet_farm: CropNetFarmModel, specific_cycle_id: Optional[str] = None):
        self._db = real_db
        self._cropnet_farm = cropnet_farm
        self._specific_cycle_id = specific_cycle_id

    def _build_farm_proxy(self) -> SimpleNamespace:
        return SimpleNamespace(
            farm_id=str(self._cropnet_farm.id),
            farm_name=self._cropnet_farm.name,
            total_area_acres=self._cropnet_farm.calculated_area_acres,
            latitude=self._cropnet_farm.centroid_latitude or 18.18,
            longitude=self._cropnet_farm.centroid_longitude or 74.53,
        )

    def _build_soil_proxy(self) -> Optional[SimpleNamespace]:
        farm_id_str = str(self._cropnet_farm.id)
        # 1. Prefer confirmed lab soil test report if present in CropNet
        try:
            confirmed_reports = (
                self._db.query(SoilTestReportModel)
                .filter(
                    SoilTestReportModel.farm_id == farm_id_str,
                    SoilTestReportModel.review_status == "confirmed",
                )
                .order_by(SoilTestReportModel.created_at.desc())
                .first()
            )
            if confirmed_reports:
                clay_meas = (
                    self._db.query(SoilMeasurementModel)
                    .filter(
                        SoilMeasurementModel.report_id == confirmed_reports.id,
                        SoilMeasurementModel.parameter_key.in_(["clay", "clay_pct", "clay_percent"]),
                    )
                    .first()
                )
                clay_val = None
                if clay_meas:
                    clay_val = (
                        clay_meas.farmer_corrected_value
                        if clay_meas.farmer_corrected_value is not None
                        else (clay_meas.normalized_value if clay_meas.normalized_value is not None else clay_meas.original_value)
                    )
                lab_label = confirmed_reports.laboratory_name or "Soil Health Card / Lab"
                return SimpleNamespace(
                    depth_interval=confirmed_reports.sample_depth_interval or "0-30cm",
                    clay_pct=float(clay_val) if clay_val is not None else None,
                    is_lab_measured=True,
                    data_provenance=lab_label,
                )
        except Exception as exc:
            logger.debug("Lab soil check fallback: %s", exc)

        # 2. Fallback to CropNet map-derived soil profile (SoilGrids/OpenLandMap)
        try:
            soil_profile = (
                self._db.query(FarmSoilProfileModel)
                .filter(FarmSoilProfileModel.farm_id == farm_id_str)
                .order_by(FarmSoilProfileModel.created_at.desc())
                .first()
            )
            if soil_profile:
                clay_param = (
                    self._db.query(SoilParameterModel)
                    .filter(
                        SoilParameterModel.profile_id == soil_profile.id,
                        SoilParameterModel.parameter_key.in_(["clay", "clay_pct"]),
                    )
                    .first()
                )
                return SimpleNamespace(
                    depth_interval=(clay_param.depth_interval if clay_param else "0-30cm"),
                    clay_pct=(float(clay_param.value) if clay_param and clay_param.value is not None else None),
                    is_lab_measured=not bool(soil_profile.is_map_derived),
                    data_provenance="CropNet Map Estimate (SoilGrids / OpenLandMap)"
                    if soil_profile.is_map_derived
                    else soil_profile.disclaimer,
                )
        except Exception as exc:
            logger.debug("Map soil check fallback: %s", exc)

        return None

    def query(self, model_cls, *args, **kwargs):
        if model_cls is RashkarFarmToken:
            return _SingleResultQueryProxy(self._build_farm_proxy())
        if model_cls is RashkarSoilToken:
            return _SingleResultQueryProxy(self._build_soil_proxy())
        q = self._db.query(model_cls, *args, **kwargs)
        if model_cls is CropCycleModel and self._specific_cycle_id:
            return _CropCycleFilterProxy(q, self._specific_cycle_id)
        return q

    def add(self, instance):
        return self._db.add(instance)

    def commit(self):
        return self._db.commit()

    def rollback(self):
        return self._db.rollback()

    def flush(self):
        return self._db.flush()

    def refresh(self, instance):
        return self._db.refresh(instance)


def map_cropnet_water_to_rashkar(
    irrigation_type: Optional[str],
    water_source: Optional[str],
    water_sources: Optional[List[WaterSourceModel]] = None,
) -> Optional[str]:
    """
    Translates CropNet farm/water records to Rashkar's `water_availability` vocabulary
    ONLY when CropNet actually has a concrete non-unknown record.
    Returns None if genuinely unknown so it is never silently fabricated.
    """
    if water_sources:
        active_ws = [w for w in water_sources if w.is_active]
        if active_ws:
            avail = {str(w.seasonal_availability or "").lower() for w in active_ws}
            if "year_round" in avail or "perennial" in avail:
                return "reliable_year_round"
            if "seasonal" in avail:
                return "seasonal_canal"
            if "scarce" in avail or "limited" in avail:
                return "limited"

    irr = (irrigation_type or "").strip().lower()
    src = (water_source or "").strip().lower()
    if irr == "rainfed":
        return "rainfed_only"
    if irr in ("irrigated", "drip", "sprinkler"):
        if src in ("borewell", "well"):
            return "reliable_year_round"
        if src == "canal":
            return "seasonal_canal"
        if src in ("rainfall",):
            return "rainfed_only"
        if src and src != "unknown":
            return "seasonal_canal"
    if irr == "mixed":
        return "seasonal_canal"
    return None


def get_or_link_farmer_for_user(
    db: Session,
    current_user: CurrentUser,
    farm: Optional[CropNetFarmModel] = None,
    create_if_missing: bool = True,
) -> Optional[FarmerModel]:
    """
    Single shared farmer identity lookup linking CropNet's auth user (`CurrentUser.user_id`)
    with `farmers` via `farmer_user_accounts`. Never fabricates personal/worker preferences.
    """
    uid_str = str(current_user.user_id)
    link = (
        db.query(FarmerUserAccountModel)
        .filter(FarmerUserAccountModel.auth_user_id == uid_str)
        .first()
    )
    if link:
        farmer = db.query(FarmerModel).filter(FarmerModel.farmer_id == link.farmer_id).first()
        if farmer:
            return farmer

    if not create_if_missing:
        return None

    farmer_id = f"farmer_{uid_str[:8]}"
    existing_farmer = db.query(FarmerModel).filter(FarmerModel.farmer_id == farmer_id).first()
    if not existing_farmer:
        fallback_name = (current_user.email.split("@")[0] if current_user.email and "@" in current_user.email else "CropNet Farmer")
        existing_farmer = FarmerModel(
            farmer_id=farmer_id,
            full_name=fallback_name,
            phone_number=None,
            state=(farm.state if farm else "Maharashtra"),
            district=(farm.district if farm else "Pune"),
            taluka=(farm.taluka if farm else "Baramati"),
            village=(farm.village if farm else None),
            preferred_language="en",
        )
        db.add(existing_farmer)
        db.flush()

    if not link:
        db.add(
            FarmerUserAccountModel(
                id=str(uuid.uuid4()),
                auth_provider="cropnet",
                auth_user_id=uid_str,
                farmer_id=existing_farmer.farmer_id,
            )
        )
    db.commit()
    db.refresh(existing_farmer)
    return existing_farmer


def _get_farm_plots_and_cycles(
    db: Session, farm_id_str: str
) -> Tuple[List[FarmPlotModel], List[CropCycleModel]]:
    plots = (
        db.query(FarmPlotModel)
        .filter(FarmPlotModel.farm_id == farm_id_str)
        .order_by(FarmPlotModel.created_at.asc())
        .all()
    )
    if not plots:
        return [], []
    plot_ids = [p.plot_id for p in plots]
    cycles = (
        db.query(CropCycleModel)
        .filter(CropCycleModel.plot_id.in_(plot_ids))
        .order_by(CropCycleModel.created_at.desc())
        .all()
    )
    return plots, cycles


def build_shared_context_response(
    db: Session,
    current_user: CurrentUser,
    cropnet_farm: CropNetFarmModel,
) -> SharedFarmContextResponse:
    farm_id_str = str(cropnet_farm.id)
    farmer = get_or_link_farmer_for_user(db, current_user, farm=cropnet_farm, create_if_missing=True)
    plots, cycles = _get_farm_plots_and_cycles(db, farm_id_str)
    plot_map = {p.plot_id: p for p in plots}

    cycle_dtos: List[CropCycleResponse] = []
    active_cycle: Optional[CropCycleModel] = None
    active_stage_info: Optional[Dict[str, Any]] = None

    for c in cycles:
        st_info = CropStageService.estimate_crop_stage(
            db=db,
            crop_code=c.crop_code,
            sowing_date=c.sowing_date,
            farmer_confirmed_stage=c.current_stage_code,
        )
        if c.is_active and active_cycle is None:
            active_cycle = c
            active_stage_info = st_info
        p = plot_map.get(c.plot_id)
        cycle_dtos.append(
            CropCycleResponse(
                cycle_id=c.cycle_id,
                plot_id=c.plot_id,
                plot_name=(p.plot_name if p else "Main Plot"),
                farm_id=farm_id_str,
                crop_code=c.crop_code,
                variety_name=c.variety_name,
                season=c.season,
                sowing_date=c.sowing_date,
                planted_area_acres=c.planted_area_acres or (p.area_acres if p else None),
                irrigation_type=(p.irrigation_type if p else cropnet_farm.irrigation_type),
                current_stage_code=c.current_stage_code,
                estimated_stage_code=st_info.get("stage_code"),
                estimated_stage_name=st_info.get("stage_name_en"),
                days_after_sowing=st_info.get("days_after_sowing"),
                is_active=bool(c.is_active),
            )
        )

    water_sources = db.query(WaterSourceModel).filter(WaterSourceModel.farm_id == farm_id_str).all()
    mapped_water = map_cropnet_water_to_rashkar(
        cropnet_farm.irrigation_type,
        cropnet_farm.water_source,
        water_sources=water_sources,
    )

    res_rec = (
        db.query(FarmerResourceProfileModel)
        .filter(FarmerResourceProfileModel.farm_id == farm_id_str)
        .first()
    )

    total_acres = round(float(cropnet_farm.calculated_area_acres or 0.0), 2)
    planted_sum = round(sum((c.planted_area_acres or 0.0) for c in cycles if c.is_active), 2)
    effective_water = (res_rec.water_availability if res_rec and res_rec.water_availability else mapped_water)

    # Check genuinely missing fields (never fabricate defaults!)
    worker_missing: List[str] = []
    if farmer.default_workload_category is None:
        worker_missing.append("workload_category")
    if farmer.default_sun_exposure is None:
        worker_missing.append("sun_exposure")
    if farmer.default_is_acclimatised is None:
        worker_missing.append("is_acclimatised")
    if farmer.default_clothing_type is None:
        worker_missing.append("clothing_type")
    if farmer.default_exposure_duration_hours is None:
        worker_missing.append("exposure_duration_hours")

    crop_missing: List[str] = [] if active_cycle is not None else ["crop_code", "season", "sowing_date"]

    income_missing: List[str] = []
    if res_rec is None or not bool(res_rec.profile_completed):
        if not res_rec or res_rec.available_investment_inr is None:
            income_missing.append("available_investment_inr")
        if not res_rec or res_rec.unused_land_acres is None:
            income_missing.append("unused_land_acres")
        if effective_water is None:
            income_missing.append("water_availability")
        if not res_rec or res_rec.family_labor_hours_day is None:
            income_missing.append("family_labor_hours_day")

    # Auto-derive assets & byproducts strictly from real recorded plots/crops (never invent)
    derived_assets: List[str] = list(res_rec.existing_assets or []) if res_rec else []
    if (cropnet_farm.irrigation_type or "").lower() == "drip" and "drip" not in derived_assets:
        derived_assets.append("drip")

    res_dto = SharedResourceProfileDTO(
        farm_id=farm_id_str,
        farmer_id=farmer.farmer_id,
        profile_completed=bool(res_rec and res_rec.profile_completed),
        missing_fields=income_missing,
        available_investment_inr=res_rec.available_investment_inr if res_rec else None,
        monthly_operating_budget_inr=res_rec.monthly_operating_budget_inr if res_rec else None,
        max_risk_capital_inr=res_rec.max_risk_capital_inr if res_rec else None,
        willing_to_borrow=res_rec.willing_to_borrow if res_rec else None,
        total_farm_acres=total_acres,
        cultivated_acres=(
            res_rec.cultivated_acres
            if res_rec and res_rec.cultivated_acres is not None
            else (planted_sum if planted_sum > 0 else None)
        ),
        available_land_acres=res_rec.available_land_acres if res_rec else None,
        unused_land_acres=res_rec.unused_land_acres if res_rec else None,
        field_bunds_available=res_rec.field_bunds_available if res_rec else None,
        has_animal_shed=res_rec.has_animal_shed if res_rec else None,
        has_storage_room=res_rec.has_storage_room if res_rec else None,
        has_shaded_space=res_rec.has_shaded_space if res_rec else None,
        water_availability=effective_water,
        water_months_available=(res_rec.water_months_available or []) if res_rec else [],
        family_labor_hours_day=res_rec.family_labor_hours_day if res_rec else None,
        hired_labor_possible=res_rec.hired_labor_possible if res_rec else None,
        existing_livestock=res_rec.existing_livestock if res_rec else None,
        existing_assets=derived_assets,
        crop_byproducts=(res_rec.crop_byproducts or []) if res_rec else [],
        byproduct_surplus_available=res_rec.byproduct_surplus_available if res_rec else None,
        interests=(res_rec.interests or []) if res_rec else [],
        has_transport=res_rec.has_transport if res_rec else None,
        has_fpo_access=res_rec.has_fpo_access if res_rec else None,
        distance_to_apmc_km=res_rec.distance_to_apmc_km if res_rec else None,
        risk_tolerance=res_rec.risk_tolerance if res_rec else None,
        category_preference=(res_rec.category_preference if res_rec else "all"),
        age_range=(res_rec.age_range if res_rec and res_rec.age_range else farmer.age_range),
        work_preference=(res_rec.work_preference if res_rec and res_rec.work_preference else farmer.work_preference),
        payback_horizon=(res_rec.payback_horizon if res_rec and res_rec.payback_horizon else farmer.payback_horizon),
        family_management_role=(
            res_rec.family_management_role
            if res_rec and res_rec.family_management_role
            else farmer.family_management_role
        ),
        current_crop_code=(active_cycle.crop_code if active_cycle else (res_rec.current_crop_code if res_rec else None)),
        current_crop_stage=(
            active_stage_info.get("stage_code")
            if active_stage_info
            else (res_rec.current_crop_stage if res_rec else None)
        ),
    )

    farmer_dto = SharedFarmerProfileData(
        farmer_id=farmer.farmer_id,
        full_name=farmer.full_name,
        phone_number=farmer.phone_number,
        preferred_language=farmer.preferred_language or "en",
        age_range=farmer.age_range,
        work_preference=farmer.work_preference,
        payback_horizon=farmer.payback_horizon,
        family_management_role=farmer.family_management_role,
        default_workload_category=farmer.default_workload_category,
        default_clothing_type=farmer.default_clothing_type,
        default_is_acclimatised=farmer.default_is_acclimatised,
        default_sun_exposure=farmer.default_sun_exposure,
        default_exposure_duration_hours=farmer.default_exposure_duration_hours,
    )

    return SharedFarmContextResponse(
        farm_id=farm_id_str,
        farm_name=cropnet_farm.name,
        taluka=cropnet_farm.taluka,
        district=cropnet_farm.district,
        state=cropnet_farm.state,
        village=cropnet_farm.village,
        latitude=float(cropnet_farm.centroid_latitude or 18.18),
        longitude=float(cropnet_farm.centroid_longitude or 74.53),
        total_area_acres=total_acres,
        total_area_hectares=round(float(cropnet_farm.calculated_area_hectares or 0.0), 2),
        irrigation_type=cropnet_farm.irrigation_type,
        water_source=cropnet_farm.water_source,
        farmer_profile=farmer_dto,
        plots=[
            FarmPlotResponse(
                plot_id=p.plot_id,
                farm_id=farm_id_str,
                plot_name=p.plot_name,
                area_acres=p.area_acres,
                irrigation_type=p.irrigation_type,
                created_at=p.created_at,
            )
            for p in plots
        ],
        crop_cycles=cycle_dtos,
        resource_profile=res_dto,
        worker_heat_missing_fields=worker_missing,
        crop_heat_missing_fields=crop_missing,
        extra_income_missing_fields=income_missing,
    )


def update_shared_context(
    db: Session,
    current_user: CurrentUser,
    cropnet_farm: CropNetFarmModel,
    payload: SharedFarmContextUpdateRequest,
) -> SharedFarmContextResponse:
    farm_id_str = str(cropnet_farm.id)
    farmer = get_or_link_farmer_for_user(db, current_user, farm=cropnet_farm, create_if_missing=True)

    if payload.farmer_profile is not None:
        fp = payload.farmer_profile
        if fp.full_name is not None:
            farmer.full_name = fp.full_name
        if fp.phone_number is not None:
            farmer.phone_number = fp.phone_number
        if fp.preferred_language is not None:
            farmer.preferred_language = fp.preferred_language
        if fp.age_range is not None:
            farmer.age_range = fp.age_range
        if fp.work_preference is not None:
            farmer.work_preference = fp.work_preference
        if fp.payback_horizon is not None:
            farmer.payback_horizon = fp.payback_horizon
        if fp.family_management_role is not None:
            farmer.family_management_role = fp.family_management_role
        if fp.default_workload_category is not None:
            farmer.default_workload_category = fp.default_workload_category
        if fp.default_clothing_type is not None:
            farmer.default_clothing_type = fp.default_clothing_type
        if fp.default_is_acclimatised is not None:
            farmer.default_is_acclimatised = fp.default_is_acclimatised
        if fp.default_sun_exposure is not None:
            farmer.default_sun_exposure = fp.default_sun_exposure
        if fp.default_exposure_duration_hours is not None:
            farmer.default_exposure_duration_hours = fp.default_exposure_duration_hours
        farmer.updated_at = now_utc()

    if payload.resource_profile is not None:
        save_resource_profile_shared(db, current_user, cropnet_farm, payload.resource_profile)

    db.commit()
    return build_shared_context_response(db, current_user, cropnet_farm)


def save_resource_profile_shared(
    db: Session,
    current_user: CurrentUser,
    cropnet_farm: CropNetFarmModel,
    profile: FarmerResourceProfile,
) -> SharedResourceProfileDTO:
    farm_id_str = str(cropnet_farm.id)
    farmer = get_or_link_farmer_for_user(db, current_user, farm=cropnet_farm, create_if_missing=True)

    record = (
        db.query(FarmerResourceProfileModel)
        .filter(FarmerResourceProfileModel.farm_id == farm_id_str)
        .first()
    )
    if not record:
        record = FarmerResourceProfileModel(farm_id=farm_id_str, farmer_id=farmer.farmer_id)
        db.add(record)

    record.farmer_id = farmer.farmer_id
    record.available_investment_inr = profile.available_investment_inr
    record.monthly_operating_budget_inr = profile.monthly_operating_budget_inr
    record.max_risk_capital_inr = profile.max_risk_capital_inr
    record.willing_to_borrow = profile.willing_to_borrow
    # Always preserve CropNet farm total area if omitted
    record.total_farm_acres = (
        profile.total_farm_acres
        if profile.total_farm_acres is not None
        else float(cropnet_farm.calculated_area_acres)
    )
    record.cultivated_acres = profile.cultivated_acres
    record.available_land_acres = profile.available_land_acres
    record.unused_land_acres = profile.unused_land_acres
    record.field_bunds_available = profile.field_bunds_available
    record.has_animal_shed = profile.has_animal_shed
    record.has_storage_room = profile.has_storage_room
    record.has_shaded_space = profile.has_shaded_space
    record.water_availability = profile.water_availability
    record.water_months_available = profile.water_months_available
    record.family_labor_hours_day = profile.family_labor_hours_day
    record.hired_labor_possible = profile.hired_labor_possible
    record.existing_livestock = profile.existing_livestock
    record.existing_assets = profile.existing_assets
    record.crop_byproducts = profile.crop_byproducts
    record.byproduct_surplus_available = profile.byproduct_surplus_available
    record.interests = profile.interests
    record.has_transport = profile.has_transport
    record.has_fpo_access = profile.has_fpo_access
    record.distance_to_apmc_km = profile.distance_to_apmc_km
    record.risk_tolerance = profile.risk_tolerance
    record.category_preference = profile.category_preference
    record.age_range = profile.age_range
    record.work_preference = profile.work_preference
    record.payback_horizon = profile.payback_horizon
    record.family_management_role = profile.family_management_role
    record.current_crop_code = profile.current_crop_code
    record.current_crop_stage = profile.current_crop_stage
    record.profile_completed = True
    record.updated_at_utc = now_utc()

    # Sync shared farmer-level personal attributes back to `farmers` table
    if profile.age_range is not None:
        farmer.age_range = profile.age_range
    if profile.work_preference is not None:
        farmer.work_preference = profile.work_preference
    if profile.payback_horizon is not None:
        farmer.payback_horizon = profile.payback_horizon
    if profile.family_management_role is not None:
        farmer.family_management_role = profile.family_management_role

    db.commit()
    return build_shared_context_response(db, current_user, cropnet_farm).resource_profile


def build_income_engine_profile(
    db: Session,
    current_user: CurrentUser,
    cropnet_farm: CropNetFarmModel,
    override: Optional[FarmerResourceProfile] = None,
) -> FarmerResourceProfile:
    """
    Hydrates Rashkar's `FarmerResourceProfile` strictly from CropNet's registered farm,
    shared farmer profile, active crop cycle, and saved resource profile.
    Raises MissingSharedContextError if farmer has not yet provided resource profile answers.
    """
    if override is not None:
        # Always inject live CropNet total_farm_acres & active crop if not explicitly passed
        ctx = build_shared_context_response(db, current_user, cropnet_farm)
        updates: Dict[str, Any] = {}
        if override.total_farm_acres is None:
            updates["total_farm_acres"] = ctx.total_area_acres
        if override.current_crop_code is None and ctx.resource_profile.current_crop_code:
            updates["current_crop_code"] = ctx.resource_profile.current_crop_code
        if override.current_crop_stage is None and ctx.resource_profile.current_crop_stage:
            updates["current_crop_stage"] = ctx.resource_profile.current_crop_stage
        return override.model_copy(update=updates) if updates else override

    ctx = build_shared_context_response(db, current_user, cropnet_farm)
    if not ctx.resource_profile.profile_completed:
        raise MissingSharedContextError(
            feature="extra_income",
            missing_fields=ctx.extra_income_missing_fields or INCOME_REQUIRED_FIELDS,
            message=(
                "Farmer resource profile details have not been confirmed yet for this farm. "
                "Please answer the missing resource questions once to personalize income opportunities."
            ),
        )

    rp = ctx.resource_profile
    return FarmerResourceProfile(
        available_investment_inr=float(rp.available_investment_inr or 0.0),
        monthly_operating_budget_inr=float(rp.monthly_operating_budget_inr or 0.0),
        max_risk_capital_inr=rp.max_risk_capital_inr,
        willing_to_borrow=bool(rp.willing_to_borrow) if rp.willing_to_borrow is not None else False,
        total_farm_acres=rp.total_farm_acres,
        cultivated_acres=rp.cultivated_acres,
        available_land_acres=float(rp.available_land_acres or 0.0),
        unused_land_acres=float(rp.unused_land_acres or 0.0),
        field_bunds_available=bool(rp.field_bunds_available) if rp.field_bunds_available is not None else True,
        has_animal_shed=bool(rp.has_animal_shed) if rp.has_animal_shed is not None else False,
        has_storage_room=bool(rp.has_storage_room) if rp.has_storage_room is not None else False,
        has_shaded_space=bool(rp.has_shaded_space) if rp.has_shaded_space is not None else False,
        water_availability=rp.water_availability or "unknown",
        water_months_available=rp.water_months_available,
        family_labor_hours_day=float(rp.family_labor_hours_day if rp.family_labor_hours_day is not None else 0.0),
        hired_labor_possible=bool(rp.hired_labor_possible) if rp.hired_labor_possible is not None else False,
        existing_livestock=rp.existing_livestock or "none",
        existing_assets=rp.existing_assets,
        crop_byproducts=rp.crop_byproducts,
        byproduct_surplus_available=bool(rp.byproduct_surplus_available) if rp.byproduct_surplus_available is not None else False,
        interests=rp.interests,
        has_transport=bool(rp.has_transport) if rp.has_transport is not None else False,
        has_fpo_access=bool(rp.has_fpo_access) if rp.has_fpo_access is not None else False,
        distance_to_apmc_km=rp.distance_to_apmc_km,
        risk_tolerance=rp.risk_tolerance or "moderate",
        category_preference=rp.category_preference or "all",
        age_range=rp.age_range or "prefer_not_to_say",
        work_preference=rp.work_preference or "daily_physical",
        payback_horizon=rp.payback_horizon or "within_6_months",
        family_management_role=rp.family_management_role or "self",
        current_crop_code=rp.current_crop_code,
        current_crop_stage=rp.current_crop_stage,
    )


def assess_worker_heat_for_farm(
    db: Session,
    current_user: CurrentUser,
    cropnet_farm: CropNetFarmModel,
    payload: FarmWorkerHeatAssessRequest,
    weather_hourly_override: Optional[List[Dict[str, float]]] = None,
) -> WorkerHeatAssessmentResponse:
    """
    Translates CropNet farm coordinates/taluka + shared Farmer worker defaults
    (with optional single-assessment overrides) into exact Rashkar `WorkerHeatAssessmentRequest`
    and executes unmodified `WorkerHeatEngine`.
    """
    farmer = get_or_link_farmer_for_user(db, current_user, farm=cropnet_farm, create_if_missing=True)

    workload = payload.workload_category if payload.workload_category is not None else farmer.default_workload_category
    clothing = payload.clothing_type if payload.clothing_type is not None else farmer.default_clothing_type
    acclimatised = payload.is_acclimatised if payload.is_acclimatised is not None else farmer.default_is_acclimatised
    sun = payload.sun_exposure if payload.sun_exposure is not None else farmer.default_sun_exposure
    duration = payload.exposure_duration_hours if payload.exposure_duration_hours is not None else farmer.default_exposure_duration_hours

    missing: List[str] = []
    if workload is None:
        missing.append("workload_category")
    if sun is None:
        missing.append("sun_exposure")
    if acclimatised is None:
        missing.append("is_acclimatised")
    if clothing is None:
        missing.append("clothing_type")
    if duration is None:
        missing.append("exposure_duration_hours")

    if missing:
        raise MissingSharedContextError(
            feature="worker_heat",
            missing_fields=missing,
            message="Worker exposure defaults have not been provided yet. Complete the missing worker inputs once.",
        )

    if payload.save_as_default:
        farmer.default_workload_category = workload
        farmer.default_clothing_type = clothing
        farmer.default_is_acclimatised = acclimatised
        farmer.default_sun_exposure = sun
        farmer.default_exposure_duration_hours = float(duration)
        farmer.updated_at = now_utc()
        db.commit()

    rashkar_req = WorkerHeatAssessmentRequest(
        latitude=float(cropnet_farm.centroid_latitude or 18.18),
        longitude=float(cropnet_farm.centroid_longitude or 74.53),
        taluka=cropnet_farm.taluka,
        workload_category=workload,
        clothing_type=clothing,
        is_acclimatised=bool(acclimatised),
        sun_exposure=sun,
        exposure_duration_hours=float(duration),
    )
    return WorkerHeatEngine.assess_worker_heat_hazard(
        request=rashkar_req,
        db=db,
        weather_hourly_override=weather_hourly_override,
    )


def assess_crop_heat_for_farm(
    db: Session,
    cropnet_farm: CropNetFarmModel,
    payload: FarmCropHeatAssessRequest,
) -> CropHeatAssessmentResponse:
    """
    Translates CropNet farm + registered plot/crop cycle + soil intelligence into exact
    Rashkar `CropHeatAssessmentRequest` via `RashkarAdaptedSession` and executes
    unmodified `CropHeatEngine.assess_crop_heat_risk`.
    Refuses to fabricate demo soybean cycles when a CropNet farm has no planted crop yet.
    """
    farm_id_str = str(cropnet_farm.id)
    plots, cycles = _get_farm_plots_and_cycles(db, farm_id_str)
    active_cycles = [c for c in cycles if c.is_active]

    if payload.cycle_id:
        matching = [c for c in active_cycles if c.cycle_id == payload.cycle_id]
        if not matching:
            raise ValueError(f"Crop cycle '{payload.cycle_id}' not found on farm '{farm_id_str}'.")
        chosen_cycle = matching[0]
        chosen_plot_id = chosen_cycle.plot_id
    elif payload.plot_id:
        matching = [c for c in active_cycles if c.plot_id == payload.plot_id]
        if not matching:
            raise MissingSharedContextError(
                feature="crop_heat",
                missing_fields=["crop_code", "season", "sowing_date"],
                message=f"Selected plot '{payload.plot_id}' has no active registered crop.",
            )
        chosen_cycle = matching[0]
        chosen_plot_id = payload.plot_id
    else:
        if not active_cycles:
            raise MissingSharedContextError(
                feature="crop_heat",
                missing_fields=["crop_code", "season", "sowing_date"],
                message=(
                    "No planted crop is registered for this farm yet. Register your crop and sowing date once "
                    "to run Crop Heat Risk."
                ),
            )
        chosen_cycle = active_cycles[0]
        chosen_plot_id = chosen_cycle.plot_id

    rashkar_req = CropHeatAssessmentRequest(
        farm_id=farm_id_str,
        plot_id=chosen_plot_id,
        farmer_confirmed_stage=payload.farmer_confirmed_stage,
        forecast_tmax_c=payload.forecast_tmax_c,
        forecast_tmin_c=payload.forecast_tmin_c,
        forecast_sun_hours=payload.forecast_sun_hours,
    )
    adapted_db = RashkarAdaptedSession(
        real_db=db,
        cropnet_farm=cropnet_farm,
        specific_cycle_id=chosen_cycle.cycle_id,
    )
    return CropHeatEngine.assess_crop_heat_risk(db=adapted_db, request=rashkar_req)


def upsert_plot_for_farm(
    db: Session,
    cropnet_farm: CropNetFarmModel,
    payload: FarmPlotUpsertRequest,
) -> FarmPlotResponse:
    farm_id_str = str(cropnet_farm.id)
    plot = FarmPlotModel(
        plot_id=f"plot_{uuid.uuid4().hex[:10]}",
        farm_id=farm_id_str,
        plot_name=payload.plot_name,
        area_acres=float(payload.area_acres),
        irrigation_type=payload.irrigation_type or cropnet_farm.irrigation_type or "rainfed",
    )
    db.add(plot)
    db.commit()
    db.refresh(plot)
    return FarmPlotResponse(
        plot_id=plot.plot_id,
        farm_id=farm_id_str,
        plot_name=plot.plot_name,
        area_acres=plot.area_acres,
        irrigation_type=plot.irrigation_type,
        created_at=plot.created_at,
    )


def upsert_crop_cycle_for_farm(
    db: Session,
    cropnet_farm: CropNetFarmModel,
    payload: CropCycleUpsertRequest,
) -> CropCycleResponse:
    farm_id_str = str(cropnet_farm.id)
    plot: Optional[FarmPlotModel] = None
    if payload.plot_id:
        plot = (
            db.query(FarmPlotModel)
            .filter(FarmPlotModel.plot_id == payload.plot_id, FarmPlotModel.farm_id == farm_id_str)
            .first()
        )
        if not plot:
            raise ValueError(f"Plot '{payload.plot_id}' does not belong to farm '{farm_id_str}'.")
    else:
        plot = (
            db.query(FarmPlotModel)
            .filter(FarmPlotModel.farm_id == farm_id_str)
            .order_by(FarmPlotModel.created_at.asc())
            .first()
        )
        if not plot:
            plot = FarmPlotModel(
                plot_id=f"plot_{uuid.uuid4().hex[:10]}",
                farm_id=farm_id_str,
                plot_name=payload.plot_name or "Main Plot 1",
                area_acres=float(payload.planted_area_acres or cropnet_farm.calculated_area_acres or 1.0),
                irrigation_type=payload.irrigation_type or cropnet_farm.irrigation_type or "rainfed",
            )
            db.add(plot)
            db.flush()

    if payload.irrigation_type:
        plot.irrigation_type = payload.irrigation_type

    cycle = CropCycleModel(
        cycle_id=f"cycle_{uuid.uuid4().hex[:10]}",
        plot_id=plot.plot_id,
        crop_code=payload.crop_code.strip().lower(),
        variety_name=payload.variety_name,
        season=payload.season.strip().lower(),
        sowing_date=payload.sowing_date,
        planted_area_acres=payload.planted_area_acres or plot.area_acres,
        current_stage_code=payload.farmer_confirmed_stage,
        is_active=True,
    )
    db.add(cycle)
    db.commit()
    db.refresh(cycle)

    st_info = CropStageService.estimate_crop_stage(
        db=db,
        crop_code=cycle.crop_code,
        sowing_date=cycle.sowing_date,
        farmer_confirmed_stage=cycle.current_stage_code,
    )
    return CropCycleResponse(
        cycle_id=cycle.cycle_id,
        plot_id=plot.plot_id,
        plot_name=plot.plot_name,
        farm_id=farm_id_str,
        crop_code=cycle.crop_code,
        variety_name=cycle.variety_name,
        season=cycle.season,
        sowing_date=cycle.sowing_date,
        planted_area_acres=cycle.planted_area_acres,
        irrigation_type=plot.irrigation_type,
        current_stage_code=cycle.current_stage_code,
        estimated_stage_code=st_info.get("stage_code"),
        estimated_stage_name=st_info.get("stage_name_en"),
        days_after_sowing=st_info.get("days_after_sowing"),
        is_active=True,
    )
