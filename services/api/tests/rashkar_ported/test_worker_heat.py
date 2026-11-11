"""Ported Rashkar Worker Heat endpoint tests wired to CropNet /api/v1/risk/worker-heat/raw."""
import pytest


def test_worker_heat_assessment_endpoint(client):
    payload = {
        "latitude": 18.1512,
        "longitude": 74.5768,
        "taluka": "Baramati",
        "workload_category": "heavy",
        "clothing_type": "standard_work_clothes",
        "is_acclimatised": True,
        "sun_exposure": "direct_sun",
    }

    res = client.post("/api/v1/risk/worker-heat/raw", json=payload)
    assert res.status_code == 200
    data = res.json()

    assert data["time_horizon"] == "0_to_6_hours"
    assert data["recalculation_cadence_minutes"] == 30
    assert data["workload_category"] == "heavy"
    assert data["clothing_cav_c"] == 0.0
    assert data["is_acclimatised"] is True
    assert data["screening_threshold_c"] == 26.0

    assert len(data["hourly_projections"]) == 7
    first_hour = data["hourly_projections"][0]
    assert "wbgt_estimated_c" in first_hour
    assert "hazard_level" in first_hour
    assert first_hour["threshold_limit_c"] == 26.0

    assert "NOTICE: WBGT values are cloud-modeled estimates" in data["disclaimer"]
    assert "does not mandate work-stoppages" in data["disclaimer"]
    assert "Do not exceed 1 litre" in data["hydration_guidance"]["max_hourly_rate"]
    assert len(data["safety_cautions"]) >= 3
    assert data["audit_logged"] is True


def test_worker_heat_unacclimatised_stricter_threshold(client):
    payload = {
        "latitude": 18.1512,
        "longitude": 74.5768,
        "taluka": "Baramati",
        "workload_category": "heavy",
        "clothing_type": "standard_work_clothes",
        "is_acclimatised": False,
        "sun_exposure": "direct_sun",
    }
    res = client.post("/api/v1/risk/worker-heat/raw", json=payload)
    assert res.status_code == 200
    assert res.json()["screening_threshold_c"] == 23.0
