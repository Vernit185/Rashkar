from datetime import date, datetime
from typing import Optional, Dict, Any
from sqlalchemy.orm import Session
from cropnet.services.api.app.models.rashkar_profiles import CropStageReferenceModel
from cropnet.services.api.app.services.rashkar.timezone import now_ist

class CropStageService:
    @staticmethod
    def estimate_crop_stage(
        db: Session,
        crop_code: str,
        sowing_date: date,
        farmer_confirmed_stage: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Estimate current phenological stage based on sowing date and SAU reference durations.
        Farmer confirmed stage takes strict precedence if provided.
        """
        today = now_ist().date()
        das = max(0, (today - sowing_date).days)

        # Query all stage references for this crop sorted by sequence
        stages = db.query(CropStageReferenceModel).filter(
            CropStageReferenceModel.crop_code == crop_code.lower()
        ).order_by(CropStageReferenceModel.sequence_order).all()

        if not stages:
            # Fallback for generic unsupported crops
            return {
                "stage_code": farmer_confirmed_stage or "GENERAL_GROWTH",
                "stage_name_en": farmer_confirmed_stage or "Vegetative / General Growth",
                "stage_name_mr": "वाढीची अवस्था",
                "days_after_sowing": das,
                "stage_source": "farmer_confirmed" if farmer_confirmed_stage else "generic_heuristic",
                "farmer_confirmed": bool(farmer_confirmed_stage),
                "confidence": "high" if farmer_confirmed_stage else "low",
                "heat_sensitivity": "medium",
                "drought_sensitivity": "medium",
                "excess_water_sensitivity": "medium"
            }

        # If farmer explicitly confirmed a stage, locate and return it
        if farmer_confirmed_stage:
            norm_target = farmer_confirmed_stage.lower().replace("stage_", "")
            matched = next(
                (s for s in stages if s.stage_code.lower() == farmer_confirmed_stage.lower() or norm_target in s.stage_code.lower() or s.stage_code.lower() in norm_target),
                None
            )
            if matched:
                return {
                    "stage_code": matched.stage_code,
                    "stage_name_en": matched.stage_name_en,
                    "stage_name_mr": matched.stage_name_mr,
                    "days_after_sowing": das,
                    "stage_source": "farmer_confirmed",
                    "farmer_confirmed": True,
                    "is_expired": False,
                    "season_status": "ACTIVE",
                    "confidence": "high",
                    "heat_sensitivity": matched.heat_sensitivity,
                    "drought_sensitivity": matched.drought_sensitivity,
                    "excess_water_sensitivity": matched.excess_water_sensitivity
                }

        # Check if crop season has expired based on typical maturity limits
        max_das_end = max(s.das_end_typical for s in stages)
        if das > max_das_end + 15:
            return {
                "stage_code": None,
                "stage_name_en": "Crop Season Expired (DAS exceeded typical season)",
                "stage_name_mr": "हंगाम समाप्त झाला",
                "days_after_sowing": das,
                "stage_source": "expired_crop_season",
                "farmer_confirmed": False,
                "is_expired": True,
                "season_status": "EXPIRED",
                "max_typical_das": max_das_end,
                "confidence": "high",
                "heat_sensitivity": "none",
                "drought_sensitivity": "none",
                "excess_water_sensitivity": "none"
            }

        # Match by Days-After-Sowing (DAS)
        matched_stage = stages[0]
        for s in stages:
            if das >= s.das_start_typical:
                matched_stage = s
            if das <= s.das_end_typical:
                matched_stage = s
                break

        return {
            "stage_code": matched_stage.stage_code,
            "stage_name_en": matched_stage.stage_name_en,
            "stage_name_mr": matched_stage.stage_name_mr,
            "days_after_sowing": das,
            "stage_source": "sowing_date_estimate",
            "farmer_confirmed": False,
            "is_expired": False,
            "season_status": "ACTIVE",
            "confidence": "medium",
            "heat_sensitivity": matched_stage.heat_sensitivity,
            "drought_sensitivity": matched_stage.drought_sensitivity,
            "excess_water_sensitivity": matched_stage.excess_water_sensitivity
        }

    estimate_growth_stage = estimate_crop_stage
