"""Crop Doctor — image-based crop disease recognition endpoint."""
from fastapi import APIRouter, File, HTTPException, UploadFile, status
from starlette.concurrency import run_in_threadpool

from cropnet.services.api.app.services.crop_doctor import inference
from cropnet.services.api.app.services.crop_doctor.advice import PREVENTION_TIPS

router = APIRouter()

MAX_IMAGE_BYTES = 10 * 1024 * 1024  # 10 MB


@router.get("/status")
def crop_doctor_status():
    """Report whether the optional vision model stack is loaded."""
    return inference.model_status()


@router.post("/predict")
async def predict_crop_disease(file: UploadFile = File(...)):
    """Classify a crop leaf image and return the diagnosis plus preventive advice."""
    content_type = (file.content_type or "").lower()
    if content_type and not content_type.startswith("image/"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Please upload a JPEG or PNG image of the affected crop leaf.",
        )

    content = await file.read(MAX_IMAGE_BYTES + 1)
    if not content:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Uploaded image is empty.")
    if len(content) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Image exceeds the 10 MB limit.")

    try:
        result = await run_in_threadpool(inference.get_prediction, content)
    except RuntimeError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc))
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Crop Doctor could not process this image: {exc}",
        )

    label = str(result["label"])
    is_healthy = "healthy" in label.lower()
    tips = PREVENTION_TIPS.get(label, ["Monitor the plant regularly and maintain field sanitation."])
    crop, _, disease = label.partition("___")

    return {
        "filename": file.filename,
        "crop": crop.replace("_", " ").strip() if crop else "Unknown",
        "diagnosis": disease.replace("_", " ").strip() if disease else label,
        "raw_label": label,
        "confidence_percent": result["confidence"],
        "is_healthy": is_healthy,
        "actionable_advice": tips,
        "disclaimer": (
            "Automated image classification is a screening aid, not a laboratory diagnosis. "
            "Confirm with a local agronomist before applying chemical treatments."
        ),
    }
