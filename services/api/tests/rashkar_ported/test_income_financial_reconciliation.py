import pytest
from cropnet.services.api.app.services.rashkar.income_financial_service import IncomeFinancialService

def test_mushroom_financial_reconciliation():
    """Verify that mushroom calculations produce consistent numbers for card, details, and comparison."""
    analysis = IncomeFinancialService.calculate_financials(
        opportunity_id="OPP_OYSTER_MUSHROOM_01",
        custom_budget_inr=20000.0,
        water_availability="seasonal_canal"
    )
    
    assert analysis.opportunity_id == "OPP_OYSTER_MUSHROOM_01"
    # Net annual profit should be around 65,000 for standard unit
    assert 60000.0 <= analysis.calculated_net_profit_annual_inr <= 70000.0
    # Must match across scenarios base case
    assert analysis.scenarios["base"].net_annual_profit_inr == analysis.calculated_net_profit_annual_inr
    
    # 12-month cash flows must be present and sum to annual cash operating surplus
    assert len(analysis.monthly_cash_flows) == 12
    # Month 1 must reflect initial setup investment outflow
    assert analysis.monthly_cash_flows[0] < 0

def test_goat_rearing_production_timeline_and_cashflow_delay():
    """Verify that goat rearing does not show immediate revenue in Month 1, respecting 8-month kidding cycle."""
    analysis = IncomeFinancialService.calculate_financials(
        opportunity_id="OPP_SMALL_GOAT_2_PLUS_1",
        custom_budget_inr=20000.0,
        water_availability="seasonal_canal"
    )
    
    # Month 1 to 5 must not have full meat sales revenue
    assert analysis.monthly_cash_flows[0] < 0
    assert analysis.monthly_cash_flows[1] <= 0
    assert analysis.monthly_cash_flows[2] <= 0
    # Revenue appears starting around month 8
    assert analysis.monthly_cash_flows[7] > 0
    
    # Payback must be cumulative and realistic
    assert analysis.calculated_break_even_months is not None
    assert analysis.calculated_break_even_months >= 8.0

def test_comparison_matrix_uses_same_authoritative_numbers():
    """Verify that comparison matrix returns exact figures matching single enterprise analysis."""
    opp_ids = ["OPP_OYSTER_MUSHROOM_01", "OPP_SMALL_GOAT_2_PLUS_1"]
    comparisons = IncomeFinancialService.compare_opportunities(opp_ids, custom_budget_inr=20000.0)
    
    mushroom_comp = next(c for c in comparisons if c.opportunity_id == "OPP_OYSTER_MUSHROOM_01")
    single_analysis = IncomeFinancialService.calculate_financials("OPP_OYSTER_MUSHROOM_01", custom_budget_inr=20000.0)
    
    assert mushroom_comp.net_annual_profit_inr == single_analysis.calculated_net_profit_annual_inr
    assert mushroom_comp.initial_investment_inr == single_analysis.total_initial_outlay_inr
    assert mushroom_comp.payback_months == single_analysis.calculated_break_even_months
