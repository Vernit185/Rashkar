"""Ported Rashkar heat defect correction test suite executed through CropNet models & RashkarAdaptedSession."""
import uuid
from datetime import date, timedelta
import pytest

from cropnet.services.api.app.models.soil_and_farm import FarmModel as CropNetFarmModel
from cropnet.services.api.app.models.rashkar_profiles import (
    FarmPlotModel,
    CropCycleModel,
    CropHeatAssessmentLogModel,
)
from cropnet.services.api.app.schemas.rashkar.worker_heat import WorkerHeatAssessmentRequest
from cropnet.services.api.app.schemas.rashkar.crop_heat import CropHeatAssessmentRequest
from cropnet.services.api.app.services.rashkar.worker_heat_engine import WorkerHeatEngine
from cropnet.services.api.app.services.rashkar.crop_heat_engine import CropHeatEngine
from cropnet.services.api.app.services.rashkar.crop_stage_service import CropStageService
from cropnet.services.api.app.services.rashkar.adapters import RashkarAdaptedSession


def create_isolated_farm(db_session, crop_code="soybean", sowing_days_ago=45, variety="JS 335"):
    uid = uuid.uuid4().hex[:8]
    farm = CropNetFarmModel(
        id=str(uuid.uuid4()),
        owner_id="00000000-0000-0000-0000-000000000001",
        name=f"Test Farm {uid}",
        district="Pune",
        taluka="Baramati",
        state="Maharashtra",
        irrigation_type="drip",
        water_source="canal",
        geometry_geojson={"type": "Polygon", "coordinates": [[[73.85, 18.51], [73.86, 18.51], [73.86, 18.52], [73.85, 18.51]]]},
        calculated_area_hectares=1.21,
        calculated_area_acres=3.0,
        centroid_latitude=18.5204,
        centroid_longitude=73.8567,
    )
    db_session.add(farm)
    plot = FarmPlotModel(
        plot_id=f"plot_{uid}",
        farm_id=farm.id,
        plot_name="Plot A",
        area_acres=3.0,
        irrigation_type="drip",
    )
    db_session.add(plot)
    cycle = CropCycleModel(
        cycle_id=f"cycle_{uid}",
        plot_id=plot.plot_id,
        crop_code=crop_code,
        season="kharif",
        sowing_date=date.today() - timedelta(days=sowing_days_ago),
        variety_name=variety,
        is_active=True,
    )
    db_session.add(cycle)
    db_session.commit()
    return farm, plot, cycle


def test_wbgt_below_threshold():
    cool_hourly = [{"air_temp_c": 18.0, "rh_pct": 40.0, "wind_ms": 2.5, "solar_wm2": 50.0} for _ in range(7)]
    req = WorkerHeatAssessmentRequest(
        latitude=18.5204, longitude=73.8567, workload_category="very_heavy",
        is_acclimatised=False, clothing_type="standard_work_clothes",
        sun_exposure="full_shade", exposure_duration_hours=4.0,
    )
    result = WorkerHeatEngine.assess_worker_heat_hazard(req, weather_hourly_override=cool_hourly)
    assert result.threshold_comparison_state == "BELOW"
    assert result.threshold_difference_c < 0.0
    assert "below the 22.0" in result.threshold_comparison_message
    assert "exceed" not in result.threshold_comparison_message.lower()


def test_wbgt_at_threshold():
    msg, diff, state = WorkerHeatEngine._build_threshold_comparison(26.0, 26.0, "heavy")
    assert state == "AT_THRESHOLD"
    assert diff == 0.0
    assert "is at the 26.0" in msg


def test_wbgt_above_threshold():
    hot_hourly = [{"air_temp_c": 42.0, "rh_pct": 65.0, "wind_ms": 1.0, "solar_wm2": 950.0} for _ in range(7)]
    req = WorkerHeatAssessmentRequest(
        latitude=18.5204, longitude=73.8567, workload_category="very_heavy",
        is_acclimatised=False, clothing_type="standard_work_clothes",
        sun_exposure="direct_sun", exposure_duration_hours=5.0,
    )
    result = WorkerHeatEngine.assess_worker_heat_hazard(req, weather_hourly_override=hot_hourly)
    assert result.threshold_comparison_state == "ABOVE"
    assert result.threshold_difference_c > 0.0
    assert "exceeds the 22.0" in result.threshold_comparison_message


def test_shift_duration_longer_than_forecast_coverage():
    req = WorkerHeatAssessmentRequest(
        latitude=18.5204, longitude=73.8567, workload_category="moderate", exposure_duration_hours=7.5
    )
    result = WorkerHeatEngine.assess_worker_heat_hazard(req)
    assert result.shift_exceeds_forecast_coverage is True
    assert result.planned_shift_duration_hours == 7.5
    assert result.forecast_coverage_hours == 6.0
    assert result.coverage_limitation_warning is not None
    assert "covers a 6-hour window" in result.coverage_limitation_warning
    assert "planned shift is 7.5 hours" in result.coverage_limitation_warning


def test_weather_provenance_and_missing_variables():
    req = WorkerHeatAssessmentRequest(
        latitude=18.5204, longitude=73.8567, workload_category="moderate", exposure_duration_hours=4.0
    )
    result = WorkerHeatEngine.assess_worker_heat_hazard(req)
    assert "0.1" in result.spatial_resolution
    assert "18.5204" in result.grid_coordinates
    assert "ACGIH 2023" in result.methodology_standards_version
    assert "screening" in result.safety_guarantee_disclaimer.lower()
    assert "108" in result.local_emergency_contacts["ambulance_toll_free"]
    assert "1800-180-1551" in result.local_emergency_contacts["kisan_call_centre"]


def test_missing_solar_graceful_handling():
    no_solar_hourly = [{"air_temp_c": 32.0, "rh_pct": 50.0, "wind_ms": 1.5, "solar_wm2": 0.0} for _ in range(7)]
    req = WorkerHeatAssessmentRequest(
        latitude=18.5204, longitude=73.8567, workload_category="moderate", sun_exposure="full_shade"
    )
    result = WorkerHeatEngine.assess_worker_heat_hazard(req, weather_hourly_override=no_solar_hourly)
    assert result.max_wbgt_effective_c > 0.0
    assert result.current_hazard_level in ["LOW", "MODERATE", "HIGH", "CRITICAL"]


def test_expired_crop_season_detection(isolated_test_session):
    db_session = isolated_test_session
    farm, plot, cycle = create_isolated_farm(db_session, crop_code="soybean", sowing_days_ago=800, variety="JS 335")
    stage_info = CropStageService.estimate_growth_stage(db_session, "soybean", cycle.sowing_date)
    assert stage_info["is_expired"] is True
    assert stage_info["stage_code"] is None
    assert stage_info["season_status"] == "EXPIRED"

    adapted = RashkarAdaptedSession(db_session, farm)
    assessment = CropHeatEngine.assess_crop_heat_risk(
        adapted, CropHeatAssessmentRequest(farm_id=farm.id, plot_id=plot.plot_id, forecast_tmax_c=38.0, forecast_tmin_c=24.0)
    )
    assert assessment.is_season_expired is True
    assert assessment.season_status == "EXPIRED"
    assert assessment.requires_season_update is True
    assert "Crop season expired" in assessment.season_expiry_message
    assert len(assessment.recommended_interventions) == 0


def test_null_crop_stage_suppresses_stage_interventions(isolated_test_session):
    db_session = isolated_test_session
    farm, plot, _cycle = create_isolated_farm(db_session, crop_code="soybean", sowing_days_ago=500)
    adapted = RashkarAdaptedSession(db_session, farm)
    assessment = CropHeatEngine.assess_crop_heat_risk(
        adapted, CropHeatAssessmentRequest(farm_id=farm.id, plot_id=plot.plot_id)
    )
    assert assessment.growth_stage_code is None
    assert len(assessment.recommended_interventions) == 0


def test_farmer_confirmed_crop_stage_change(isolated_test_session):
    db_session = isolated_test_session
    farm, plot, _cycle = create_isolated_farm(db_session, crop_code="soybean", sowing_days_ago=20, variety="JS 93-05")
    adapted = RashkarAdaptedSession(db_session, farm)
    assessment = CropHeatEngine.assess_crop_heat_risk(
        adapted,
        CropHeatAssessmentRequest(
            farm_id=farm.id, plot_id=plot.plot_id,
            farmer_confirmed_stage="stage_flowering", forecast_tmax_c=37.0, forecast_tmin_c=23.0,
        ),
    )
    assert "flower" in assessment.growth_stage_code.lower()
    assert assessment.farmer_confirmed_stage == "stage_flowering"
    assert assessment.critical_tmax_threshold_c == 35.0


def test_synthetic_soil_profile_labeling(isolated_test_session):
    db_session = isolated_test_session
    farm, plot, _cycle = create_isolated_farm(db_session, crop_code="soybean", sowing_days_ago=45)
    adapted = RashkarAdaptedSession(db_session, farm)
    assessment = CropHeatEngine.assess_crop_heat_risk(
        adapted,
        CropHeatAssessmentRequest(farm_id=farm.id, plot_id=plot.plot_id, forecast_tmax_c=36.0, forecast_tmin_c=22.0),
    )
    assert assessment.is_soil_synthetic is True
    assert "CropNet Model Estimate (Unsampled Farm Coordinate)" in assessment.soil_provenance_label


def test_invalid_crop_threshold_fallback(isolated_test_session):
    db_session = isolated_test_session
    farm, plot, _cycle = create_isolated_farm(db_session, crop_code="dragonfruit_exotic", sowing_days_ago=30)
    adapted = RashkarAdaptedSession(db_session, farm)
    assessment = CropHeatEngine.assess_crop_heat_risk(
        adapted,
        CropHeatAssessmentRequest(farm_id=farm.id, plot_id=plot.plot_id, forecast_tmax_c=37.0, forecast_tmin_c=22.0),
    )
    assert assessment.base_temp_c == 10.0
    assert assessment.critical_tmax_threshold_c == 36.0
    assert assessment.optimal_temp_min_c == 25.0
    assert assessment.optimal_temp_max_c == 30.0


def test_audited_interventions_and_infrastructure_distinction(isolated_test_session):
    db_session = isolated_test_session
    farm, plot, _cycle = create_isolated_farm(db_session, crop_code="soybean", sowing_days_ago=45)
    adapted = RashkarAdaptedSession(db_session, farm)
    assessment = CropHeatEngine.assess_crop_heat_risk(
        adapted,
        CropHeatAssessmentRequest(
            farm_id=farm.id, plot_id=plot.plot_id,
            farmer_confirmed_stage="stage_flowering", forecast_tmax_c=39.0, forecast_tmin_c=25.0,
        ),
    )
    assert len(assessment.recommended_interventions) > 0
    for inv in assessment.recommended_interventions:
        assert inv.evidence_status == "VERIFIED_PUBLISHED"
        assert inv.agronomist_reviewer is not None and len(inv.agronomist_reviewer) > 0
        assert inv.evidence_citation is not None and len(inv.evidence_citation) > 0
        assert inv.application_dose is not None
        assert inv.infrastructure_requirements is not None
        if "drip" in inv.title_en.lower():
            assert "drip" in inv.infrastructure_requirements.lower()
        if "sprinkler" in inv.title_en.lower():
            assert "sprinkler" in inv.infrastructure_requirements.lower()


def test_low_heat_risk_conditionality(isolated_test_session):
    db_session = isolated_test_session
    farm, plot, _cycle = create_isolated_farm(db_session, crop_code="soybean", sowing_days_ago=45)
    adapted = RashkarAdaptedSession(db_session, farm)
    assessment = CropHeatEngine.assess_crop_heat_risk(
        adapted,
        CropHeatAssessmentRequest(
            farm_id=farm.id, plot_id=plot.plot_id,
            farmer_confirmed_stage="stage_flowering", forecast_tmax_c=26.0, forecast_tmin_c=18.0,
        ),
    )
    assert assessment.overall_crop_heat_risk == "low"
    assert len(assessment.recommended_interventions) == 1
    assert assessment.recommended_interventions[0].intervention_id == "ROUTINE_MONITORING"
    assert "Routine" in assessment.recommended_interventions[0].title_en


def test_database_log_history_retrieval(isolated_test_session):
    db_session = isolated_test_session
    farm, plot, cycle = create_isolated_farm(db_session, crop_code="onion", sowing_days_ago=40, variety="Bhima Super")
    adapted = RashkarAdaptedSession(db_session, farm)
    req = CropHeatAssessmentRequest(farm_id=farm.id, plot_id=plot.plot_id, forecast_tmax_c=35.0, forecast_tmin_c=20.0)
    db_session.query(CropHeatAssessmentLogModel).filter(CropHeatAssessmentLogModel.farm_id == farm.id).delete()
    db_session.commit()

    assessment1 = CropHeatEngine.assess_crop_heat_risk(adapted, req)
    assert len(assessment1.assessment_history) == 0

    assessment2 = CropHeatEngine.assess_crop_heat_risk(adapted, req)
    assert len(assessment2.assessment_history) == 1
    assert assessment2.assessment_history[0]["crop_code"] == cycle.crop_code
