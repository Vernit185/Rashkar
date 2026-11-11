from typing import List, Dict, Any, Optional
from cropnet.services.api.app.schemas.rashkar.income import (
    OpportunityCatalogItem,
    FarmerResourceProfile,
    ScoredOpportunity,
    DiscoveredOpportunity,
    EnterpriseFinancialAnalysis,
    OpportunityComparisonItem
)
from cropnet.services.api.app.services.rashkar.income_knowledge_catalog import (
    EXTENDED_OPPORTUNITY_CATALOG,
    get_opportunity_by_id
)
from cropnet.services.api.app.services.rashkar.opportunity_feasibility_engine import OpportunityFeasibilityEngine
from cropnet.services.api.app.services.rashkar.income_financial_service import IncomeFinancialService

# Maintain backwards compatibility with legacy imports
OPPORTUNITY_CATALOG: List[OpportunityCatalogItem] = EXTENDED_OPPORTUNITY_CATALOG

class IncomeEngine:
    @staticmethod
    def match_opportunities(profile: FarmerResourceProfile) -> List[DiscoveredOpportunity]:
        """
        Evaluate farmer resource constraints and discover personalized opportunities
        prioritizing zero-cash and cost-saving options first.
        """
        return OpportunityFeasibilityEngine.discover_and_rank_opportunities(profile)

    @staticmethod
    def calculate_enterprise_financials(
        opportunity_id: str,
        custom_budget_inr: float,
        water_availability: str = "seasonal_canal"
    ) -> EnterpriseFinancialAnalysis:
        """
        Calculate authoritative, enterprise-specific 3-scenario financial simulation
        with 12-month production cycle cash flows and true cumulative break-even.
        """
        return IncomeFinancialService.calculate_financials(
            opportunity_id=opportunity_id,
            custom_budget_inr=custom_budget_inr,
            water_availability=water_availability
        )

    @staticmethod
    def compare_opportunities(
        opportunity_ids: List[str],
        custom_budget: float = 60000.0
    ) -> List[OpportunityComparisonItem]:
        """
        Produce a side-by-side comparison matrix for selected enterprise alternatives
        guaranteed to reconcile with single enterprise financial analyses.
        """
        return IncomeFinancialService.compare_opportunities(
            opportunity_ids=opportunity_ids,
            custom_budget_inr=custom_budget
        )
