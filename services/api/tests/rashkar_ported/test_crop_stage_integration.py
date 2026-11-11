"""Ported Rashkar crop-stage integration tests run through RashkarAdaptedSession."""
import uuid
from datetime import date, timedelta
import pytest

from cropnet.services.api.app.models.soil_and_farm import FarmModel as CropNetFarmModel
from cropnet.services.api.app.models.rashkar_profiles import FarmPlotModel, CropCycleModel
from cropnet.services.api.app.services.rashkar.crop_heat_engine import CROP_SPECIES_PHYSIOLOGY, CropHeatEngine
from cropnet.services.api.app.schemas.rashkar.crop_heat import CropHeatAssessmentRequest
from cropnet.services.api.app.services.rashkar.adapters import RashkarAdaptedSession


def _make_farm_with_cycle(db, crop_code="soybean", sowing_days_ago=35, name="Test Farm"):
    farm = CropNetFarmModel(
        id=str(uuid.uuid4()),
        owner_id="00000000-0000-0000-0000-000000000001",
        name=name,
        taluka="Baramati",
        district="Pune",
        state="Maharashtra",
        irrigation_type="drip",
        water_source="canal",
        geometry_geojson={"type": "Polygon", "coordinates": [[[74.5, 18.1], [74.51, 18.1], [74.51, 18.11], [74.5, 18.1]]]},
        calculated_area_hectares=1.0,
        calculated_area_acres=2.5,
        centroid_latitude=18.15,
        centroid_longitude=74.58,
    )
    db.add(farm)
    plot = FarmPlotModel(
        plot_id=f"plot_{uuid.uuid4().hex[:8]}",
        farm_id=farm.id,
        plot_name="Plot 1",
        area_acres=2.5,
        irrigation_type="drip",
    )
    db.add(plot)
    cycle = CropCycleModel(
        cycle_id=f"cycle_{uuid.uuid4().hex[:8]}",
        plot_id=plot.plot_id,
        crop_code=crop_code,
        season="kharif",
        sowing_date=date.today() - timedelta(days=sowing_days_ago),
        is_active=True,
    )
    db.add(cycle)
    db.commit()
    return farm, plot, cycle


def test_backend_stage_definitions_for_all_supported_crops():
    assert len(CROP_SPECIES_PHYSIOLOGY) >= 4
    for crop_code, spec in CROP_SPECIES_PHYSIOLOGY.items():
        stages = spec.get("stages", [])
        assert len(stages) >= 3
        for s in stages:
            code = s.get("stage_code")
            name = s.get("stage_name")
            name_en = s.get("stage_name_en")
            crit_tmax = s.get("crit_tmax")
            assert code is not None and str(code).strip() != ""
            assert name is not None and str(name).strip() != "" and str(name).lower() != "null"
            assert name_en is not None and str(name_en).strip() != "" and str(name_en).lower() != "null"
            assert isinstance(crit_tmax, (int, float)) and 25.0 <= crit_tmax <= 50.0


def test_unsupported_crop_does_not_fabricate_stages(isolated_test_session):
    db = isolated_test_session
    farm, plot, _cycle = _make_farm_with_cycle(db, crop_code="dragonfruit", name="Unsupported Crop Farm")
    adapted = RashkarAdaptedSession(db, farm)
    res = CropHeatEngine.assess_crop_heat_risk(
        db=adapted,
        request=CropHeatAssessmentRequest(farm_id=farm.id, plot_id=plot.plot_id, forecast_tmax_c=36.0),
    )
    for s in res.supported_stages:
        assert "pod" not in s.get("stage_name", "").lower()
        assert "soybean" not in s.get("stage_name", "").lower()


def test_dynamic_stage_recalculation_changes_threshold_risk_and_interventions(isolated_test_session):
    db = isolated_test_session
    farm, plot, _cycle = _make_farm_with_cycle(db, crop_code="soybean", sowing_days_ago=35)
    adapted = RashkarAdaptedSession(db, farm)

    res_flowering = CropHeatEngine.assess_crop_heat_risk(
        db=adapted,
        request=CropHeatAssessmentRequest(farm_id=farm.id, farmer_confirmed_stage="stage_flowering", forecast_tmax_c=37.0),
    )
    assert res_flowering.critical_tmax_threshold_c == 35.0
    assert res_flowering.overall_crop_heat_risk in ["critical", "high"]
    assert res_flowering.hours_above_critical > 0.0
    assert any(
        "pollen" in i.why_appropriate.lower() or "flower" in i.why_appropriate.lower() or "potassium" in i.title_en.lower()
        for i in res_flowering.recommended_interventions
    )

    res_maturity = CropHeatEngine.assess_crop_heat_risk(
        db=adapted,
        request=CropHeatAssessmentRequest(farm_id=farm.id, farmer_confirmed_stage="stage_maturity", forecast_tmax_c=37.0),
    )
    assert res_maturity.critical_tmax_threshold_c == 42.0
    assert res_maturity.hours_above_critical == 0.0
    assert res_maturity.overall_crop_heat_risk in ["moderate", "low"]
    assert any("harvest" in i.title_en.lower() or "shattering" in i.why_appropriate.lower() for i in res_maturity.recommended_interventions)


def test_season_expiry_suppresses_stage_interventions(isolated_test_session):
    db = isolated_test_session
    farm, _plot, _cycle = _make_farm_with_cycle(db, crop_code="soybean", sowing_days_ago=250)
    adapted = RashkarAdaptedSession(db, farm)
    res = CropHeatEngine.assess_crop_heat_risk(
        db=adapted,
        request=CropHeatAssessmentRequest(farm_id=farm.id, forecast_tmax_c=38.0),
    )
    assert res.is_season_expired is True
    assert res.season_status == "EXPIRED"
    for i in res.recommended_interventions:
        assert "flower abortion" not in i.why_appropriate.lower()
        assert "pod development" not in i.why_appropriate.lower()


def test_invalid_sowing_date_handled_safely(isolated_test_session):
    db = isolated_test_session
    farm, _plot, _cycle = _make_farm_with_cycle(db, crop_code="soybean", sowing_days_ago=-30)
    adapted = RashkarAdaptedSession(db, farm)
    res = CropHeatEngine.assess_crop_heat_risk(
        db=adapted,
        request=CropHeatAssessmentRequest(farm_id=farm.id, forecast_tmax_c=34.0),
    )
    assert res.days_after_sowing == 0
    assert res.assessment_id is not None


def test_farmer_confirmed_stage_persists(isolated_test_session):
    db = isolated_test_session
    farm, _plot, cycle = _make_farm_with_cycle(db, crop_code="soybean", sowing_days_ago=40)
    adapted = RashkarAdaptedSession(db, farm)
    res = CropHeatEngine.assess_crop_heat_risk(
        db=adapted,
        request=CropHeatAssessmentRequest(farm_id=farm.id, farmer_confirmed_stage="stage_vegetative"),
    )
    assert res.farmer_confirmed_stage == "stage_vegetative"
    db.refresh(cycle)
    assert cycle.current_stage_code in ["stage_vegetative", "VEGETATIVE"]
    res_sub = CropHeatEngine.assess_crop_heat_risk(db=adapted, request=CropHeatAssessmentRequest(farm_id=farm.id))
    assert res_sub.growth_stage_code in ["stage_vegetative", "VEGETATIVE"]
