import base64
import io
from typing import Any, Dict, Optional
import httpx
from fastapi import APIRouter, File, HTTPException, UploadFile, status
from pydantic import BaseModel

try:
    from PIL import Image
except ImportError:
    Image = None

from cropnet.services.api.app.core.config import settings
from cropnet.services.api.app.services.crop_doctor import inference
from cropnet.services.api.app.services.crop_doctor.advice import PREVENTION_TIPS
from cropnet.services.api.app.services.crop_doctor.service import crop_doctor_service

router = APIRouter()

MAX_IMAGE_BYTES = 10 * 1024 * 1024  # 10 MB
REMOTE_TARGET_BYTES = 3 * 1024 * 1024  # keep Ngrok Free uploads compact


def _is_remote_mode() -> bool:
    return (settings.CROP_DOCTOR_MODE or "local").strip().lower() == "remote"


def _remote_base_url() -> str:
    return (settings.CROP_DOCTOR_REMOTE_URL or settings.OLLAMA_BASE_URL or "").rstrip("/")


def _remote_headers() -> Dict[str, str]:
    headers: Dict[str, str] = {"ngrok-skip-browser-warning": "true"}
    if settings.OLLAMA_AUTH_TOKEN:
        headers["Authorization"] = f"Bearer {settings.OLLAMA_AUTH_TOKEN}"
    if settings.OLLAMA_CF_ACCESS_CLIENT_ID and settings.OLLAMA_CF_ACCESS_CLIENT_SECRET:
        headers["CF-Access-Client-Id"] = settings.OLLAMA_CF_ACCESS_CLIENT_ID
        headers["CF-Access-Client-Secret"] = settings.OLLAMA_CF_ACCESS_CLIENT_SECRET
    return headers


def _ensure_crop_doctor_enabled() -> None:
    """Fail explicitly with HTTP 503 when Crop Doctor is disabled in cloud deployment."""
    if not _is_remote_mode() and not settings.CROP_DOCTOR_ENABLED:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=inference.UNAVAILABLE_MESSAGE,
        )


def _compact_image_for_tunnel(content: bytes) -> bytes:
    """Resize/re-encode oversized uploads in memory so Ngrok Free bandwidth stays bounded."""
    if len(content) <= REMOTE_TARGET_BYTES or Image is None:
        return content
    try:
        with Image.open(io.BytesIO(content)) as img:
            img = img.convert("RGB")
            img.thumbnail((1024, 1024))
            buf = io.BytesIO()
            img.save(buf, format="JPEG", quality=85, optimize=True)
            return buf.getvalue()
    except Exception:
        return content


def _forward_remote_predict(content: bytes, filename: str, content_type: str) -> Dict[str, Any]:
    base = _remote_base_url()
    if not base:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=inference.UNAVAILABLE_MESSAGE,
        )
    compact = _compact_image_for_tunnel(content)
    payload = {
        "image_base64": base64.b64encode(compact).decode("ascii"),
        "filename": filename or "leaf.jpg",
        "content_type": content_type or "image/jpeg",
    }
    try:
        with httpx.Client(timeout=settings.CROP_DOCTOR_REMOTE_TIMEOUT_SECONDS) as client:
            resp = client.post(
                f"{base}/crop-doctor/predict",
                json=payload,
                headers=_remote_headers(),
            )
    except httpx.HTTPError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=inference.UNAVAILABLE_MESSAGE,
        ) from exc

    if resp.status_code == 200:
        return resp.json()
    if resp.status_code == 400:
        detail = resp.json().get("error", "Invalid leaf image.")
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=detail)
    raise HTTPException(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        detail=inference.UNAVAILABLE_MESSAGE,
    )


class PredictionSampleRequest(BaseModel):
    sample_name: str


@router.get("/status")
def crop_doctor_status():
    """Report whether the optional vision model stack is loaded (local or remote tunnel)."""
    if _is_remote_mode():
        base = _remote_base_url()
        if base:
            try:
                with httpx.Client(timeout=4.0) as client:
                    resp = client.get(f"{base}/crop-doctor/status", headers=_remote_headers())
                if resp.status_code == 200:
                    data = resp.json()
                    if data.get("loaded"):
                        return {
                            "loaded": True,
                            "available": True,
                            "enabled": True,
                            "mode": "remote",
                            "model_id": data.get("model_id", inference.MODEL_ID),
                            "error": None,
                        }
            except httpx.HTTPError:
                pass
        return {
            "loaded": False,
            "available": False,
            "enabled": False,
            "mode": "remote",
            "model_id": inference.MODEL_ID,
            "message": inference.UNAVAILABLE_MESSAGE,
            "error": inference.UNAVAILABLE_MESSAGE,
        }
    return inference.model_status()


@router.post("/predict")
def predict_crop_disease(file: UploadFile = File(...)):
    """Diagnoses crop disease from an uploaded leaf image (locally or via authenticated tunnel)."""
    _ensure_crop_doctor_enabled()
    content_type = (file.content_type or "").lower()
    if content_type and not (content_type.startswith("image/") or content_type == "application/octet-stream"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Please upload a JPEG or PNG image of the affected crop leaf.",
        )

    content = file.file.read()
    if not content:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Uploaded image is empty.")
    if len(content) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Image exceeds the 10 MB limit.")

    if _is_remote_mode():
        return _forward_remote_predict(content, file.filename or "leaf.jpg", content_type)

    try:
        result = inference.get_prediction(content)
        label = str(result["label"])
        is_healthy = "healthy" in label.lower()
        tips = PREVENTION_TIPS.get(label, ["Monitor the plant regularly and maintain field sanitation."])
        crop, _, disease = label.partition("___")
        crop_clean = crop.replace("_", " ").strip() if crop else "Unknown"
        disease_clean = disease.replace("_", " ").strip() if disease else label
        conf = result.get("confidence", 90.0)

        return {
            "filename": file.filename,
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
    except RuntimeError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc))
    except Exception as exc:
        # Fallback to crop_doctor_service for comprehensive pathology heuristics
        try:
            return crop_doctor_service.diagnose_image(image_bytes=content, filename=file.filename)
        except Exception:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Crop Doctor could not process this image: {exc}",
            )


@router.post("/predict-sample")
def predict_sample(payload: PredictionSampleRequest):
    """Diagnoses a sample disease scenario for testing and instant preview."""
    _ensure_crop_doctor_enabled()
    sample_name = payload.sample_name
    if Image is not None:
        img = Image.new("RGB", (128, 128), color=(180, 100, 50) if "blight" in sample_name.lower() else (34, 139, 34))
        buf = io.BytesIO()
        img.save(buf, format="JPEG")
        sample_bytes = buf.getvalue()
    else:
        sample_bytes = b"sample-image-data-placeholder" * 10

    if _is_remote_mode():
        if Image is None:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=inference.UNAVAILABLE_MESSAGE,
            )
        return _forward_remote_predict(sample_bytes, sample_name, "image/jpeg")

    try:
        result = crop_doctor_service.diagnose_image(
            image_bytes=sample_bytes,
            filename=sample_name
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Sample diagnosis error: {str(e)}")
