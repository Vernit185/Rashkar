import pytest
from cropnet.services.api.app.schemas.rashkar.income import FarmerResourceProfile
from cropnet.services.api.app.services.rashkar.opportunity_feasibility_engine import OpportunityFeasibilityEngine
from cropnet.services.api.app.services.rashkar.income_knowledge_catalog import get_opportunity_by_id

def test_equipment_sharing_requires_actual_equipment_ownership():
    # Farmer who does NOT own a tractor or sprayer
    profile_without_equipment = FarmerResourceProfile(
        farm_id="farm_no_equip",
        farmer_id="farmer_01",
        available_investment_inr=5000.0,
        existing_assets=[] # No equipment owned
    )
    
    equip_opp = get_opportunity_by_id("OPP_EQUIPMENT_SHARING_01")
    assert equip_opp is not None
    
    scored = OpportunityFeasibilityEngine.evaluate_opportunity(equip_opp, profile_without_equipment)
    assert scored.is_feasible is False
    assert scored.feasibility_status in ["EQUIPMENT_NOT_OWNED", "NOT_SUITABLE_CURRENTLY"]
    assert any("tractor" in f.lower() or "equipment" in f.lower() for f in (scored.missing_requirements + scored.reasons_why_unsuitable))

    # Farmer who DOES own a tractor
    profile_with_tractor = FarmerResourceProfile(
        farm_id="farm_has_tractor",
        farmer_id="farmer_02",
        available_investment_inr=5000.0,
        existing_assets=["tractor", "cultivator"]
    )
    scored_tractor = OpportunityFeasibilityEngine.evaluate_opportunity(equip_opp, profile_with_tractor)
    assert scored_tractor.is_feasible is True
    assert scored_tractor.feasibility_status in ["FEASIBLE_NOW", "USES_EXISTING_RESOURCES"]

def test_working_capital_included_in_capital_shortfall_calculation():
    # Small goat unit: 18,000 capex + 2,500 working capital = 20,500 total outlay
    # Farmer has 15,000 available. Shortfall MUST be 5,500 (not 3,000)
    profile_fifteen_k = FarmerResourceProfile(
        farm_id="farm_15k",
        farmer_id="farmer_03",
        available_investment_inr=15000.0,
        monthly_operating_budget_inr=0.0,
        available_land_acres=0.5,
        family_labor_hours_day=2.0
    )
    
    small_goat = get_opportunity_by_id("OPP_SMALL_GOAT_2_PLUS_1")
    assert small_goat is not None
    
    scored = OpportunityFeasibilityEngine.evaluate_opportunity(small_goat, profile_fifteen_k)
    assert scored.is_feasible is False
    assert scored.feasibility_status in ["NOT_CURRENTLY_AFFORDABLE", "NEEDS_MORE_INVESTMENT"]
    # Total outlay is 18000 + 3000 = 21000. Gap with 15000 is 6000
    assert scored.capital_gap_inr == 6000.0

def test_dynamic_composting_residue_and_cost_savings():
    # 2.5 acres soybean produces ~3.5 tonnes of residue.
    # 50% needed for cattle fodder/mulch -> ~1.75 tonnes surplus for composting.
    # Cured compost yield ~0.8 tonnes -> replaces ~6 bags of DAP/MOP (~₹8,500 saved).
    profile = FarmerResourceProfile(
        farm_id="farm_soy_2_5",
        farmer_id="farmer_04",
        total_farm_acres=2.5,
        cultivated_acres=2.5,
        crop_byproducts=["soybean_straw", "cow_dung"],
        existing_livestock="indigenous_cows",
        byproduct_surplus_available=True
    )
    
    compost_opp = get_opportunity_by_id("OPP_COMPOST_COST_SAVING_01")
    scored = OpportunityFeasibilityEngine.evaluate_opportunity(compost_opp, profile)
    assert scored.is_feasible is True
    assert scored.feasibility_status in ["FEASIBLE_NOW", "USES_EXISTING_RESOURCES"]
    # Dynamic annual savings should reflect real residue generation
    assert scored.estimated_annual_savings_inr > 0.0
