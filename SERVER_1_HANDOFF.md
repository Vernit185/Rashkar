# Rashkar Primary AI Server Configuration Handoff (`SERVER_1_HANDOFF.md`)

This document captures the exact verified configuration of **Server 1 (Primary Windows AI Server)** so an equivalent **Server 2 (Backup Windows AI Server)** can be configured from the same codebase.

> **Security Rule:** Do NOT copy Server 1's `OLLAMA_AUTH_TOKEN`, Ngrok authtoken, Supabase credentials, or any `.env` files to Server 2. Generate a fresh token and use Server 2's own Ngrok domain/authtoken.

---

## 1. Git Branch & Commit
- **Branch:** `deployment/free-cloud`
- **Verified Commit (prior to adding this handoff):** `37fd571c27a30beec192b59a2dd6f1a57e1b54ad`
- **Pull command for Server 2:**
  ```powershell
  git fetch origin
  git checkout deployment/free-cloud
  git pull origin deployment/free-cloud
  ```

## 2. Ollama Version
- `ollama version is 0.40.16`

## 3. Qwen3:8B Model Configuration
- **Model Name / Tag:** `qwen3:8b`
- **Digest / ID:** `500a1f067a9f` (`sha256-a3de86cd1c132c822487ededd47a324c50491393e6565cd14bafa40d0b8e686f`, `5.2 GB`)
- **Modelfile Parameters (from `ollama show qwen3:8b --modelfile`):**
  - `PARAMETER top_p 0.95`
  - `PARAMETER repeat_penalty 1`
  - `PARAMETER stop <|im_start|>`
  - `PARAMETER stop <|im_end|>`
  - `PARAMETER temperature 0.6`
  - `PARAMETER top_k 20`
  - Stock `qwen3:8b` ChatML/tool/thinking template (`<|im_start|>`, `<|im_end|>`, `<think>`). No custom Modelfile overrides.

## 4. Original Rashkar System Prompt File Locations
- Prompt builder: `services/api/app/services/llm/prompt_builder.py` (`ExplanationPromptBuilder`)
- Guardrail validator: `services/api/app/services/llm/guardrail_validator.py`
- Explanation orchestration & fallback: `services/api/app/services/llm/explanation_service.py`
- Deterministic fallback: `services/api/app/services/llm/template_fallback.py`
- Structured output schemas: `services/api/app/services/llm/schemas.py`

## 5. Farmer-Context Builder Location
- `services/api/app/services/llm/farm_context_builder.py`

## 6. Ollama Request Parameters & Response Format
- Implemented in `services/api/app/services/llm/ollama_client.py`:
  - `model`: `settings.OLLAMA_MODEL` (`"qwen3:8b"`)
  - `messages`: chat array (`[{"role": "system", ...}, {"role": "user", ...}]`)
  - `stream`: `False`
  - `format`: optional JSON schema (`dict`) when structured output is requested
  - `options`:
    - `temperature`: `0.1` (`settings.OLLAMA_TEMPERATURE`)
    - `num_predict`: `600` (`settings.OLLAMA_MAX_TOKENS`)
  - **Response handling:** Reads `message.content`, strips `<think>...</think>` wrapper if present, and returns `{"success": True, "content": ..., "model": ..., "tokens_used": ..., "generation_source": "llm_qwen3_8b"}`.

## 7. Local Ollama Port
- `http://127.0.0.1:11434` (bound to localhost only; never exposed publicly).

## 8. Local Authenticated Proxy Port
- `http://127.0.0.1:11435` (`scripts/ollama_tunnel_proxy.py`).

## 9. Existing Ngrok Setup & Public Domain
- **CLI Version:** `ngrok version 3.39.13`
- **Server 1 Static Domain:** `https://mute-octopus-pruning.ngrok-free.dev` → forwards HTTPS traffic to `http://127.0.0.1:11435`.
- **Server 2 Note:** Server 2 must use its **own** Ngrok account/authtoken and its **own** static domain (two laptops cannot share the same static Ngrok domain simultaneously).

## 10. Proxy Supported Routes & Authentication Scheme
- **Authentication:** Constant-time Bearer token check (`hmac.compare_digest`) against `OLLAMA_AUTH_TOKEN` (`Authorization: Bearer <token>`). Missing/invalid token returns `HTTP 401`.
- **Strict Route Allowlist (any other path/method returns `HTTP 403`):**
  - `GET /api/tags` → `http://127.0.0.1:11434/api/tags`
  - `POST /api/chat` → `http://127.0.0.1:11434/api/chat`
  - `GET /crop-doctor/status` → `http://127.0.0.1:11436/health`
  - `POST /crop-doctor/predict` → `http://127.0.0.1:11436/predict`
- **Payload & Content-Type Limits:**
  - `/api/chat`: max `256 KB`
  - `/crop-doctor/predict`: max `7 MB` body (`5 MB` decoded image), `Content-Type` restricted to `application/json`, `image/jpeg`, `image/jpg`, `image/png`, `image/webp`.

## 11. Relevant Python Dependency Versions (Server 1)
- `Python`: `3.13.1`
- `torch`: `2.11.0+cu128`
- `transformers`: `5.5.4`
- `pillow`: `11.0.0`
- `httpx`: `0.28.1`
- `fastapi`: `0.136.0`
- `uvicorn`: `0.44.0`
- `pydantic`: `2.13.2`
- `sqlalchemy`: `2.0.51`
- `pytest`: `9.1.1`

## 12. Crop Doctor Model, Weights, Preprocessing, Labels & Response Schema
- **Model ID:** `neghani/plantvillage-mobilenetv2` (Hugging Face Hub, 38 PlantVillage classes)
- **Implementation:** `services/api/app/services/crop_doctor/inference.py` + `services/api/app/services/crop_doctor/advice.py` (`PREVENTION_TIPS`) + `scripts/crop_doctor_local_server.py` (`127.0.0.1:11436`)
- **Preprocessing & Inference:**
  - Validates image via `PIL.Image.open(...).verify()`, converts to `RGB`.
  - Runs `AutoImageProcessor.from_pretrained("neghani/plantvillage-mobilenetv2")` + `AutoModelForImageClassification.from_pretrained("neghani/plantvillage-mobilenetv2")` in `eval()` + `torch.no_grad()`, applying `softmax` over logits.
- **Response Schema (`POST /predict`):**
  ```json
  {
    "filename": "leaf.jpg",
    "crop": "Corn (maize)",
    "crop_name": "Corn (maize)",
    "diagnosis": "healthy",
    "condition": "healthy",
    "raw_label": "Corn_(maize)___healthy",
    "confidence": "100.0%",
    "confidence_percent": 100.0,
    "confidence_value": 100.0,
    "is_healthy": true,
    "actionable_advice": ["..."],
    "model_architecture": "MobileNetV2 (PlantVillage)",
    "verification_status": "VERIFIED_PATHOLOGY_INFERENCE",
    "disclaimer": "..."
  }
  ```

## 13. Crop Doctor Remote Inference Status
- **Implemented & Verified Working:** Yes.
  - Render runs with `CROP_DOCTOR_ENABLED=false` and `CROP_DOCTOR_MODE=remote` (`services/api/app/api/v1/endpoints/crop_doctor.py` + `render.yaml`).
  - Verified live: `GET https://rashkar.onrender.com/api/v1/crop-doctor/status` returns `{"loaded": true, "available": true, "enabled": true, "mode": "remote", "model_id": "neghani/plantvillage-mobilenetv2", "error": null}`.
  - Verified live: `POST https://rashkar.onrender.com/api/v1/crop-doctor/predict` returns identical label & confidence as local `inference.get_prediction()`.

## 14. Windows Launcher Command & Startup Order
- **Command:**
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\scripts\start_rashkar_ollama_tunnel.ps1 -NgrokDomain <server-static-domain>.ngrok-free.dev
  ```
- **Startup Order:**
  1. Verify `ollama` CLI & start `ollama serve` on `127.0.0.1:11434`.
  2. Verify `qwen3:8b` model is present (never auto-replaces it) & verify `ExplanationPromptBuilder`.
  3. Load or generate local `OLLAMA_AUTH_TOKEN` in `scripts/.ollama_tunnel.env` (ACLs restricted to current Windows user).
  4. Start `scripts/crop_doctor_local_server.py` on `127.0.0.1:11436` and wait until `GET /health` returns `loaded: true`.
  5. Start `scripts/ollama_tunnel_proxy.py` on `127.0.0.1:11435` and verify `401` (unauth), `200` on `/api/tags`, and `loaded: true` on `/crop-doctor/status`.
  6. Start `ngrok http --domain=<NgrokDomain> 11435` and verify `GET https://<NgrokDomain>/api/tags` and `GET https://<NgrokDomain>/crop-doctor/status`.

## 15. Health & Readiness Endpoints
- Local Ollama: `GET http://127.0.0.1:11434/api/tags`
- Local Crop Doctor: `GET http://127.0.0.1:11436/health`
- Local Auth Proxy: `GET http://127.0.0.1:11435/api/tags` and `GET http://127.0.0.1:11435/crop-doctor/status` (requires `Authorization: Bearer <token>`)
- Render Cloud API: `GET https://rashkar.onrender.com/api/v1/health` (`llm_runtime`) and `GET https://rashkar.onrender.com/api/v1/crop-doctor/status`

## 16. Timeouts, Rate Limits & Concurrency Settings
- **Proxy (`scripts/ollama_tunnel_proxy.py`):**
  - `OLLAMA_PROXY_TIMEOUT`: `90` seconds
  - `CROP_DOCTOR_PROXY_TIMEOUT`: `30` seconds
  - `OLLAMA_PROXY_RPM`: `20` requests/minute (shared across gateway)
  - `OLLAMA_PROXY_MAX_CONCURRENT`: `2`
  - `CROP_DOCTOR_PROXY_MAX_CONCURRENT`: `2`
- **Local Crop Doctor (`scripts/crop_doctor_local_server.py`):**
  - `CROP_DOCTOR_LOCAL_MAX_CONCURRENT`: `2`
- **Render Backend (`services/api/app/core/config.py` & `render.yaml`):**
  - `OLLAMA_TIMEOUT_SECONDS`: `60` (Render override; config default `40`)
  - `OLLAMA_MAX_CONCURRENT_REQUESTS`: `2`
  - `CROP_DOCTOR_REMOTE_TIMEOUT_SECONDS`: `30.0`

## 17. Environment-Variable NAMES Needed on Server 2
- In `scripts/.ollama_tunnel.env` (auto-created by launcher if absent):
  - `OLLAMA_AUTH_TOKEN` *(unique to Server 2)*
- Optional launcher/process env vars (defaults shown):
  - `NGROK_STATIC_DOMAIN` *(Server 2's own Ngrok domain)*
  - `OLLAMA_UPSTREAM` (`http://127.0.0.1:11434`)
  - `CROP_DOCTOR_UPSTREAM` (`http://127.0.0.1:11436`)
  - `OLLAMA_PROXY_HOST` (`127.0.0.1`), `OLLAMA_PROXY_PORT` (`11435`)
  - `CROP_DOCTOR_LOCAL_HOST` (`127.0.0.1`), `CROP_DOCTOR_LOCAL_PORT` (`11436`)
  - `OLLAMA_PROXY_MAX_CONCURRENT` (`2`), `CROP_DOCTOR_PROXY_MAX_CONCURRENT` (`2`), `OLLAMA_PROXY_RPM` (`20`)
- On Render (only if switching Render to point to Server 2):
  - `OLLAMA_BASE_URL` → `https://<server-2-domain>.ngrok-free.dev`
  - `OLLAMA_AUTH_TOKEN` → Server 2's `OLLAMA_AUTH_TOKEN`

## 18. Verification Tests for Server 2
1. **Unit & Proxy Tests:**
   ```powershell
   $env:PYTHONPATH = "."
   python -m pytest services/api/tests/test_free_cloud_deployment_adapters.py -v
   ```
2. **Unauthenticated Rejection (`401`) & Disallowed Route (`403`):**
   - `GET https://<server2-domain>/api/tags` without token → `401`
   - `POST https://<server2-domain>/api/pull` with token → `403`
3. **Authenticated Ollama Inference (`200`):**
   - `GET https://<server2-domain>/api/tags` with Server 2 token → `200`, includes `qwen3:8b`
   - `POST https://<server2-domain>/api/chat` with `model="qwen3:8b"` → `200`
4. **Authenticated Crop Doctor Inference (`200`):**
   - `GET https://<server2-domain>/crop-doctor/status` with Server 2 token → `200`, `loaded: true`
   - `POST https://<server2-domain>/crop-doctor/predict` with a test JPEG → `200`, matches local `inference.get_prediction()` label & confidence.

---

## Server 2 Parity Checklist

### Must Match Server 1 Exactly
- [ ] Git branch `deployment/free-cloud` at latest commit
- [ ] Ollama installed (`0.40.16` or compatible) with `qwen3:8b` (`500a1f067a9f`) and stock Modelfile
- [ ] Prompt/context files (`prompt_builder.py`, `farm_context_builder.py`, `guardrail_validator.py`) unmodified
- [ ] Python environment with `torch`, `transformers`, `pillow`, `httpx`, `fastapi`
- [ ] `neghani/plantvillage-mobilenetv2` weights cached and loading on `127.0.0.1:11436`
- [ ] `scripts/ollama_tunnel_proxy.py` running on `127.0.0.1:11435` with identical allowlist, limits, and Bearer auth
- [ ] `scripts/start_rashkar_ollama_tunnel.ps1` passing all 8 startup checks

### Must Be Unique to Server 2
- [ ] Fresh `OLLAMA_AUTH_TOKEN` in Server 2's `scripts/.ollama_tunnel.env` (never copy Server 1's token)
- [ ] Teammate's own Ngrok account / authtoken
- [ ] Teammate's own static Ngrok domain (`<server-2-domain>.ngrok-free.dev`)
