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


def test_ollama_tunnel_headers_and_offline_handling(monkeypatch):
    monkeypatch.setattr(settings, "LLM_PROVIDER", "ollama")
    monkeypatch.setattr(settings, "OLLAMA_AUTH_TOKEN", "test_tunnel_secret")
    monkeypatch.setattr(settings, "OLLAMA_BASE_URL", "https://demo.ngrok-free.app")

    ollama = OllamaClient()
    headers = ollama._ollama_headers()
    assert headers["Authorization"] == "Bearer test_tunnel_secret"
    assert headers["ngrok-skip-browser-warning"] == "true"

    mock_offline = MagicMock()
    mock_offline.status_code = 502
    mock_offline.text = "Tunnel offline"

    with patch("cropnet.services.api.app.services.llm.ollama_client.httpx.Client") as mock_client_cls:
        mock_http = mock_client_cls.return_value.__enter__.return_value
        mock_http.post.return_value = mock_offline
        res = ollama.chat_completion(messages=[{"role": "user", "content": "Check heat risk"}])

    assert res["success"] is False
    assert res["error_type"] == "tunnel_offline"
    _, kwargs = mock_http.post.call_args
    assert kwargs["headers"]["Authorization"] == "Bearer test_tunnel_secret"


def test_ollama_tunnel_proxy_auth_and_route_allowlist():
    import threading
    from http.server import ThreadingHTTPServer
    import httpx
    import sys
    import os

    sys.path.insert(0, os.path.abspath("scripts"))
    import ollama_tunnel_proxy as proxy

    proxy.AUTH_TOKEN = "unit_test_secret_token"
    server = ThreadingHTTPServer(("127.0.0.1", 0), proxy.OllamaAuthProxyHandler)
    port = server.server_address[1]
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()

    try:
        base = f"http://127.0.0.1:{port}"
        # 1. Unauthorized request must be rejected with 401
        r_unauth = httpx.get(f"{base}/api/tags", timeout=5.0)
        assert r_unauth.status_code == 401

        # 2. Disallowed route (/api/pull) even with valid auth must be rejected with 403
        r_forbidden = httpx.post(
            f"{base}/api/pull",
            headers={"Authorization": "Bearer unit_test_secret_token"},
            json={"name": "evil"},
            timeout=5.0,
        )
        assert r_forbidden.status_code == 403

        # 3. Authorized GET /api/tags forwards to local Ollama (200)
        r_ok = httpx.get(
            f"{base}/api/tags",
            headers={"Authorization": "Bearer unit_test_secret_token"},
            timeout=5.0,
        )
        assert r_ok.status_code == 200
        models = [m["name"] for m in r_ok.json().get("models", [])]
        assert any(m.startswith("qwen3:8b") for m in models)
    finally:
        server.shutdown()
        server.server_close()
