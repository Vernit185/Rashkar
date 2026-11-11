"""
Risk endpoints integrating Rashkar's original Worker Heat Risk and Crop Heat Risk
engines into CropNet with farm-ownership checks and shared-context adapters.
"""
import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from cropnet.services.api.app.core.database import get_db
from cropnet.services.api.app.core.security import get_current_user, CurrentUser
from cropnet.services.api.app.api.v1.endpoints.farms import _get_farm_and_verify_owner
from cropnet.services.api.app.models.soil_and_farm import FarmModel as CropNetFarmModel
from cropnet.services.api.app.models.rashkar_profiles import CanonicalCropMasterModel
from cropnet.services.api.app.schemas.rashkar.worker_heat import (
    WorkerHeatAssessmentRequest,
    WorkerHeatAssessmentResponse,
)
from cropnet.services.api.app.schemas.rashkar.crop_heat import CropHeatAssessmentResponse
from cropnet.services.api.app.schemas.rashkar.shared_profile import (
    FarmWorkerHeatAssessRequest,
    FarmCropHeatAssessRequest,
)
from cropnet.services.api.app.services.rashkar.worker_heat_engine import WorkerHeatEngine
from cropnet.services.api.app.services.rashkar.crop_heat_engine import CROP_SPECIES_PHYSIOLOGY
from cropnet.services.api.app.services.rashkar.adapters import (
    MissingSharedContextError,
    assess_worker_heat_for_farm,
    assess_crop_heat_for_farm,
)

router = APIRouter()


@router.get("/crop-heat/supported-crops")
def list_supported_heat_crops(db: Session = Depends(get_db)):
    """List crops and physiological stages supported by Rashkar's Crop Heat Engine."""
    canon_map = {c.crop_code: c for c in db.query(CanonicalCropMasterModel).all()}
    crops = []
    for code, spec in sorted(CROP_SPECIES_PHYSIOLOGY.items()):
        master = canon_map.get(code)
        crops.append({
            "crop_code": code,
            "common_name": master.common_name_en if master else code.capitalize(),
            "common_name_mr": master.common_name_mr if master else "",
            "standard_season": master.standard_season if master else "kharif",
            "night_crit_c": spec.get("night_crit_c"),
            "stages": spec.get("stages", []),
        })
    return {"crops": crops}


@router.post("/farms/{farm_id}/worker-heat", response_model=WorkerHeatAssessmentResponse)
def assess_farm_worker_heat(
    farm_id: uuid.UUID,
    payload: FarmWorkerHeatAssessRequest,
    current_user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Assess WBGT occupational heat risk for a registered CropNet farm."""
    _get_farm_and_verify_owner(farm_id, current_user, db)
    db_farm = db.query(CropNetFarmModel).filter(CropNetFarmModel.id == str(farm_id)).first()
    if not db_farm:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Farm {farm_id} not found")

    try:
        return assess_worker_heat_for_farm(
            db=db,
            current_user=current_user,
            cropnet_farm=db_farm,
            payload=payload,
        )
    except MissingSharedContextError as mce:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"code": "MISSING_WORKER_CONTEXT", "message": mce.message, "missing_fields": mce.missing_fields},
        )
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Worker heat assessment error: {exc}")


@router.post("/worker-heat/raw", response_model=WorkerHeatAssessmentResponse)
def assess_raw_worker_heat(
    request: WorkerHeatAssessmentRequest,
    current_user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Direct Rashkar WBGT solver endpoint for verified equivalence checking."""
    try:
        return WorkerHeatEngine.assess_worker_heat_hazard(request=request, db=db)
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Worker heat assessment error: {exc}")


@router.post("/farms/{farm_id}/crop-heat", response_model=CropHeatAssessmentResponse)
def assess_farm_crop_heat(
    farm_id: uuid.UUID,
    payload: FarmCropHeatAssessRequest,
    current_user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Assess crop-stage-specific heat risk for a CropNet farm's registered plot and crop."""
    _get_farm_and_verify_owner(farm_id, current_user, db)
    db_farm = db.query(CropNetFarmModel).filter(CropNetFarmModel.id == str(farm_id)).first()
    if not db_farm:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Farm {farm_id} not found")

    try:
        return assess_crop_heat_for_farm(db=db, cropnet_farm=db_farm, payload=payload)
    except MissingSharedContextError as mce:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"code": "MISSING_CROP_CONTEXT", "message": mce.message, "missing_fields": mce.missing_fields},
        )
    except ValueError as ve:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(ve))
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Crop heat assessment error: {exc}")
