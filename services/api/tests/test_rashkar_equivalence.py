"""
Golden Equivalence Tests verifying that CropNet's ported Rashkar engines
produce bit-for-bit identical calculations, thresholds, feasibility decisions,
and financial outputs as Rashkar `yeild-and-heat-risk-feature` (7b5641e).
"""
import importlib.util
import sys
from datetime import date, timedelta
from pathlib import Path
from unittest.mock import patch
import pytest

from cropnet.services.api.app.schemas.rashkar.worker_heat import WorkerHeatAssessmentRequest
from cropnet.services.api.app.schemas.rashkar.crop_heat import CropHeatAssessmentRequest
from cropnet.services.api.app.schemas.rashkar.income import FarmerResourceProfile
from cropnet.services.api.app.services.rashkar.worker_heat_engine import WorkerHeatEngine as CropNetWorkerHeatEngine
from cropnet.services.api.app.services.rashkar.wbgt_solver import calculate_wbgt as cropnet_wbgt
from cropnet.services.api.app.services.rashkar.crop_heat_engine import (
    CropHeatEngine as CropNetCropHeatEngine,
    CROP_SPECIES_PHYSIOLOGY as CROPNET_PHYSIOLOGY,
)
from cropnet.services.api.app.services.rashkar.income_engine import IncomeEngine as CropNetIncomeEngine
from cropnet.services.api.app.models.soil_and_farm import FarmModel as CropNetFarmModel
from cropnet.services.api.app.models.rashkar_profiles import FarmPlotModel, CropCycleModel
from cropnet.services.api.app.services.rashkar.adapters import RashkarAdaptedSession

RASHKAR_ORIG_DIR = Path(
    r"C:\Users\verni\.gemini\antigravity\brain\11d077b1-a769-4c58-a6eb-463255061f8a\scratch\rashkar_orig_src"
)


def _import_orig_rashkar_modules():
    """Import original Rashkar modules into an isolated namespace when scratch worktree exists."""
    if not RASHKAR_ORIG_DIR.exists():
        pytest.skip("Original Rashkar detached worktree not available on disk.")
    if str(RASHKAR_ORIG_DIR) not in sys.path:
        sys.path.insert(0, str(RASHKAR_ORIG_DIR))
    from backend.app.services.wbgt_solver import calculate_wbgt as orig_wbgt
    from backend.app.services.worker_heat_engine import WorkerHeatEngine as OrigWorkerHeatEngine
    from backend.app.schemas.worker_heat import WorkerHeatAssessmentRequest as OrigWorkerReq
    from backend.app.services.crop_heat_engine import CROP_SPECIES_PHYSIOLOGY as ORIG_PHYSIOLOGY
    from backend.app.services.income_engine import IncomeEngine as OrigIncomeEngine
    from backend.app.schemas.income import FarmerResourceProfile as OrigProfile
    return {
        "orig_wbgt": orig_wbgt,
        "OrigWorkerHeatEngine": OrigWorkerHeatEngine,
        "OrigWorkerReq": OrigWorkerReq,
        "ORIG_PHYSIOLOGY": ORIG_PHYSIOLOGY,
        "OrigIncomeEngine": OrigIncomeEngine,
        "OrigProfile": OrigProfile,
    }


SAMPLE_HOURLY_WEATHER = [
    {"air_temp_c": 38.2, "relative_humidity_pct": 42.0, "wind_speed_ms": 1.6, "solar_irradiance_wm2": 780.0},
    {"air_temp_c": 39.5, "relative_humidity_pct": 39.0, "wind_speed_ms": 1.4, "solar_irradiance_wm2": 820.0},
    {"air_temp_c": 40.1, "relative_humidity_pct": 36.0, "wind_speed_ms": 1.3, "solar_irradiance_wm2": 810.0},
    {"air_temp_c": 38.8, "relative_humidity_pct": 40.0, "wind_speed_ms": 1.5, "solar_irradiance_wm2": 690.0},
    {"air_temp_c": 36.4, "relative_humidity_pct": 45.0, "wind_speed_ms": 1.8, "solar_irradiance_wm2": 480.0},
    {"air_temp_c": 33.9, "relative_humidity_pct": 52.0, "wind_speed_ms": 2.0, "solar_irradiance_wm2": 220.0},
    {"air_temp_c": 31.2, "relative_humidity_pct": 58.0, "wind_speed_ms": 2.1, "solar_irradiance_wm2": 40.0},
]


@pytest.mark.parametrize("workload", ["light", "moderate", "heavy", "very_heavy"])
@pytest.mark.parametrize("is_accl", [True, False])
@pytest.mark.parametrize("sun_exp", ["direct_sun", "partial_shade", "full_shade"])
def test_worker_heat_wbgt_equivalence(workload, is_accl, sun_exp):
    orig = _import_orig_rashkar_modules()

    orig_wbgt_res = orig["orig_wbgt"](temp_c=39.5, rh_pct=39.0, wind_speed_ms=1.4, solar_irradiance_wm2=820.0, in_sun=True)
    port_wbgt_res = cropnet_wbgt(temp_c=39.5, rh_pct=39.0, wind_speed_ms=1.4, solar_irradiance_wm2=820.0, in_sun=True)
    assert port_wbgt_res == orig_wbgt_res

    orig_req = orig["OrigWorkerReq"](
        latitude=18.18,
        longitude=74.53,
        taluka="Baramati",
        workload_category=workload,
        clothing_type="standard_work_clothes",
        is_acclimatised=is_accl,
        sun_exposure=sun_exp,
        exposure_duration_hours=4.0,
    )
    port_req = WorkerHeatAssessmentRequest(
        latitude=18.18,
        longitude=74.53,
        taluka="Baramati",
        workload_category=workload,
        clothing_type="standard_work_clothes",
        is_acclimatised=is_accl,
        sun_exposure=sun_exp,
        exposure_duration_hours=4.0,
    )

    orig_res = orig["OrigWorkerHeatEngine"].assess_worker_heat_hazard(
        orig_req, db=None, weather_hourly_override=SAMPLE_HOURLY_WEATHER
    )
    port_res = CropNetWorkerHeatEngine.assess_worker_heat_hazard(
        port_req, db=None, weather_hourly_override=SAMPLE_HOURLY_WEATHER
    )

    assert port_res.current_wbgt_estimated_c == orig_res.current_wbgt_estimated_c
    assert port_res.max_wbgt_effective_c == orig_res.max_wbgt_effective_c
    assert port_res.screening_threshold_c == orig_res.screening_threshold_c
    assert port_res.threshold_difference_c == orig_res.threshold_difference_c
    assert port_res.threshold_comparison_state == orig_res.threshold_comparison_state
    assert port_res.current_hazard_level == orig_res.current_hazard_level
    assert port_res.max_hazard_level_in_window == orig_res.max_hazard_level_in_window
    assert port_res.personalized_heat_strain_score == orig_res.personalized_heat_strain_score
    assert port_res.hydration_guidance == orig_res.hydration_guidance
    assert [
        (p.wbgt_estimated_c, p.wbgt_effective_c, p.hazard_level, p.work_rest_cycle)
        for p in port_res.hourly_projections
    ] == [
        (p.wbgt_estimated_c, p.wbgt_effective_c, p.hazard_level, p.work_rest_cycle)
        for p in orig_res.hourly_projections
    ]


def test_crop_heat_physiology_and_stage_recalculation(isolated_test_session):
    orig = _import_orig_rashkar_modules()
    assert CROPNET_PHYSIOLOGY == orig["ORIG_PHYSIOLOGY"]

    db = isolated_test_session
    farm = CropNetFarmModel(
        id="aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
        owner_id="00000000-0000-0000-0000-000000000001",
        name="Golden Baramati Farm",
        taluka="Baramati",
        district="Pune",
        state="Maharashtra",
        irrigation_type="drip",
        water_source="canal",
        geometry_geojson={"type": "Polygon", "coordinates": [[[74.52, 18.17], [74.53, 18.17], [74.53, 18.18], [74.52, 18.17]]]},
        calculated_area_hectares=1.0,
        calculated_area_acres=2.47,
        centroid_latitude=18.175,
        centroid_longitude=74.525,
    )
    db.add(farm)
    plot = FarmPlotModel(
        plot_id="plot_golden_1",
        farm_id=farm.id,
        plot_name="Plot A",
        area_acres=2.47,
        irrigation_type="drip",
    )
    db.add(plot)
    cycle = CropCycleModel(
        cycle_id="cycle_golden_1",
        plot_id=plot.plot_id,
        crop_code="soybean",
        variety_name="JS-335",
        season="kharif",
        sowing_date=date.today() - timedelta(days=40),
        planted_area_acres=2.47,
        is_active=True,
    )
    db.add(cycle)
    db.commit()

    adapted_db = RashkarAdaptedSession(db, farm, specific_cycle_id=cycle.cycle_id)
    with patch(
        "cropnet.services.api.app.services.rashkar.crop_heat_engine.WeatherService.get_hourly_forecast",
        return_value={"hourly_points": [{"air_temp_c": 37.5}, {"air_temp_c": 36.2}, {"air_temp_c": 24.5}]},
    ):
        veg_res = CropNetCropHeatEngine.assess_crop_heat_risk(
            adapted_db,
            CropHeatAssessmentRequest(
                farm_id=farm.id,
                plot_id=plot.plot_id,
                farmer_confirmed_stage="stage_vegetative",
                forecast_tmax_c=37.5,
                forecast_tmin_c=24.5,
            ),
        )
        flower_res = CropNetCropHeatEngine.assess_crop_heat_risk(
            adapted_db,
            CropHeatAssessmentRequest(
                farm_id=farm.id,
                plot_id=plot.plot_id,
                farmer_confirmed_stage="stage_flowering",
                forecast_tmax_c=37.5,
                forecast_tmin_c=24.5,
            ),
        )

    assert veg_res.growth_stage_code != flower_res.growth_stage_code
    assert veg_res.critical_tmax_threshold_c != flower_res.critical_tmax_threshold_c
    assert flower_res.overall_crop_heat_risk in ("high", "critical")
    assert all(s.get("stage_name_en") not in (None, "", "null") for s in flower_res.supported_stages)


@pytest.mark.parametrize(
    "profile_kwargs",
    [
        dict(available_investment_inr=0.0, unused_land_acres=0.0, field_bunds_available=True, water_availability="limited", family_labor_hours_day=1.5, crop_byproducts=["soybean_straw", "cow_dung"]),
        dict(available_investment_inr=5000.0, unused_land_acres=0.1, water_availability="seasonal_canal", family_labor_hours_day=2.0, crop_byproducts=["cotton_stalks"]),
        dict(available_investment_inr=15000.0, unused_land_acres=0.5, available_land_acres=0.5, water_availability="seasonal_canal", family_labor_hours_day=3.0),
        dict(available_investment_inr=50000.0, has_animal_shed=True, water_availability="reliable_year_round", existing_livestock="indigenous_cows", family_labor_hours_day=4.0, age_range="36-45", work_preference="daily_physical"),
        dict(available_investment_inr=100000.0, has_animal_shed=True, has_storage_room=True, has_transport=True, has_fpo_access=True, water_availability="reliable_year_round", existing_assets=["tractor", "drip"], family_labor_hours_day=5.0),
    ],
)
def test_extra_income_and_financial_equivalence(profile_kwargs):
    orig = _import_orig_rashkar_modules()

    orig_prof = orig["OrigProfile"](**profile_kwargs)
    port_prof = FarmerResourceProfile(**profile_kwargs)

    orig_opps = orig["OrigIncomeEngine"].match_opportunities(orig_prof)
    port_opps = CropNetIncomeEngine.match_opportunities(port_prof)

    assert len(port_opps) == len(orig_opps)
    for p, o in zip(port_opps, orig_opps):
        assert p.opportunity.opportunity_id == o.opportunity.opportunity_id
        assert p.feasibility_status == o.feasibility_status
        assert p.feasibility_category == o.feasibility_category
        assert p.suitability_score == o.suitability_score
        assert p.is_feasible == o.is_feasible
        assert p.capital_gap_inr == o.capital_gap_inr
        assert p.estimated_annual_profit_inr == o.estimated_annual_profit_inr
        assert p.estimated_annual_savings_inr == o.estimated_annual_savings_inr
        assert p.farmer_summary_qa == o.farmer_summary_qa

    sample_ids = [o.opportunity.opportunity_id for o in port_opps[:4]]
    for opp_id in sample_ids:
        orig_fin = orig["OrigIncomeEngine"].calculate_enterprise_financials(opp_id, profile_kwargs["available_investment_inr"])
        port_fin = CropNetIncomeEngine.calculate_enterprise_financials(opp_id, profile_kwargs["available_investment_inr"])
        assert port_fin.calculated_capex_inr == orig_fin.calculated_capex_inr
        assert port_fin.calculated_opex_annual_inr == orig_fin.calculated_opex_annual_inr
        assert port_fin.calculated_gross_revenue_inr == orig_fin.calculated_gross_revenue_inr
        assert port_fin.calculated_net_profit_annual_inr == orig_fin.calculated_net_profit_annual_inr
        assert port_fin.calculated_break_even_months == orig_fin.calculated_break_even_months
        assert port_fin.monthly_cash_flows == orig_fin.monthly_cash_flows

    orig_cmp = orig["OrigIncomeEngine"].compare_opportunities(sample_ids, 25000.0)
    port_cmp = CropNetIncomeEngine.compare_opportunities(sample_ids, 25000.0)
    assert [c.model_dump() for c in port_cmp] == [c.model_dump() for c in orig_cmp]
