import pytest
from cropnet.services.api.app.schemas.rashkar.income import (
    FarmerResourceProfile,
    OpportunityCatalogItem,
    EnterpriseFinancialAnalysis,
    FinancialScenarioItem,
    DiscoveredOpportunity
)

def test_farmer_resource_profile_accepts_zero_budget():
    """Verify that a farmer with ₹0 available capital is fully supported without validation failure."""
    profile = FarmerResourceProfile(
        available_investment_inr=0.0,
        monthly_operating_budget_inr=0.0,
        available_land_acres=1.5,
        unused_land_acres=0.0,
        water_availability="rainfed_only",
        family_labor_hours_day=2.0
    )
    assert profile.available_investment_inr == 0.0
    assert profile.monthly_operating_budget_inr == 0.0
    assert profile.is_zero_budget is True

def test_opportunity_catalog_item_categories_and_cost_saving():
    """Verify that 5 opportunity categories and cost-saving flags are supported."""
    opp = OpportunityCatalogItem(
        opportunity_id="OPP_COMPOST_COST_SAVING_01",
        title="On-Farm Crop Residue Composting for Fertilizer Cost Reduction",
        category="zero_cash",
        is_cost_saving=True,
        tagline="Cut chemical fertilizer purchase expenses using surplus crop biomass",
        min_investment_inr=0.0,
        max_investment_inr=1500.0,
        required_land_acres=0.02,
        water_requirement="very_low",
        daily_labor_hours=1.0,
        risk_level="low",
        payback_period_months=2,
        potential_annual_profit_inr=0.0,
        potential_annual_savings_inr=14000.0,
        summary="Convert stubble and farmyard manure into rich compost, eliminating commercial DAP/NPK bags.",
        market_commodity="Compost Organic Fertilizer",
        market_benchmark_price="Saves ₹1,400 per 50kg bag",
        market_source="MPKV Rahuri Organic Input Guidance",
        production_cycle_days=60,
        revenue_delay_months=2
    )
    assert opp.category == "zero_cash"
    assert opp.is_cost_saving is True
    assert opp.potential_annual_savings_inr == 14000.0
    assert opp.min_investment_inr == 0.0

def test_financial_analysis_distinguishes_cash_surplus_economic_profit_and_savings():
    """Verify that financial outputs separate cash surplus, economic profit (with family labour), and savings."""
    analysis = EnterpriseFinancialAnalysis(
        scenario_id="scen_test_01",
        opportunity_id="OPP_COMPOST_COST_SAVING_01",
        opportunity_title="On-Farm Composting",
        category="zero_cash",
        is_cost_saving=True,
        custom_budget_inr=0.0,
        calculated_capex_inr=0.0,
        working_capital_inr=0.0,
        total_initial_outlay_inr=0.0,
        calculated_gross_revenue_inr=0.0,
        calculated_annual_savings_inr=14000.0,
        calculated_opex_annual_inr=1200.0,
        cash_operating_surplus_inr=12800.0,
        imputed_family_labor_cost_inr=4500.0,
        economic_profit_inr=8300.0,
        calculated_break_even_months=1.5,
        break_even_reached=True,
        assumptions_applied=["Residue available on farm", "Replaces 10 bags chemical fertilizer"],
        risks_to_monitor=["Requires light moisture preservation during hot months"],
        source_attribution="MPKV Package of Practices",
        disclaimer="Estimates based on typical Maharashtra smallholder fertilizer replacement."
    )
    assert analysis.is_cost_saving is True
    assert analysis.cash_operating_surplus_inr == 12800.0
    assert analysis.economic_profit_inr == 8300.0
    assert analysis.calculated_annual_savings_inr == 14000.0
    assert analysis.break_even_reached is True
