"""Ported Rashkar Extra Income endpoint tests wired to CropNet /api/v1/income."""
import pytest


def test_get_income_opportunities_catalog(client):
    response = client.get("/api/v1/income/opportunities")
    assert response.status_code == 200
    data = response.json()
    assert len(data) >= 12
    for opp in data:
        assert "opportunity_id" in opp
        assert "title" in opp
        assert "category" in opp
        assert "source_attribution" in opp


def test_get_single_opportunity_endpoint(client):
    response = client.get("/api/v1/income/opportunities/OPP_OYSTER_MUSHROOM_01")
    assert response.status_code == 200
    data = response.json()
    assert data["opportunity_id"] == "OPP_OYSTER_MUSHROOM_01"
    assert data["category"] == "moderate_enterprise"


def test_match_opportunities_zero_budget(client):
    payload = {
        "available_investment_inr": 0.0,
        "monthly_operating_budget_inr": 0.0,
        "available_land_acres": 0.0,
        "field_bunds_available": True,
        "water_availability": "rainfed_only",
        "family_labor_hours_day": 1.5,
        "crop_byproducts": ["soybean_straw", "cow_dung"],
    }
    response = client.post("/api/v1/income/match-opportunities", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert len(data) > 0

    comp_opp = next(o for o in data if o["opportunity"]["opportunity_id"] == "OPP_COMPOST_COST_SAVING_01")
    assert comp_opp["is_feasible"] is True
    assert comp_opp["feasibility_status"] == "USES_EXISTING_RESOURCES"
    assert comp_opp["capital_gap_inr"] == 0.0

    goat = next(o for o in data if o["opportunity"]["opportunity_id"] == "OPP_OSMANABADI_GOAT_10_PLUS_1")
    assert goat["is_feasible"] is False
    assert goat["feasibility_status"] == "NOT_CURRENTLY_AFFORDABLE"
    assert goat["capital_gap_inr"] in [75000.0, 87000.0]


def test_match_opportunities_fifteen_thousand_budget(client):
    payload = {
        "available_investment_inr": 15000.0,
        "monthly_operating_budget_inr": 2000.0,
        "available_land_acres": 0.5,
        "unused_land_acres": 0.2,
        "field_bunds_available": True,
        "water_availability": "seasonal_canal",
        "family_labor_hours_day": 2.5,
    }
    response = client.post("/api/v1/income/match-opportunities", json=payload)
    assert response.status_code == 200
    data = response.json()

    goat_commercial = next(o for o in data if o["opportunity"]["opportunity_id"] == "OPP_OSMANABADI_GOAT_10_PLUS_1")
    assert goat_commercial["is_feasible"] is False
    assert goat_commercial["capital_gap_inr"] in [60000.0, 70000.0, 72000.0]

    drumstick = next(o for o in data if o["opportunity"]["opportunity_id"] == "OPP_FIELD_BUND_DRUMSTICK_01")
    assert drumstick["is_feasible"] is True
    assert drumstick["capital_gap_inr"] == 0.0


def test_calculate_income_scenario_deterministic(client):
    payload = {
        "opportunity_id": "OPP_OYSTER_MUSHROOM_01",
        "custom_budget_inr": 20000.0,
        "available_labour_hours_day": 2.0,
        "available_land_acres": 0.0,
    }
    response = client.post("/api/v1/income/calculate-scenario", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["opportunity_id"] == "OPP_OYSTER_MUSHROOM_01"
    assert data["calculated_capex_inr"] == 18000.0
    assert data["calculated_net_profit_annual_inr"] > 0
    assert len(data["monthly_cash_flows"]) == 12
    assert "base" in data["scenarios"]
    assert "conservative" in data["scenarios"]
    assert "optimistic" in data["scenarios"]


def test_compare_selected_opportunities(client):
    payload = {
        "opportunity_ids": ["OPP_COMPOST_COST_SAVING_01", "OPP_OYSTER_MUSHROOM_01"],
        "custom_budget_inr": 20000.0,
    }
    response = client.post("/api/v1/income/compare-opportunities", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 2

    mush = next(o for o in data if o["opportunity_id"] == "OPP_OYSTER_MUSHROOM_01")
    compost = next(o for o in data if o["opportunity_id"] == "OPP_COMPOST_COST_SAVING_01")
    assert mush["net_annual_profit_inr"] > 0
    assert compost["is_cost_saving"] is True
    assert compost["annual_money_saved_inr"] > 0


def test_farm_profile_and_saved_plan_lifecycle(client):
    farm_res = client.post("/api/v1/farms", json={
        "name": "Baramati Test Farm",
        "district": "Pune",
        "taluka": "Baramati",
        "village": "Malegaon",
        "irrigation_type": "irrigated",
        "water_source": "canal",
        "geometry": {
            "type": "Polygon",
            "coordinates": [[[74.575, 18.145], [74.585, 18.145], [74.585, 18.155], [74.575, 18.155], [74.575, 18.145]]],
        },
    })
    assert farm_res.status_code == 201
    farm_id = farm_res.json()["id"]

    # Prefilled profile leaves unknown fields genuinely None without fabricating 0.0 investment
    prof_res = client.get(f"/api/v1/income/farms/{farm_id}/profile")
    assert prof_res.status_code == 200
    prof_data = prof_res.json()
    assert prof_data["profile_completed"] is False

    # Save resource profile once
    save_prof_res = client.put(
        f"/api/v1/income/farms/{farm_id}/profile",
        json={
            "available_investment_inr": 10000.0,
            "has_storage_room": True,
            "water_availability": "seasonal_canal",
            "family_labor_hours_day": 2.5,
            "unused_land_acres": 0.25,
            "crop_byproducts": ["soybean_straw", "cow_dung"],
        },
    )
    assert save_prof_res.status_code == 200
    assert save_prof_res.json()["available_investment_inr"] == 10000.0

    disc_res = client.post(f"/api/v1/income/farms/{farm_id}/discover")
    assert disc_res.status_code == 200
    assert len(disc_res.json()) > 0

    plan_res = client.post(f"/api/v1/income/farms/{farm_id}/plans", json={
        "opportunity_id": "OPP_FIELD_BUND_DRUMSTICK_01",
        "chosen_budget_inr": 2500.0,
        "notes": "Plan to plant 25 moringa saplings along North boundary bund.",
    })
    assert plan_res.status_code == 200
    assert plan_res.json()["opportunity_id"] == "OPP_FIELD_BUND_DRUMSTICK_01"
    assert plan_res.json()["projected_annual_profit_inr"] > 0

    list_res = client.get(f"/api/v1/income/farms/{farm_id}/plans")
    assert list_res.status_code == 200
    assert len(list_res.json()) >= 1
    assert list_res.json()[0]["opportunity_id"] == "OPP_FIELD_BUND_DRUMSTICK_01"
