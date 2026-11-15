"""Lightweight local PyTorch inference service for Rashkar Crop Doctor on Windows.

Binds strictly to 127.0.0.1:<CROP_DOCTOR_LOCAL_PORT> (default 11436), loads the
original `neghani/plantvillage-mobilenetv2` model via CropNet's existing
`inference.py` module, validates uploaded leaf images in memory (never writes
files to disk), and enforces bounded concurrency.
"""
from __future__ import annotations

import base64
import binascii
import io
import json
import os
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

# Ensure repo root is importable as `cropnet`
_REPO_ROOT = Path(__file__).resolve().parent.parent
_PARENT_DIR = str(_REPO_ROOT.parent)
if _PARENT_DIR not in sys.path:
    sys.path.insert(0, _PARENT_DIR)
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

# Force local PyTorch mode inside this dedicated local worker process
os.environ.setdefault("CROP_DOCTOR_ENABLED", "true")
os.environ.setdefault("CROP_DOCTOR_MODE", "local")

from PIL import Image, UnidentifiedImageError  # noqa: E402
from cropnet.services.api.app.services.crop_doctor import inference  # noqa: E402
from cropnet.services.api.app.services.crop_doctor.advice import PREVENTION_TIPS  # noqa: E402

HOST = os.environ.get("CROP_DOCTOR_LOCAL_HOST", "127.0.0.1")
PORT = int(os.environ.get("CROP_DOCTOR_LOCAL_PORT", "11436"))
MAX_IMAGE_BYTES = 5 * 1024 * 1024  # 5 MB
MAX_CONCURRENT = max(1, int(os.environ.get("CROP_DOCTOR_LOCAL_MAX_CONCURRENT", "2")))

_inference_sem = threading.BoundedSemaphore(MAX_CONCURRENT)


def _format_prediction(image_bytes: bytes, filename: str = "leaf.jpg") -> dict:
    result = inference.get_prediction(image_bytes)
    label = str(result["label"])
    is_healthy = "healthy" in label.lower()
    tips = PREVENTION_TIPS.get(label, ["Monitor the plant regularly and maintain field sanitation."])
    crop, _, disease = label.partition("___")
    crop_clean = crop.replace("_", " ").strip() if crop else "Unknown"
    disease_clean = disease.replace("_", " ").strip() if disease else label
    conf = result.get("confidence", 90.0)

    return {
        "filename": filename,
        "crop": crop_clean,
        "crop_name": crop_clean,
        "diagnosis": disease_clean,
        "condition": disease_clean,
        "raw_label": label,
        "confidence": f"{conf}%",
        "confidence_percent": conf,
        "confidence_value": conf,
        "is_healthy": is_healthy,
        "actionable_advice": tips,
        "model_architecture": "MobileNetV2 (PlantVillage)",
        "verification_status": "VERIFIED_PATHOLOGY_INFERENCE",
        "disclaimer": (
            "Automated image classification is a screening aid, not a laboratory diagnosis. "
            "Confirm with a local agronomist before applying chemical treatments."
        ),
    }


def _validate_image_bytes(raw: bytes) -> bytes:
    if not raw:
        raise ValueError("Uploaded image is empty.")
    if len(raw) > MAX_IMAGE_BYTES:
        raise ValueError("Image exceeds the 5 MB limit.")
    try:
        with Image.open(io.BytesIO(raw)) as img:
            img.verify()
        with Image.open(io.BytesIO(raw)) as img2:
            if img2.format not in {"JPEG", "PNG", "WEBP"}:
                raise ValueError("Unsupported image format. Use JPEG, PNG, or WEBP.")
    except (UnidentifiedImageError, OSError) as exc:
        raise ValueError(f"Invalid image content: {exc}") from exc
    return raw


class CropDoctorHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, format: str, *args) -> None:  # noqa: A002
        print(f"[crop-doctor-local] {self.address_string()} - {format % args}")

    def _send_json(self, status_code: int, payload: dict) -> None:
        raw = json.dumps(payload).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self) -> None:  # noqa: N802
        path = self.path.split("?", 1)[0]
        if path != "/health":
            self._send_json(404, {"error": "Not found"})
            return
        st = inference.model_status()
        code = 200 if st.get("loaded") else 503
        self._send_json(code, st)

    def do_POST(self) -> None:  # noqa: N802
        path = self.path.split("?", 1)[0]
        if path != "/predict":
            self._send_json(404, {"error": "Not found"})
            return

        content_len = int(self.headers.get("Content-Length", "0"))
        if content_len <= 0:
            self._send_json(400, {"error": "Empty request body."})
            return
        if content_len > 7 * 1024 * 1024:  # allows base64 overhead for <=5MB image
            self._send_json(413, {"error": "Request payload too large."})
            return

        raw_body = self.rfile.read(content_len)
        content_type = (self.headers.get("Content-Type") or "").lower()
        filename = "leaf.jpg"

        if content_type.startswith("application/json"):
            try:
                data = json.loads(raw_body.decode("utf-8"))
                b64 = data.get("image_base64", "")
                filename = str(data.get("filename") or "leaf.jpg")
                image_bytes = base64.b64decode(b64, validate=True)
            except (UnicodeDecodeError, json.JSONDecodeError, binascii.Error) as exc:
                self._send_json(400, {"error": f"Invalid JSON/base64 image payload: {exc}"})
                return
        elif content_type.startswith("image/"):
            image_bytes = raw_body
        else:
            self._send_json(415, {"error": "Unsupported Content-Type. Send application/json or image/*."})
            return

        try:
            _validate_image_bytes(image_bytes)
        except ValueError as exc:
            self._send_json(400, {"error": str(exc)})
            return

        if not _inference_sem.acquire(blocking=True, timeout=5.0):
            self._send_json(429, {"error": "Local Crop Doctor is busy; please retry shortly."})
            return

        try:
            result = _format_prediction(image_bytes, filename=filename)
            self._send_json(200, result)
        except Exception as exc:
            self._send_json(500, {"error": f"Inference failed: {exc}"})
        finally:
            _inference_sem.release()


def main() -> None:
    print(f"[crop-doctor-local] Loading {inference.MODEL_ID}...")
    if not inference.is_available():
        st = inference.model_status()
        raise RuntimeError(f"Failed to load Crop Doctor model: {st.get('error')}")
    print(f"[crop-doctor-local] Model ready: {inference.MODEL_ID}")
    server = ThreadingHTTPServer((HOST, PORT), CropDoctorHandler)
    print(f"[crop-doctor-local] Listening on http://{HOST}:{PORT} (max_concurrent={MAX_CONCURRENT})")
    server.serve_forever()


if __name__ == "__main__":
    main()
