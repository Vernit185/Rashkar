"""
Shared Farmer, Farm Plot, and Crop Cycle Endpoints anchored on CropNet's `farms.id`.
Single source of truth consumed across Worker Heat Risk, Crop Heat Risk, Extra Income,
and CropNet registration/profile workflows.
"""
import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from cropnet.services.api.app.core.database import get_db
from cropnet.services.api.app.core.security import get_current_user, CurrentUser
from cropnet.services.api.app.api.v1.endpoints.farms import _get_farm_and_verify_owner
from cropnet.services.api.app.models.soil_and_farm import FarmModel as CropNetFarmModel
from cropnet.services.api.app.models.rashkar_profiles import FarmPlotModel, CropCycleModel
from cropnet.services.api.app.schemas.rashkar.shared_profile import (
    SharedFarmContextResponse,
    SharedFarmContextUpdateRequest,
    FarmPlotResponse,
    FarmPlotUpsertRequest,
    CropCycleResponse,
    CropCycleUpsertRequest,
    CropCycleStageUpdateRequest,
)
from cropnet.services.api.app.services.rashkar.adapters import (
    build_shared_context_response,
    update_shared_context,
    upsert_plot_for_farm,
    upsert_crop_cycle_for_farm,
)
from cropnet.services.api.app.services.rashkar.crop_stage_service import CropStageService
from cropnet.services.api.app.services.rashkar.timezone import now_utc

router = APIRouter()


def _load_owned_cropnet_farm(
    farm_id: uuid.UUID, current_user: CurrentUser, db: Session
) -> CropNetFarmModel:
    _get_farm_and_verify_owner(farm_id, current_user, db)
    db_farm = db.query(CropNetFarmModel).filter(CropNetFarmModel.id == str(farm_id)).first()
    if not db_farm:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Farm {farm_id} not found",
        )
    return db_farm


@router.get("/{farm_id}/shared-context", response_model=SharedFarmContextResponse)
def get_farm_shared_context(
    farm_id: uuid.UUID,
    current_user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Retrieve unified CropNet farm registration + shared farmer/plot/crop/resource context."""
    db_farm = _load_owned_cropnet_farm(farm_id, current_user, db)
    return build_shared_context_response(db=db, current_user=current_user, cropnet_farm=db_farm)


@router.put("/{farm_id}/shared-context", response_model=SharedFarmContextResponse)
def put_farm_shared_context(
    farm_id: uuid.UUID,
    payload: SharedFarmContextUpdateRequest,
    current_user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Update shared farmer, worker, or resource profile fields once across all features."""
    db_farm = _load_owned_cropnet_farm(farm_id, current_user, db)
    return update_shared_context(db=db, current_user=current_user, cropnet_farm=db_farm, payload=payload)


@router.get("/{farm_id}/plots", response_model=List[FarmPlotResponse])
def list_farm_plots(
    farm_id: uuid.UUID,
    current_user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """List plots registered under an existing CropNet farm."""
    db_farm = _load_owned_cropnet_farm(farm_id, current_user, db)
    return build_shared_context_response(db=db, current_user=current_user, cropnet_farm=db_farm).plots


@router.post("/{farm_id}/plots", response_model=FarmPlotResponse, status_code=status.HTTP_201_CREATED)
def create_farm_plot(
    farm_id: uuid.UUID,
    payload: FarmPlotUpsertRequest,
    current_user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Register an additional plot under an existing CropNet farm."""
    db_farm = _load_owned_cropnet_farm(farm_id, current_user, db)
    return upsert_plot_for_farm(db=db, cropnet_farm=db_farm, payload=payload)


@router.get("/{farm_id}/crop-cycles", response_model=List[CropCycleResponse])
def list_farm_crop_cycles(
    farm_id: uuid.UUID,
    current_user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """List crop cycles across plots for an existing CropNet farm."""
    db_farm = _load_owned_cropnet_farm(farm_id, current_user, db)
    return build_shared_context_response(db=db, current_user=current_user, cropnet_farm=db_farm).crop_cycles


@router.post("/{farm_id}/crop-cycles", response_model=CropCycleResponse, status_code=status.HTTP_201_CREATED)
def create_farm_crop_cycle(
    farm_id: uuid.UUID,
    payload: CropCycleUpsertRequest,
    current_user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Register an active planted crop & sowing date for a CropNet farm/plot."""
    db_farm = _load_owned_cropnet_farm(farm_id, current_user, db)
    try:
        return upsert_crop_cycle_for_farm(db=db, cropnet_farm=db_farm, payload=payload)
    except ValueError as ve:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(ve))


@router.patch("/{farm_id}/crop-cycles/{cycle_id}/stage", response_model=CropCycleResponse)
def update_crop_cycle_stage(
    farm_id: uuid.UUID,
    cycle_id: str,
    payload: CropCycleStageUpdateRequest,
    current_user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Persist farmer-confirmed growth stage on a specific crop cycle."""
    _load_owned_cropnet_farm(farm_id, current_user, db)
    row = (
        db.query(CropCycleModel, FarmPlotModel)
        .join(FarmPlotModel, CropCycleModel.plot_id == FarmPlotModel.plot_id)
        .filter(CropCycleModel.cycle_id == cycle_id, FarmPlotModel.farm_id == str(farm_id))
        .first()
    )
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Crop cycle '{cycle_id}' not found")
    cycle, plot = row
    cycle.current_stage_code = payload.farmer_confirmed_stage
    cycle.stage_updated_at = now_utc()
    db.commit()
    db.refresh(cycle)
    st_info = CropStageService.estimate_crop_stage(
        db=db,
        crop_code=cycle.crop_code,
        sowing_date=cycle.sowing_date,
        farmer_confirmed_stage=cycle.current_stage_code,
    )
    return CropCycleResponse(
        cycle_id=cycle.cycle_id,
        plot_id=plot.plot_id,
        plot_name=plot.plot_name,
        farm_id=str(farm_id),
        crop_code=cycle.crop_code,
        variety_name=cycle.variety_name,
        season=cycle.season,
        sowing_date=cycle.sowing_date,
        planted_area_acres=cycle.planted_area_acres,
        irrigation_type=plot.irrigation_type,
        current_stage_code=cycle.current_stage_code,
        estimated_stage_code=st_info.get("stage_code"),
        estimated_stage_name=st_info.get("stage_name_en"),
        days_after_sowing=st_info.get("days_after_sowing"),
        is_active=bool(cycle.is_active),
    )
