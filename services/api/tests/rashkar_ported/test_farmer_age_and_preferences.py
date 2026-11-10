import pytest
from cropnet.services.api.app.schemas.rashkar.income import FarmerResourceProfile
from cropnet.services.api.app.services.rashkar.opportunity_feasibility_engine import OpportunityFeasibilityEngine
from cropnet.services.api.app.services.rashkar.income_knowledge_catalog import get_opportunity_by_id

def test_age_is_not_treated_as_physical_ability_or_disqualification():
    """An older farmer (above 65) who selects daily_physical work must NOT be disqualified."""
    profile_elder = FarmerResourceProfile(
        age_range="above_65",
        work_preference="daily_physical",
        available_investment_inr=15000.0,
        monthly_operating_budget_inr=1000.0,
        available_land_acres=0.5,
        unused_land_acres=0.2,
        field_bunds_available=True,
        water_availability="seasonal_canal",
        family_labor_hours_day=3.0
    )
    bund_drumstick = get_opportunity_by_id("OPP_FIELD_BUND_DRUMSTICK_01")
    assert bund_drumstick is not None
    
    scored = OpportunityFeasibilityEngine.evaluate_opportunity(bund_drumstick, profile_elder)
    # Must NOT be rejected based on age!
    assert scored.is_feasible is True
    assert scored.feasibility_category in ["CAN_TRY_WITH_WHAT_YOU_HAVE", "CAN_TRY_WITH_SMALL_ADDITIONAL_AMOUNT"]
    assert not any("age" in r.lower() and "disqualif" in r.lower() for r in scored.missing_requirements)

def test_supervisory_work_preference_flags_heavy_manual_tasks():
    """Farmer preferring supervisory/light work without family/hired labor has heavy manual tasks flagged."""
    profile_supervise = FarmerResourceProfile(
        age_range="46-55",
        work_preference="manage_supervise",
        family_management_role="self",
        family_labor_hours_day=1.0,
        hired_labor_possible=False,
        available_investment_inr=100000.0,
        monthly_operating_budget_inr=10000.0,
        has_animal_shed=True,
        water_availability="reliable_year_round"
    )
    commercial_goat = get_opportunity_by_id("OPP_OSMANABADI_GOAT_10_PLUS_1")
    assert commercial_goat is not None

    scored = OpportunityFeasibilityEngine.evaluate_opportunity(commercial_goat, profile_supervise)
    # Must contain labor preference notice
    assert any("supervis" in r.lower() or "preference" in r.lower() or "labor" in r.lower() for r in (scored.missing_requirements + scored.reasons_why_unsuitable))

def test_payback_horizon_influences_timing_advisories():
    """Farmer requesting returns within a few weeks is alerted when an activity has multi-month delay."""
    profile_fast_cash = FarmerResourceProfile(
        payback_horizon="few_weeks",
        available_investment_inr=80000.0,
        has_animal_shed=True,
        water_availability="reliable_year_round"
    )
    commercial_goat = get_opportunity_by_id("OPP_OSMANABADI_GOAT_10_PLUS_1")
    scored = OpportunityFeasibilityEngine.evaluate_opportunity(commercial_goat, profile_fast_cash)
    # Must alert about the 14-month gestation
    assert any("month" in r.lower() or "gestation" in r.lower() or "timeline" in r.lower() for r in (scored.missing_requirements + scored.reasons_why_unsuitable))

def test_sunflower_agronomic_validation_requires_compatible_crop_and_timing():
    """Standing onion at bulb development cannot be intercropped with sunflower."""
    profile_onion_field = FarmerResourceProfile(
        current_crop_code="onion",
        current_crop_stage="stage_bulb_development",
        available_land_acres=0.5,
        unused_land_acres=0.0, # No spare unplanted field
        water_availability="seasonal_canal",
        available_investment_inr=15000.0
    )
    sunflower = get_opportunity_by_id("OPP_SUNFLOWER_INTERCROP_01")
    if sunflower:
        scored = OpportunityFeasibilityEngine.evaluate_opportunity(sunflower, profile_onion_field)
        assert scored.is_feasible is False
        assert scored.feasibility_category in ["NEEDS_MORE_INFORMATION", "NOT_SUITABLE_CURRENTLY"]
        assert any("onion" in r.lower() or "agronomic" in r.lower() for r in scored.missing_requirements)

def test_composting_requires_actual_dung_or_starter_for_zero_cost():
    """Farmer without cattle dung or livestock cannot be given a ₹0 zero-cash composting recommendation."""
    profile_no_dung = FarmerResourceProfile(
        available_investment_inr=0.0,
        monthly_operating_budget_inr=0.0,
        crop_byproducts=["soybean_straw"], # Only straw, no cow dung
        existing_livestock="none",
        byproduct_surplus_available=True
    )
    compost_opp = get_opportunity_by_id("OPP_COMPOST_COST_SAVING_01")
    scored = OpportunityFeasibilityEngine.evaluate_opportunity(compost_opp, profile_no_dung)
    # If no dung and ₹0 budget, must flag requirement for starter culture/dung inoculum
    assert any("dung" in r.lower() or "culture" in r.lower() or "starter" in r.lower() for r in scored.missing_requirements)

def test_five_clean_categories_produced():
    """Verify all discovered opportunities fall strictly into the 5 farmer-facing categories."""
    profile = FarmerResourceProfile(
        available_investment_inr=15000.0,
        monthly_operating_budget_inr=2000.0,
        available_land_acres=0.5,
        field_bunds_available=True,
        water_availability="seasonal_canal",
        crop_byproducts=["soybean_straw", "cow_dung"]
    )
    results = OpportunityFeasibilityEngine.discover_and_rank_opportunities(profile)
    valid_categories = {
        "CAN_TRY_WITH_WHAT_YOU_HAVE",
        "CAN_TRY_WITH_SMALL_ADDITIONAL_AMOUNT",
        "NEEDS_MORE_MONEY",
        "NEEDS_MORE_INFORMATION",
        "NOT_SUITABLE_CURRENTLY"
    }
    for r in results:
        assert r.feasibility_category in valid_categories, f"Invalid category {r.feasibility_category} on {r.opportunity.opportunity_id}"

def test_farmer_summary_qa_populated():
    """Verify that every opportunity has the 6 plain-language answers populated."""
    profile = FarmerResourceProfile(
        available_investment_inr=5000.0,
        field_bunds_available=True,
        crop_byproducts=["soybean_straw", "cow_dung"]
    )
    compost_opp = get_opportunity_by_id("OPP_COMPOST_COST_SAVING_01")
    scored = OpportunityFeasibilityEngine.evaluate_opportunity(compost_opp, profile)
    qa = scored.farmer_summary_qa
    assert qa is not None
    assert "what_is_it" in qa
    assert "why_suits_my_farm" in qa
    assert "what_will_i_need" in qa
    assert "how_will_i_earn_or_save" in qa
    assert "when_will_i_receive_money" in qa
    assert "what_to_be_careful_about" in qa
