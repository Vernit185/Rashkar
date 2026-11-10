"""
End-to-end integration tests for CropNet <-> Rashkar shared registration,
no-fabrication missing-context checks, multi-plot/multi-crop selection,
live farm-update propagation, ownership authorization, and saved plans.
"""
import uuid
from datetime import date, timedelta
from unittest.mock import patch
import pytest

from cropnet.services.api.app.core.config import settings

USER_A = "00000000-0000-0000-0000-000000000001"
USER_B = "00000000-0000-0000-0000-000000000002"
AUTH_A = {"X-Dev-User-Id": USER_A}
AUTH_B = {"X-Dev-User-Id": USER_B}


def _create_cropnet_farm(test_client, headers=AUTH_A, name="Shetkari Baramati Farm", taluka="Baramati", irrigation="drip", water="canal", lat=18.18, lon=74.53):
    delta = 0.005
    payload = {
        "name": name,
        "village": "Malegaon",
        "taluka": taluka,
        "district": "Pune",
        "state": "Maharashtra",
        "irrigation_type": irrigation,
        "water_source": water,
        "geometry": {
            "type": "Polygon",
            "coordinates": [[[lon - delta, lat - delta], [lon + delta, lat - delta], [lon + delta, lat + delta], [lon - delta, lat + delta], [lon - delta, lat - delta]]],
        },
    }
    resp = test_client.post("/api/v1/farms", json=payload, headers=headers)
    assert resp.status_code == 201, resp.text
    return resp.json()


def test_shared_registration_no_fabrication_and_reuse(test_client):
    settings.ALLOW_DEV_AUTH_BYPASS = True
    farm = _create_cropnet_farm(test_client)
    farm_id = farm["id"]

    # 1. Shared context initially loads farm details cleanly without fabricating unknown inputs
    ctx_resp = test_client.get(f"/api/v1/farms/{farm_id}/shared-context", headers=AUTH_A)
    assert ctx_resp.status_code == 200
    ctx = ctx_resp.json()
    assert ctx["farm_name"] == "Shetkari Baramati Farm"
    assert ctx["taluka"] == "Baramati"
    assert abs(ctx["total_area_acres"] - farm["calculated_area_acres"]) < 0.05
    assert "workload_category" in ctx["worker_heat_missing_fields"]
    assert "crop_code" in ctx["crop_heat_missing_fields"]
    assert "available_investment_inr" in ctx["extra_income_missing_fields"]
    assert ctx["resource_profile"]["available_investment_inr"] is None
    assert ctx["farmer_profile"]["default_workload_category"] is None
    # Water is auto-mapped ONLY because CropNet registered drip + canal
    assert ctx["resource_profile"]["water_availability"] == "seasonal_canal"

    # 2. Assessing Worker Heat, Crop Heat, or Income without filling missing fields refuses fabrication (422)
    wh_missing = test_client.post(f"/api/v1/risk/farms/{farm_id}/worker-heat", json={}, headers=AUTH_A)
    assert wh_missing.status_code == 422
    assert "MISSING_WORKER_CONTEXT" in str(wh_missing.json())

    ch_missing = test_client.post(f"/api/v1/risk/farms/{farm_id}/crop-heat", json={}, headers=AUTH_A)
    assert ch_missing.status_code == 422
    assert "MISSING_CROP_CONTEXT" in str(ch_missing.json())

    inc_missing = test_client.post(f"/api/v1/income/farms/{farm_id}/discover", headers=AUTH_A)
    assert inc_missing.status_code == 422
    assert "MISSING_RESOURCE_PROFILE" in str(inc_missing.json())

    # 3. Farmer fills worker defaults ONCE on assessment (save_as_default=True) -> reused on subsequent empty call!
    with patch(
        "cropnet.services.api.app.services.rashkar.weather_service.WeatherService.get_hourly_forecast",
        return_value={"hourly_points": [{"air_temp_c": 37.0, "relative_humidity_pct": 45.0, "wind_speed_ms": 1.8, "solar_irradiance_wm2": 750.0}] * 7},
    ):
        wh_first = test_client.post(
            f"/api/v1/risk/farms/{farm_id}/worker-heat",
            json={
                "workload_category": "heavy",
                "clothing_type": "standard_work_clothes",
                "is_acclimatised": True,
                "sun_exposure": "direct_sun",
                "exposure_duration_hours": 5.0,
                "save_as_default": True,
            },
            headers=AUTH_A,
        )
        assert wh_first.status_code == 200, wh_first.text
        data1 = wh_first.json()
        assert data1["workload_category"] == "heavy"
        assert "Baramati" in data1["farm_location_display"]

        # Subsequent assessment with empty body automatically reuses saved farmer defaults
        wh_second = test_client.post(f"/api/v1/risk/farms/{farm_id}/worker-heat", json={}, headers=AUTH_A)
        assert wh_second.status_code == 200
        assert wh_second.json()["workload_category"] == "heavy"
        assert wh_second.json()["exposure_duration_hours"] == 5.0

        # Per-day override with save_as_default=False does not clobber defaults
        wh_override = test_client.post(
            f"/api/v1/risk/farms/{farm_id}/worker-heat",
            json={"workload_category": "light", "save_as_default": False},
            headers=AUTH_A,
        )
        assert wh_override.status_code == 200
        assert wh_override.json()["workload_category"] == "light"

        wh_after = test_client.post(f"/api/v1/risk/farms/{farm_id}/worker-heat", json={}, headers=AUTH_A)
        assert wh_after.json()["workload_category"] == "heavy"


def test_multi_plot_crop_heat_stage_persistence_and_farm_update_propagation(test_client):
    settings.ALLOW_DEV_AUTH_BYPASS = True
    farm = _create_cropnet_farm(test_client, name="Multi Crop Estate", taluka="Baramati", irrigation="irrigated", water="borewell")
    farm_id = farm["id"]

    p1 = test_client.post(f"/api/v1/farms/{farm_id}/plots", json={"plot_name": "North Plot", "area_acres": 1.2, "irrigation_type": "drip"}, headers=AUTH_A).json()
    p2 = test_client.post(f"/api/v1/farms/{farm_id}/plots", json={"plot_name": "South Plot", "area_acres": 1.5, "irrigation_type": "rainfed"}, headers=AUTH_A).json()

    c1 = test_client.post(
        f"/api/v1/farms/{farm_id}/crop-cycles",
        json={"plot_id": p1["plot_id"], "crop_code": "soybean", "variety_name": "JS-335", "season": "kharif", "sowing_date": (date.today() - timedelta(days=38)).isoformat()},
        headers=AUTH_A,
    ).json()
    c2 = test_client.post(
        f"/api/v1/farms/{farm_id}/crop-cycles",
        json={"plot_id": p2["plot_id"], "crop_code": "cotton", "variety_name": "Bt", "season": "kharif", "sowing_date": (date.today() - timedelta(days=60)).isoformat()},
        headers=AUTH_A,
    ).json()

    with patch(
        "cropnet.services.api.app.services.rashkar.weather_service.WeatherService.get_hourly_forecast",
        return_value={"hourly_points": [{"air_temp_c": 38.5}, {"air_temp_c": 24.0}]},
    ):
        soy_res = test_client.post(
            f"/api/v1/risk/farms/{farm_id}/crop-heat",
            json={"plot_id": p1["plot_id"], "cycle_id": c1["cycle_id"], "farmer_confirmed_stage": "stage_flowering", "forecast_tmax_c": 38.5, "forecast_tmin_c": 24.0},
            headers=AUTH_A,
        ).json()
        cot_res = test_client.post(
            f"/api/v1/risk/farms/{farm_id}/crop-heat",
            json={"plot_id": p2["plot_id"], "cycle_id": c2["cycle_id"], "forecast_tmax_c": 38.5, "forecast_tmin_c": 24.0},
            headers=AUTH_A,
        ).json()

    assert soy_res["crop_code"] == "soybean"
    assert soy_res["plot_name"] == "North Plot"
    assert soy_res["growth_stage_code"] == "R1_FLOWERING"
    assert cot_res["crop_code"] == "cotton"
    assert cot_res["plot_name"] == "South Plot"

    # Confirm stage persisted ONLY on soybean cycle, untouched on cotton
    cycles = test_client.get(f"/api/v1/farms/{farm_id}/crop-cycles", headers=AUTH_A).json()
    cycle_by_id = {c["cycle_id"]: c for c in cycles}
    assert cycle_by_id[c1["cycle_id"]]["current_stage_code"] == "R1_FLOWERING"
    assert cycle_by_id[c2["cycle_id"]]["current_stage_code"] is None

    # Save resource profile & confirm CropNet total area and active crop populate Extra Income
    prof_save = test_client.put(
        f"/api/v1/income/farms/{farm_id}/profile",
        json={
            "available_investment_inr": 15000.0,
            "monthly_operating_budget_inr": 2000.0,
            "unused_land_acres": 0.5,
            "available_land_acres": 0.5,
            "water_availability": "reliable_year_round",
            "family_labor_hours_day": 3.0,
            "age_range": "36-45",
            "work_preference": "daily_physical",
            "payback_horizon": "3_to_6_months",
            "family_management_role": "self",
            "crop_byproducts": ["soybean_straw", "cow_dung"],
        },
        headers=AUTH_A,
    )
    assert prof_save.status_code == 200
    assert prof_save.json()["profile_completed"] is True
    assert prof_save.json()["current_crop_code"] in ("soybean", "cotton")

    discovered = test_client.post(f"/api/v1/income/farms/{farm_id}/discover", headers=AUTH_A).json()
    assert len(discovered) > 5

    # Save & retrieve an Extra Income Plan
    first_id = discovered[0]["opportunity"]["opportunity_id"]
    plan = test_client.post(
        f"/api/v1/income/farms/{farm_id}/plans",
        json={"opportunity_id": first_id, "chosen_budget_inr": 0.0, "notes": "Integration plan"},
        headers=AUTH_A,
    )
    assert plan.status_code == 200
    plans = test_client.get(f"/api/v1/income/farms/{farm_id}/plans", headers=AUTH_A).json()
    assert len(plans) == 1
    assert plans[0]["opportunity_id"] == first_id

    # Update existing CropNet farm via PUT /farms/{id} -> context propagates to all 3 features!
    upd = test_client.put(f"/api/v1/farms/{farm_id}", json={"taluka": "Indapur", "name": "Updated Indapur Farm"}, headers=AUTH_A)
    assert upd.status_code == 200
    ctx_after = test_client.get(f"/api/v1/farms/{farm_id}/shared-context", headers=AUTH_A).json()
    assert ctx_after["taluka"] == "Indapur"
    assert ctx_after["farm_name"] == "Updated Indapur Farm"

    test_client.put(
        f"/api/v1/farms/{farm_id}/shared-context",
        json={"farmer_profile": {"default_workload_category": "moderate", "default_sun_exposure": "direct_sun", "default_is_acclimatised": True, "default_clothing_type": "standard_work_clothes", "default_exposure_duration_hours": 4.0}},
        headers=AUTH_A,
    )
    wh_after = test_client.post(f"/api/v1/risk/farms/{farm_id}/worker-heat", json={}, headers=AUTH_A).json()
    assert "Indapur" in wh_after["farm_location_display"]

    with patch(
        "cropnet.services.api.app.services.rashkar.weather_service.WeatherService.get_hourly_forecast",
        return_value={"hourly_points": [{"air_temp_c": 36.0}, {"air_temp_c": 22.0}]},
    ):
        ch_after = test_client.post(f"/api/v1/risk/farms/{farm_id}/crop-heat", json={}, headers=AUTH_A).json()
        assert ch_after["farm_name"] == "Updated Indapur Farm"


def test_ownership_isolation_across_shared_risk_and_income_routes(test_client):
    settings.ALLOW_DEV_AUTH_BYPASS = True
    farm = _create_cropnet_farm(test_client, headers=AUTH_A)
    farm_id = farm["id"]

    # Another user MUST get 403 on all farm-scoped routes
    assert test_client.get(f"/api/v1/farms/{farm_id}/shared-context", headers=AUTH_B).status_code == 403
    assert test_client.post(f"/api/v1/farms/{farm_id}/plots", json={"plot_name": "Hack", "area_acres": 1.0}, headers=AUTH_B).status_code == 403
    assert test_client.post(f"/api/v1/risk/farms/{farm_id}/worker-heat", json={}, headers=AUTH_B).status_code == 403
    assert test_client.post(f"/api/v1/risk/farms/{farm_id}/crop-heat", json={}, headers=AUTH_B).status_code == 403
    assert test_client.get(f"/api/v1/income/farms/{farm_id}/profile", headers=AUTH_B).status_code == 403
    assert test_client.post(f"/api/v1/income/farms/{farm_id}/discover", headers=AUTH_B).status_code == 403
    assert test_client.get(f"/api/v1/income/farms/{farm_id}/plans", headers=AUTH_B).status_code == 403

    # Unknown farm UUID returns 404
    fake_id = str(uuid.uuid4())
    assert test_client.get(f"/api/v1/farms/{fake_id}/shared-context", headers=AUTH_A).status_code == 404
