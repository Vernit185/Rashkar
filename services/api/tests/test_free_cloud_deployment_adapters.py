import json
from unittest.mock import MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from cropnet.services.api.app.core.config import settings
from cropnet.services.api.app.main import app
from cropnet.services.api.app.services.llm.ollama_client import OllamaClient

client = TestClient(app)


def test_crop_doctor_disabled_returns_explicit_503(monkeypatch):
    monkeypatch.setattr(settings, "CROP_DOCTOR_ENABLED", False)

    status_resp = client.get("/api/v1/crop-doctor/status")
    assert status_resp.status_code == 200
    body = status_resp.json()
    assert body["enabled"] is False
    assert body["available"] is False
    assert body["loaded"] is False
    assert body["message"] == "Crop Doctor is temporarily unavailable."

    predict_resp = client.post(
        "/api/v1/crop-doctor/predict",
        files={"file": ("leaf.jpg", b"\xff\xd8\xff\xe0" + b"\x00" * 200, "image/jpeg")},
    )
    assert predict_resp.status_code == 503
    assert predict_resp.json()["detail"] == "Crop Doctor is temporarily unavailable."

    sample_resp = client.post(
        "/api/v1/crop-doctor/predict-sample",
        json={"sample_name": "Tomato_Early_blight_sample.jpg"},
    )
    assert sample_resp.status_code == 503
    assert sample_resp.json()["detail"] == "Crop Doctor is temporarily unavailable."


def test_groq_client_chat_completion_success():
    groq = OllamaClient(
        provider="groq",
        groq_api_key="gsk_test_dummy_key",
        default_model="llama-3.3-70b-versatile",
        base_url="https://api.groq.com/openai/v1",
    )

    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {
        "model": "llama-3.3-70b-versatile",
        "choices": [{"message": {"content": json.dumps({"summary": "Irrigate early morning."})}}],
        "usage": {"completion_tokens": 12},
    }

    with patch("cropnet.services.api.app.services.llm.ollama_client.httpx.Client") as mock_client_cls:
        mock_http = mock_client_cls.return_value.__enter__.return_value
        mock_http.post.return_value = mock_resp

        res = groq.chat_completion(
            messages=[{"role": "user", "content": "Advice?"}],
            format={"type": "object"},
        )

    assert res["success"] is True
    assert json.loads(res["content"])["summary"] == "Irrigate early morning."
    _, kwargs = mock_http.post.call_args
    assert kwargs["json"]["response_format"] == {"type": "json_object"}
    assert kwargs["headers"]["Authorization"] == "Bearer gsk_test_dummy_key"


def test_groq_client_handles_rate_limit_429():
    groq = OllamaClient(
        provider="groq",
        groq_api_key="gsk_test_dummy_key",
        default_model="llama-3.3-70b-versatile",
    )

    mock_resp = MagicMock()
    mock_resp.status_code = 429
    mock_resp.text = "Rate limit exceeded"

    with patch("cropnet.services.api.app.services.llm.ollama_client.httpx.Client") as mock_client_cls:
        mock_client_cls.return_value.__enter__.return_value.post.return_value = mock_resp
        res = groq.chat_completion(messages=[{"role": "user", "content": "Hi"}])

    assert res["success"] is False
    assert res["error_type"] == "rate_limit"
    assert "429" in res["error"]


def test_groq_client_missing_api_key():
    groq = OllamaClient(provider="groq", groq_api_key="", default_model="llama-3.3-70b-versatile")
    assert groq.is_available() is False
    res = groq.chat_completion(messages=[{"role": "user", "content": "Hi"}])
    assert res["success"] is False
    assert res["error_type"] == "configuration_error"
