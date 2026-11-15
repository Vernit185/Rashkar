"""Crop Doctor — lazy, optional image-classification inference.

The PlantVillage MobileNetV2 model (torch/transformers) is loaded lazily so the
CropNet backend starts without the heavy ML stack. If the stack or model is
unavailable, the API reports a clear 503 instead of crashing at import time.
"""
import io
import threading
from typing import Any, Dict

from cropnet.services.api.app.core.config import settings

MODEL_ID = "neghani/plantvillage-mobilenetv2"
UNAVAILABLE_MESSAGE = "Crop Doctor is temporarily unavailable."

_lock = threading.Lock()
_state: Dict[str, Any] = {
    "attempted": False,
    "loaded": False,
    "error": None,
    "processor": None,
    "model": None,
}


def _load() -> None:
    global _state
    if not settings.CROP_DOCTOR_ENABLED:
        return
    with _lock:
        if _state["attempted"]:
            return
        _state["attempted"] = True
        try:
            import torch  # noqa: F401
            from transformers import AutoImageProcessor, AutoModelForImageClassification

            processor = AutoImageProcessor.from_pretrained(MODEL_ID)
            model = AutoModelForImageClassification.from_pretrained(MODEL_ID)
            model.eval()
            _state.update(loaded=True, processor=processor, model=model, error=None)
        except Exception as exc:  # pragma: no cover - depends on optional ML stack
            _state["error"] = str(exc)
            _state["loaded"] = False


def is_available() -> bool:
    if not settings.CROP_DOCTOR_ENABLED:
        return False
    _load()
    return bool(_state["loaded"])


def model_status() -> Dict[str, Any]:
    if not settings.CROP_DOCTOR_ENABLED:
        return {
            "loaded": False,
            "available": False,
            "enabled": False,
            "model_id": MODEL_ID,
            "message": UNAVAILABLE_MESSAGE,
            "error": UNAVAILABLE_MESSAGE,
        }
    _load()
    return {
        "loaded": bool(_state["loaded"]),
        "available": bool(_state["loaded"]),
        "enabled": True,
        "model_id": MODEL_ID,
        "error": _state["error"],
    }


def get_prediction(image_bytes: bytes) -> Dict[str, Any]:
    if not settings.CROP_DOCTOR_ENABLED:
        raise RuntimeError(UNAVAILABLE_MESSAGE)
    _load()
    if not _state["loaded"]:
        raise RuntimeError(
            f"Crop Doctor model is unavailable. Install torch/transformers and allow access to '{MODEL_ID}'. "
            f"Detail: {_state['error']}"
        )
    from PIL import Image
    import torch

    image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    processor = _state["processor"]
    model = _state["model"]
    inputs = processor(images=image, return_tensors="pt")
    with torch.no_grad():
        outputs = model(**inputs)
        probs = torch.nn.functional.softmax(outputs.logits, dim=-1)
    confidence, predicted_idx = torch.max(probs, dim=-1)
    label = model.config.id2label[predicted_idx.item()]
    return {"label": label, "confidence": round(float(confidence.item()) * 100, 2)}
