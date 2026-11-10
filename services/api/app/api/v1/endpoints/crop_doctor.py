import io
from fastapi import APIRouter, File, UploadFile, HTTPException
from typing import Optional
from pydantic import BaseModel
from PIL import Image

from cropnet.services.api.app.services.crop_doctor.service import crop_doctor_service

router = APIRouter()


class PredictionSampleRequest(BaseModel):
    sample_name: str


@router.post("/predict")
async def predict_crop_disease(file: UploadFile = File(...)):
    """Diagnoses crop disease from an uploaded leaf image."""
    try:
        image_bytes = await file.read()
        if not image_bytes:
            raise HTTPException(status_code=400, detail="Empty image uploaded.")
        
        result = crop_doctor_service.diagnose_image(
            image_bytes=image_bytes,
            filename=file.filename
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Diagnostic error: {str(e)}")


@router.post("/predict-sample")
async def predict_sample(payload: PredictionSampleRequest):
    """Diagnoses a sample disease scenario for testing and instant preview."""
    try:
        sample_name = payload.sample_name
        # Create a valid synthetic sample image buffer
        img = Image.new("RGB", (128, 128), color=(180, 100, 50) if "blight" in sample_name.lower() else (34, 139, 34))
        buf = io.BytesIO()
        img.save(buf, format="JPEG")
        sample_bytes = buf.getvalue()

        result = crop_doctor_service.diagnose_image(
            image_bytes=sample_bytes,
            filename=sample_name
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Sample diagnosis error: {str(e)}")
