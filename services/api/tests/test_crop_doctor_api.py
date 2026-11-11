import io
import pytest
from fastapi.testclient import TestClient
from PIL import Image

from cropnet.services.api.app.main import app

client = TestClient(app)


def test_crop_doctor_predict_sample():
    response = client.post(
        "/api/v1/crop-doctor/predict-sample",
        json={"sample_name": "Tomato_Early_blight_sample.jpg"}
    )
    assert response.status_code == 200
    data = response.json()
    assert "Tomato" in data["crop_name"]
    assert "Early blight" in data["condition"]
    assert "actionable_advice" in data
    assert len(data["actionable_advice"]) > 0


def test_crop_doctor_predict_upload():
    # Create simple synthetic test image
    img = Image.new("RGB", (64, 64), color=(34, 139, 34))  # Green
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    buf.seek(0)

    response = client.post(
        "/api/v1/crop-doctor/predict",
        files={"file": ("healthy_leaf.jpg", buf, "image/jpeg")}
    )
    assert response.status_code == 200
    data = response.json()
    assert "diagnosis" in data
    assert "confidence" in data
    assert "actionable_advice" in data
