from typing import List, Dict, Any, Optional
from cropnet.services.api.app.schemas.rashkar.income import (
    FarmerResourceProfile,
    OpportunityCatalogItem,
    DiscoveredOpportunity
)
from cropnet.services.api.app.services.rashkar.income_knowledge_catalog import EXTENDED_OPPORTUNITY_CATALOG

class OpportunityFeasibilityEngine:
    @staticmethod
    def evaluate_opportunity(
        opp: OpportunityCatalogItem,
        profile: FarmerResourceProfile
    ) -> DiscoveredOpportunity:
        matching_resources: List[str] = []
        missing_requirements: List[str] = []
        
        is_feasible = True
        feasibility_status = "FEASIBLE_NOW" if opp.category != "zero_cash" else "USES_EXISTING_RESOURCES"
        capital_gap = 0.0

        # Dynamic return tracking
        annual_profit = float(opp.potential_annual_profit_inr)
        annual_savings = float(opp.potential_annual_savings_inr)
        annual_loss_avoidance = 0.0

        # ---------------------------------------------------------------------
        # 1. CAPITAL & WORKING CAPITAL GATE
        # ---------------------------------------------------------------------
        total_required_outlay = round(opp.min_investment_inr + opp.working_capital_required_inr, 2)
        total_available_budget = round(profile.available_investment_inr + profile.monthly_operating_budget_inr, 2)

        # Check composting zero-cost validity: requires cow dung or livestock
        if opp.opportunity_id == "OPP_COMPOST_COST_SAVING_01":
            has_dung = (
                any("dung" in str(b).lower() or "manure" in str(b).lower() for b in profile.crop_byproducts)
                or profile.existing_livestock in ["indigenous_cows", "graded_buffaloes", "mixed", "dairy"]
            )
            if not has_dung:
                # Composting cannot be zero-cost without cattle dung
                starter_cost = 1200.0
                if total_available_budget < starter_cost:
                    is_feasible = False
                    capital_gap = round(starter_cost - total_available_budget, 2)
                    missing_requirements.append(
                        "Microbial Starter / Dung Inoculum: Producing compost without farm cattle requires purchasing decomposer starter culture or cow dung slurry (~₹1,200)."
                    )
                else:
                    matching_resources.append(
                        "Culture Investment: Budget allows purchasing bio-decomposer starter culture (~₹1,200) in place of farm cow dung."
                    )

        if total_available_budget < total_required_outlay:
            capital_gap = max(capital_gap, round(total_required_outlay - total_available_budget, 2))
            is_feasible = False
            feasibility_status = "NOT_CURRENTLY_AFFORDABLE"
            missing_requirements.append(
                f"Capital Gap: Total initial outlay required is ₹{total_required_outlay:,.0f} "
                f"(₹{opp.min_investment_inr:,.0f} setup + ₹{opp.working_capital_required_inr:,.0f} operating cash) "
                f"exceeding available funds of ₹{total_available_budget:,.0f}. Requires ₹{capital_gap:,.0f} additional funds."
            )
        else:
            if opp.category == "zero_cash" and is_feasible:
                matching_resources.append("Zero Extra Cash: Requires no additional capital investment.")
            elif is_feasible:
                matching_resources.append(
                    f"Capital Match: Total outlay (₹{total_required_outlay:,.0f}) fits within your available budget (₹{total_available_budget:,.0f})."
                )

        # ---------------------------------------------------------------------
        # 1B. AGRONOMIC & CROP COMPATIBILITY GATE (Sunflower / Intercropping)
        # ---------------------------------------------------------------------
        if opp.opportunity_id == "OPP_SUNFLOWER_INTERCROP_01":
            # Standing onion has high bulb rot risk and shade sensitivity
            if profile.current_crop_code in ["onion", "garlic"] and profile.unused_land_acres <= 0.0:
                is_feasible = False
                feasibility_status = "NOT_SUITABLE_CURRENTLY"
                missing_requirements.append(
                    "Agronomic Conflict: Sunflower cannot be intercropped with standing onion; root zone moisture and canopy shade damage bulb development. Requires sequential rotation post-harvest or dedicated unplanted acreage."
                )

        # ---------------------------------------------------------------------
        # 2. EQUIPMENT OWNERSHIP GATE (Crucial for Custom Hiring)
        # ---------------------------------------------------------------------
        if opp.opportunity_id == "OPP_EQUIPMENT_SHARING_01":
            equipment_keywords = ["tractor", "sprayer", "pump", "rotavator", "weeder", "cultivator", "thresher", "trailer"]
            has_machinery = any(
                any(kw in str(a).lower() for kw in equipment_keywords)
                for a in profile.existing_assets
            )
            if not has_machinery:
                is_feasible = False
                feasibility_status = "EQUIPMENT_NOT_OWNED"
                missing_requirements.append(
                    "Equipment Ownership: Requires owning a battery sprayer, water pump, power weeder, or tractor to offer paid hiring."
                )
            else:
                matching_resources.append(
                    f"Equipment Match: Owned farm machinery ({', '.join(profile.existing_assets)}) available for paid local hire."
                )

        # ---------------------------------------------------------------------
        # 3. FPO / MARKET ACCESS GATE (Crucial for Collective Aggregation)
        # ---------------------------------------------------------------------
        if opp.opportunity_id in ["OPP_DIRECT_APMC_FPO_01", "OPP_FPO_COLLECTIVE_INPUT_01"]:
            if profile.has_fpo_access:
                matching_resources.append("Market Match: Active FPO membership enables collective aggregation and bulk pricing.")
            else:
                # Still feasible through neighbor cooperative / KVK linkage, but noted
                matching_resources.append("FPO Opportunity: Open to joining local village Farmer Producer Company (FPC).")

        # ---------------------------------------------------------------------
        # 4. LAND / SPACE GATE
        # ---------------------------------------------------------------------
        if opp.required_space_type == "bund":
            if not profile.field_bunds_available:
                is_feasible = False
                feasibility_status = "NOT_SUITABLE_CURRENTLY" if is_feasible else feasibility_status
                missing_requirements.append("Space Constraint: Requires perimeter field bunds.")
            else:
                matching_resources.append("Space Match: Utilizes existing outer field perimeter bunds without taking crop land.")
        elif opp.required_space_type == "shed":
            if not profile.has_animal_shed:
                if is_feasible:
                    feasibility_status = "NEEDS_MORE_INVESTMENT"
                missing_requirements.append("Facility Note: Requires a shaded animal shelter or lean-to shed.")
            else:
                matching_resources.append("Facility Match: Existing farm animal shed satisfies shelter requirement.")
        elif opp.required_space_type == "room":
            if not profile.has_storage_room:
                if is_feasible:
                    feasibility_status = "NEEDS_MORE_INVESTMENT"
                missing_requirements.append("Facility Note: Requires a clean, shaded ventilated room (10x12 ft).")
            else:
                matching_resources.append("Facility Match: Existing storage room satisfies microclimate need.")
        elif opp.required_space_type == "field":
            avail = max(profile.available_land_acres, profile.unused_land_acres)
            if avail < opp.required_land_acres:
                is_feasible = False
                feasibility_status = "NOT_SUITABLE_CURRENTLY" if is_feasible else feasibility_status
                missing_requirements.append(
                    f"Land Constraint: Requires {opp.required_land_acres} acres; available unused land is {avail} acres."
                )
            else:
                matching_resources.append(f"Land Match: Requires {opp.required_land_acres} acres, available on farm.")
        else:
            matching_resources.append("Space Match: Fits within standard domestic farm yard.")

        # ---------------------------------------------------------------------
        # 5. WATER GATE
        # ---------------------------------------------------------------------
        if opp.water_requirement == "high":
            if profile.water_availability in ["rainfed_only", "rainfed_limited", "limited", "none"]:
                is_feasible = False
                feasibility_status = "NEEDS_MORE_WATER_OR_LABOR"
                missing_requirements.append("Water Constraint: Requires reliable perennial water; farm has rainfed/limited supply.")
            elif profile.water_availability == "seasonal_canal":
                if is_feasible:
                    feasibility_status = "NEEDS_MORE_WATER_OR_LABOR"
                missing_requirements.append("Water Alert: High water requirement requires borewell or pond buffer during peak summer.")
            else:
                matching_resources.append("Water Match: Reliable water supply meets intensive enterprise needs.")
        elif opp.water_requirement in ["low", "very_low", "none"]:
            matching_resources.append(f"Water Efficient: Low water need ({opp.water_requirement.replace('_', ' ')}) is well-suited to your farm.")

        # ---------------------------------------------------------------------
        # 6. LABOR & WORK PREFERENCE GATE
        # ---------------------------------------------------------------------
        if profile.family_labor_hours_day < opp.daily_labor_hours and not profile.hired_labor_possible:
            if is_feasible:
                feasibility_status = "NEEDS_MORE_WATER_OR_LABOR"
            missing_requirements.append(
                f"Labor Constraint: Requires {opp.daily_labor_hours} hrs/day; available family labor is {profile.family_labor_hours_day} hrs/day."
            )
        else:
            matching_resources.append(
                f"Labor Match: {profile.family_labor_hours_day} hrs/day family labor readily accommodates the {opp.daily_labor_hours} hrs/day required."
            )

        # Work preference & supervisory check
        if profile.work_preference in ["manage_supervise", "light_physical"] and opp.daily_labor_hours >= 2.0:
            if profile.family_management_role != "family_collective" and not profile.hired_labor_possible:
                missing_requirements.append(
                    f"Work Intensity Alert: Requires {opp.daily_labor_hours} hrs/day active manual labor. Your preference is {profile.work_preference.replace('_', ' ')}, so family or hired labor support is recommended."
                )

        # Payback horizon preference check
        if profile.payback_horizon in ["few_weeks", "3_to_6_months"]:
            max_acceptable_months = 1.5 if profile.payback_horizon == "few_weeks" else 6.0
            if opp.payback_period_months > max_acceptable_months:
                missing_requirements.append(
                    f"Timeline Mismatch: You preferred returns within {profile.payback_horizon.replace('_', ' ')}, but this activity has a {opp.payback_period_months}-month gestation/payback timeline."
                )

        # ---------------------------------------------------------------------
        # 7. DYNAMIC COMPOSTING RESIDUE & NITROGEN SAVINGS CALCULATION
        # ---------------------------------------------------------------------
        if opp.opportunity_id == "OPP_COMPOST_COST_SAVING_01":
            acres = profile.cultivated_acres or profile.total_farm_acres or 2.5
            # Biomass generated: ~1.4 tonnes dry matter / acre (soybean/cotton/jowar)
            total_biomass_tonnes = round(acres * 1.4, 2)
            # Cattle feed and surface mulching reserve (50%)
            feed_mulch_reserve_tonnes = round(total_biomass_tonnes * 0.50, 2)
            surplus_biomass_tonnes = round(total_biomass_tonnes - feed_mulch_reserve_tonnes, 2)
            # Compost cured yield (45% recovery rate with animal dung)
            cured_compost_tonnes = round(surplus_biomass_tonnes * 0.45, 2)
            # Chemical fertilizer equivalent: 1 tonne cured farm compost ~ 15kg N, 8kg P2O5, 12kg K2O
            # Replaces ~3.5 to 4 bags of commercial fertilizer (DAP + MOP + Urea) per tonne of compost
            bags_replaced = max(4, int(cured_compost_tonnes * 4.5))
            cost_per_bag = 1450.0  # Prevailing IFFCO DAP/complex fertilizer retail benchmark
            annual_savings = round(bags_replaced * cost_per_bag, 0)
            
            matching_resources.append(
                f"Biomass Match: {acres} acres generates ~{total_biomass_tonnes}t crop residue. "
                f"Reserving {feed_mulch_reserve_tonnes}t for cattle feed leaves ~{surplus_biomass_tonnes}t surplus, "
                f"yielding ~{cured_compost_tonnes}t organic compost and replacing {bags_replaced} commercial fertilizer bags."
            )

        # ---------------------------------------------------------------------
        # 8. TRI-PARTITE RETURN BREAKDOWN
        # ---------------------------------------------------------------------
        if opp.is_cost_saving:
            cost_savings_inr = annual_savings
            cash_income_inr = 0.0
            loss_avoidance_inr = round(annual_savings * 0.15, 0) # Residual soil moisture protection
        elif opp.opportunity_id == "OPP_SOLAR_DRYER_01":
            cost_savings_inr = 0.0
            cash_income_inr = annual_profit
            loss_avoidance_inr = round(annual_profit * 0.40, 0) # Distress sale gluts avoided
        else:
            cost_savings_inr = 0.0
            cash_income_inr = annual_profit
            loss_avoidance_inr = 0.0

        tripartite_return = {
            "additional_cash_income_inr": cash_income_inr,
            "cost_savings_inr": cost_savings_inr,
            "loss_avoidance_inr": loss_avoidance_inr
        }

        # ---------------------------------------------------------------------
        # 9. CALCULATE WEIGHTED SUITABILITY SCORE (0 to 100)
        # ---------------------------------------------------------------------
        score = 0

        # Capital Compatibility (Weight: 20)
        if total_required_outlay == 0.0:
            score += 20
        elif total_available_budget >= total_required_outlay:
            score += 20
        elif total_available_budget > 0:
            ratio = total_available_budget / total_required_outlay
            score += int(ratio * 12)

        # Space Compatibility (Weight: 15)
        if opp.required_space_type in ["none", "yard"]:
            score += 15
        elif opp.required_space_type == "bund" and profile.field_bunds_available:
            score += 15
        elif opp.required_space_type == "shed" and profile.has_animal_shed:
            score += 15
        elif opp.required_space_type == "room" and profile.has_storage_room:
            score += 15
        elif opp.required_space_type == "field" and max(profile.available_land_acres, profile.unused_land_acres) >= opp.required_land_acres:
            score += 15
        else:
            score += 4

        # Water Availability (Weight: 15)
        if opp.water_requirement in ["none", "very_low"]:
            score += 15
        elif opp.water_requirement == "low":
            score += 14 if profile.water_availability not in ["none", "rainfed_limited", "rainfed_only"] else 8
        elif opp.water_requirement == "moderate":
            score += 13 if profile.water_availability in ["reliable_year_round", "seasonal_canal"] else 5
        elif opp.water_requirement == "high":
            score += 15 if profile.water_availability == "reliable_year_round" else (8 if profile.water_availability == "seasonal_canal" else 2)

        # Labor Compatibility (Weight: 10)
        if profile.family_labor_hours_day >= opp.daily_labor_hours:
            score += 10
        elif profile.family_labor_hours_day > 0:
            score += int((profile.family_labor_hours_day / max(0.5, opp.daily_labor_hours)) * 8)

        # Market Accessibility (Weight: 15)
        if opp.market_verified:
            score += 10
            if profile.has_fpo_access or profile.has_transport:
                score += 5
            elif profile.distance_to_apmc_km and profile.distance_to_apmc_km <= 20:
                score += 3
            else:
                score += 2
        else:
            score += 5

        # Resource / Byproduct Match (Weight: 10)
        if opp.category == "zero_cash":
            score += 10
        elif any(c in opp.target_crops for c in profile.crop_byproducts) or profile.byproduct_surplus_available:
            score += 9
        elif "all" in opp.target_crops:
            score += 7
        else:
            score += 4

        # Location and Season Suitability (Weight: 10)
        score += 9

        # Farmer Interest & Risk Preference (Weight: 5)
        if profile.category_preference in ["all", opp.category]:
            score += 3
        if profile.risk_tolerance == "conservative" and opp.risk_level == "low":
            score += 2
        elif profile.risk_tolerance != "conservative":
            score += 2

        score = max(10, min(95, score))

        # Infeasible items strictly capped at <= 55
        if not is_feasible:
            score = min(55, score)

        # ---------------------------------------------------------------------
        # 10. BENEFIT LABELS & COMPATIBILITY
        # ---------------------------------------------------------------------
        if opp.is_cost_saving and annual_savings > 0:
            benefit_label = f"Saves ~₹{annual_savings:,.0f}/year in farm input expenses"
        elif annual_profit > 0:
            benefit_label = f"Earns ~₹{annual_profit:,.0f}/year additional net profit"
        else:
            benefit_label = "Reduces post-harvest loss and improves quality"

        if not is_feasible and capital_gap > 0:
            benefit_label = f"Requires ₹{capital_gap:,.0f} additional funds (setup + operational)"

        # Set final descriptive verdict & 5 clean categories
        if is_feasible:
            if opp.category == "zero_cash":
                feasibility_status = "USES_EXISTING_RESOURCES"
                verdict = "Uses resources you already have"
            else:
                feasibility_status = "FEASIBLE_NOW"
                verdict = "Affordable with your current budget"
            feasibility_category = "CAN_TRY_WITH_WHAT_YOU_HAVE"
        else:
            if 0 < capital_gap <= 10000.0:
                feasibility_status = "NOT_CURRENTLY_AFFORDABLE"
                verdict = f"Needs a small additional amount (Shortfall: ₹{capital_gap:,.0f})"
                feasibility_category = "CAN_TRY_WITH_SMALL_ADDITIONAL_AMOUNT"
            elif capital_gap > 10000.0:
                feasibility_status = "NOT_CURRENTLY_AFFORDABLE"
                verdict = f"Needs more money (Shortfall: ₹{capital_gap:,.0f})"
                feasibility_category = "NEEDS_MORE_MONEY"
            elif any("verify" in m.lower() or "information" in m.lower() for m in missing_requirements):
                feasibility_status = "NEEDS_MORE_INFORMATION"
                verdict = "Needs more information or field verification"
                feasibility_category = "NEEDS_MORE_INFORMATION"
            else:
                feasibility_status = "NOT_SUITABLE_CURRENTLY"
                verdict = "Not suitable right now"
                feasibility_category = "NOT_SUITABLE_CURRENTLY"

        # 6 Plain-Language Farmer Questions & Answers
        farmer_summary_qa = {
            "what_is_it": opp.summary,
            "why_suits_my_farm": " · ".join(matching_resources[:2]) if matching_resources else "Matches your farm profile resources.",
            "what_will_i_need": f"Investment: ₹{total_required_outlay:,.0f} (Setup: ₹{opp.min_investment_inr:,.0f}, Op: ₹{opp.working_capital_required_inr:,.0f}) | Space: {opp.required_space_type} | Daily Work: {opp.daily_labor_hours} hrs/day.",
            "how_will_i_earn_or_save": f"Annual net benefit: ~₹{max(annual_profit, annual_savings):,.0f} ({benefit_label}).",
            "when_will_i_receive_money": f"Estimated payback horizon is ~{opp.payback_period_months} months based on regional crop and market cycle.",
            "what_to_be_careful_about": missing_requirements[0] if missing_requirements else "Manage input timing, local market access, and hygiene carefully."
        }

        return DiscoveredOpportunity(
            opportunity=opp,
            feasibility_status=feasibility_status,
            suitability_score=score,
            is_feasible=is_feasible,
            capital_gap_inr=capital_gap,
            matching_resources=matching_resources,
            missing_requirements=missing_requirements,
            primary_benefit_label=benefit_label,
            evidence_source=opp.source_attribution,
            estimated_annual_profit_inr=annual_profit,
            estimated_annual_savings_inr=annual_savings,
            payback_months=float(opp.payback_period_months),
            market_benchmark_summary=f"{opp.market_commodity}: {opp.market_benchmark_price} ({opp.market_source})" if opp.market_commodity else "",
            tripartite_return=tripartite_return,
            feasibility_category=feasibility_category,
            farmer_summary_qa=farmer_summary_qa,
            suitability_score_pct=score,
            is_suitable=is_feasible,
            suitability_verdict=verdict,
            reasons_why_suitable=matching_resources,
            reasons_why_unsuitable=missing_requirements
        )

    @staticmethod
    def discover_and_rank_opportunities(
        profile: FarmerResourceProfile
    ) -> List[DiscoveredOpportunity]:
        results: List[DiscoveredOpportunity] = []

        for opp in EXTENDED_OPPORTUNITY_CATALOG:
            res = OpportunityFeasibilityEngine.evaluate_opportunity(opp, profile)
            results.append(res)

        # Sorting logic:
        # Feasible opportunities first (ranked by zero_cash, low cost, moderate, crop, group)
        # Infeasible opportunities sorted by smallest capital shortfall
        def sort_key(d: DiscoveredOpportunity):
            if d.is_feasible:
                category_order = {
                    "zero_cash": 1,
                    "very_low_cost": 2,
                    "moderate_enterprise": 3,
                    "crop_diversification": 4,
                    "group_external": 5
                }.get(d.opportunity.category, 6)
                return (0, category_order, -d.suitability_score)
            else:
                return (1, d.capital_gap_inr, -d.suitability_score)

        results.sort(key=sort_key)
        return results
