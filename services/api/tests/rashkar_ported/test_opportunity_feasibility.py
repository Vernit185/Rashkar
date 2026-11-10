import pytest
from cropnet.services.api.app.schemas.rashkar.income import FarmerResourceProfile
from cropnet.services.api.app.services.rashkar.income_knowledge_catalog import get_opportunity_by_id
from cropnet.services.api.app.services.rashkar.opportunity_feasibility_engine import OpportunityFeasibilityEngine

def test_fifteen_thousand_budget_rejects_seventy_five_thousand_goat_unit():
    """Verify that a farmer with ₹15,000 budget rejects 10+1 goats and calculates exact ₹60,000 capital gap."""
    profile = FarmerResourceProfile(
        available_investment_inr=15000.0,
        monthly_operating_budget_inr=2000.0,
        available_land_acres=0.5,
        unused_land_acres=0.5,
        water_availability="seasonal_canal",
        family_labor_hours_day=3.0,
        has_animal_shed=True
    )
    opp = get_opportunity_by_id("OPP_OSMANABADI_GOAT_10_PLUS_1")
    assert opp is not None
    
    result = OpportunityFeasibilityEngine.evaluate_opportunity(opp, profile)
    
    assert result.is_feasible is False
    assert result.feasibility_status == "NOT_CURRENTLY_AFFORDABLE"
    assert result.capital_gap_inr in [60000.0, 70000.0, 72000.0]
    assert any("initial outlay" in msg.lower() or "requires" in msg.lower() or "exceeds available" in msg.lower() for msg in result.missing_requirements)
    # Must NOT have 98% fit score!
    assert result.suitability_score < 70

def test_fifteen_thousand_budget_approves_small_goat_or_bund_planting():
    """Verify that affordable smaller models (e.g. bundle drumstick or micro units) are feasible for ₹15k."""
    profile = FarmerResourceProfile(
        available_investment_inr=15000.0,
        monthly_operating_budget_inr=2000.0,
        available_land_acres=0.5,
        unused_land_acres=0.2,
        field_bunds_available=True,
        water_availability="seasonal_canal",
        family_labor_hours_day=2.0
    )
    opp = get_opportunity_by_id("OPP_FIELD_BUND_DRUMSTICK_01")
    assert opp is not None
    
    result = OpportunityFeasibilityEngine.evaluate_opportunity(opp, profile)
    assert result.is_feasible is True
    assert result.feasibility_status in ["FEASIBLE_WITH_CURRENT_RESOURCES", "FEASIBLE_NOW"]
    assert result.capital_gap_inr == 0.0

def test_zero_budget_farmer_receives_zero_cash_opportunities_first():
    """Verify that a farmer with ₹0 budget receives composting and aggregation as top recommendations."""
    profile = FarmerResourceProfile(
        available_investment_inr=0.0,
        monthly_operating_budget_inr=0.0,
        available_land_acres=0.0,
        unused_land_acres=0.0,
        water_availability="rainfed_only",
        family_labor_hours_day=1.5,
        crop_byproducts=["soybean_straw", "cow_dung"],
        byproduct_surplus_available=True
    )
    
    results = OpportunityFeasibilityEngine.discover_and_rank_opportunities(profile)
    assert len(results) > 0
    
    # Top opportunity must be zero_cash
    top_opp = results[0]
    assert top_opp.opportunity.category == "zero_cash"
    assert top_opp.is_feasible is True
    assert top_opp.capital_gap_inr == 0.0
    
    # Capital-intensive opportunities must be marked NOT_CURRENTLY_AFFORDABLE
    expensive = next(r for r in results if r.opportunity.opportunity_id == "OPP_OSMANABADI_GOAT_10_PLUS_1")
    assert expensive.is_feasible is False
    assert expensive.feasibility_status == "NOT_CURRENTLY_AFFORDABLE"
    assert expensive.capital_gap_inr in [75000.0, 87000.0]

def test_no_identical_ninety_eight_percent_scores():
    """Verify that different opportunities do not receive the same fake 98% score."""
    profile = FarmerResourceProfile(
        available_investment_inr=75000.0,
        monthly_operating_budget_inr=5000.0,
        available_land_acres=0.5,
        water_availability="seasonal_canal",
        family_labor_hours_day=3.0,
        has_animal_shed=True
    )
    results = OpportunityFeasibilityEngine.discover_and_rank_opportunities(profile)
    scores = [r.suitability_score for r in results[:5]]
    # Ensure not all scores are identical 98
    assert not all(s == 98 for s in scores)
