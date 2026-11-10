"""Ported Rashkar Crop Heat endpoint tests wired through CropNet farms, plots & crop cycles."""
import pytest


def test_crop_heat_assessment_endpoint(client):
    farm_res = client.post("/api/v1/farms", json={
        "name": "Indapur Cotton Farm",
        "district": "Pune",
        "taluka": "Indapur",
        "village": "Nimgaon",
        "irrigation_type": "drip",
        "water_source": "borewell",
        "geometry": {
            "type": "Polygon",
            "coordinates": [[[75.018, 18.108], [75.028, 18.108], [75.028, 18.118], [75.018, 18.118], [75.018, 18.108]]],
        },
    })
    assert farm_res.status_code == 201
    farm_id = farm_res.json()["id"]

    plot_res = client.post(f"/api/v1/farms/{farm_id}/plots", json={
        "plot_name": "Cotton Block A",
        "area_acres": 4.5,
        "irrigation_type": "drip",
    })
    assert plot_res.status_code == 201
    plot_id = plot_res.json()["plot_id"]

    cycle_res = client.post(f"/api/v1/farms/{farm_id}/crop-cycles", json={
        "plot_id": plot_id,
        "crop_code": "cotton",
        "variety_name": "Ajeet-155",
        "season": "kharif",
        "sowing_date": "2024-06-10",
        "farmer_confirmed_stage": "FLOWERING_BOLL_DEV",
    })
    assert cycle_res.status_code == 201

    assessment_res = client.post(f"/api/v1/risk/farms/{farm_id}/crop-heat", json={
        "plot_id": plot_id,
        "forecast_tmax_c": 39.5,
        "forecast_tmin_c": 25.5,
    })
    assert assessment_res.status_code == 200
    data = assessment_res.json()

    assert data["farm_id"] == farm_id
    assert data["crop_code"] == "cotton"
    assert data["growth_stage_code"] == "FLOWERING_BOLL_DEV"
    assert data["critical_tmax_threshold_c"] == 38.0
    assert data["critical_tmin_threshold_c"] == 24.0
    assert data["daytime_heat_stress_level"] in ["high", "critical"]
    assert data["warm_night_respiration_hazard"] is True
    assert data["overall_crop_heat_risk"] in ["high", "critical"]
    assert "ICAR-Central Institute for Cotton Research" in data["evidence_citation"]
    assert len(data["recommended_interventions"]) > 0
    assert data["audit_logged"] is True

    assert "supported_stages" in data and len(data["supported_stages"]) > 0
    for stage in data["supported_stages"]:
        assert stage.get("stage_code") is not None
        assert stage.get("stage_name_en") is not None
        assert len(stage["stage_name_en"].strip()) > 0
        assert "null" not in stage["stage_name_en"].lower()
