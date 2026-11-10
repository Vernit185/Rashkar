import pytest
from cropnet.services.api.app.services.rashkar.income_knowledge_catalog import (
    EXTENDED_OPPORTUNITY_CATALOG,
    get_catalog_by_category,
    get_opportunity_by_id
)

def test_catalog_has_all_five_categories():
    categories = {opp.category for opp in EXTENDED_OPPORTUNITY_CATALOG}
    expected = {"zero_cash", "very_low_cost", "moderate_enterprise", "crop_diversification", "group_external"}
    assert expected.issubset(categories), f"Missing categories: {expected - categories}"

def test_zero_cash_opportunities_exist():
    zero_cash_opps = get_catalog_by_category("zero_cash")
    assert len(zero_cash_opps) >= 3, "Must have at least 3 zero-cash opportunities"
    
    ids = [o.opportunity_id for o in zero_cash_opps]
    assert "OPP_COMPOST_COST_SAVING_01" in ids
    assert "OPP_DIRECT_APMC_FPO_01" in ids
    assert "OPP_EQUIPMENT_SHARING_01" in ids
    
    compost = next(o for o in zero_cash_opps if o.opportunity_id == "OPP_COMPOST_COST_SAVING_01")
    assert compost.min_investment_inr == 0.0
    assert compost.is_cost_saving is True
    assert compost.potential_annual_savings_inr > 0

def test_small_scale_goat_model_exists_for_low_budget():
    """Verify that a small 2+1 goat model exists so smallholders aren't forced into ₹75,000 units."""
    small_goat = get_opportunity_by_id("OPP_SMALL_GOAT_2_PLUS_1")
    assert small_goat is not None
    assert small_goat.min_investment_inr < 25000.0
    assert small_goat.min_investment_inr >= 15000.0

def test_commercial_goat_unit_has_proper_capital():
    commercial_goat = get_opportunity_by_id("OPP_OSMANABADI_GOAT_10_PLUS_1")
    assert commercial_goat is not None
    assert commercial_goat.min_investment_inr == 75000.0

def test_provenance_citations_and_assumptions():
    for opp in EXTENDED_OPPORTUNITY_CATALOG:
        assert len(opp.source_attribution) > 5, f"Opportunity {opp.opportunity_id} missing source"
        assert len(opp.key_assumptions) >= 2, f"Opportunity {opp.opportunity_id} missing assumptions"
        assert len(opp.key_risks) >= 1, f"Opportunity {opp.opportunity_id} missing risks"
