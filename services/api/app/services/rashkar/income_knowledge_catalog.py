from typing import List, Optional
from cropnet.services.api.app.schemas.rashkar.income import OpportunityCatalogItem

EXTENDED_OPPORTUNITY_CATALOG: List[OpportunityCatalogItem] = [
    # -------------------------------------------------------------------------
    # CATEGORY A: Zero-Additional-Cash-Cost Opportunities
    # -------------------------------------------------------------------------
    OpportunityCatalogItem(
        opportunity_id="OPP_COMPOST_COST_SAVING_01",
        title="On-Farm Crop Residue Composting for Fertilizer Cost Reduction",
        category="zero_cash",
        is_cost_saving=True,
        tagline="Cut chemical fertilizer purchase expenses using surplus crop biomass and cow dung",
        min_investment_inr=0.0,
        max_investment_inr=1500.0,
        working_capital_required_inr=0.0,
        required_land_acres=0.02,
        required_space_type="yard",
        water_requirement="very_low",
        daily_labor_hours=0.75,
        risk_level="low",
        payback_period_months=2,
        potential_annual_profit_inr=0.0,
        potential_annual_savings_inr=14000.0,
        summary="Converts surplus crop residues (soybean straw, cotton stalks, jowar stover) and farmyard cow dung into high-grade organic manure. Replaces 8-12 bags of purchased commercial chemical fertilizers (DAP/MOP/Urea).",
        market_commodity="Farmyard Organic Fertilizer (On-Farm Replacement)",
        market_benchmark_price="Saves ₹1,350 to ₹1,500 per 50kg DAP bag",
        market_source="MPKV Rahuri Organic Input Guidance & IFFCO Retail Benchmark",
        market_verified=True,
        target_crops=["soybean", "cotton", "jowar", "onion", "sugarcane", "all"],
        key_assumptions=[
            "Surplus residue: ~3 to 4 tonnes available from current harvest",
            "Cow dung: available from at least 1-2 farm animals or neighbor barter",
            "Curing time: 60-75 days with regular aerated heap turning"
        ],
        key_risks=[
            "Heap drying out during hot summer (> 40°C) without shaded cover",
            "Incomplete decomposition if coarse stalks are not chopped"
        ],
        source_attribution="MPKV Rahuri University Package of Practices & NABARD Organic Farm Demonstration Protocol",
        minimum_viable_unit_description="2 compost heaps (15x5 ft) on field boundary",
        production_cycle_days=60,
        revenue_delay_months=2
    ),
    OpportunityCatalogItem(
        opportunity_id="OPP_DIRECT_APMC_FPO_01",
        title="Collective Grain Aggregation & Direct APMC Grading Realization",
        category="zero_cash",
        is_cost_saving=False,
        tagline="Capture higher price realization by grading produce and selling through local FPO",
        min_investment_inr=0.0,
        max_investment_inr=2000.0,
        working_capital_required_inr=0.0,
        required_land_acres=0.0,
        required_space_type="yard",
        water_requirement="none",
        daily_labor_hours=1.0,
        risk_level="low",
        payback_period_months=1,
        potential_annual_profit_inr=18000.0,
        potential_annual_savings_inr=0.0,
        summary="Sorts and sieves harvest using farm manual sieves (chaalni) into Grade-A produce, eliminating middleman distress deductions. Aggregates quantity with registered village FPO for direct delivery to regional market yard.",
        market_commodity="Clean Graded Soybean / Jowar / Onion",
        market_benchmark_price="₹250 - ₹400 / quintal premium over uncleaned field-run grain",
        market_source="Maharashtra State Agricultural Marketing Board (MSAMB) APMC Benchmark",
        market_verified=True,
        target_crops=["soybean", "jowar", "onion", "cotton", "all"],
        key_assumptions=[
            "Marketable surplus: at least 30-40 quintals",
            "Grading rejects (culls/broken): used on-farm or sold at secondary rate",
            "FPO pooling eliminates individual small-lot transport penalties"
        ],
        key_risks=[
            "Delayed settlement from buyer (typically 7-14 days)",
            "Moisture content exceeding 12% leading to mandi deduction"
        ],
        source_attribution="MSAMB Produce Grading Standards & NABARD Farmer Producer Organization Guidelines",
        minimum_viable_unit_description="Manual farm-level grading with existing tarpaulin and sieves",
        production_cycle_days=15,
        revenue_delay_months=1
    ),
    OpportunityCatalogItem(
        opportunity_id="OPP_EQUIPMENT_SHARING_01",
        title="Custom Hiring of Underutilized Farm Assets & Equipment",
        category="zero_cash",
        is_cost_saving=False,
        tagline="Earn hourly hire fees by renting idle sprayers, pumps or implements to neighbors",
        min_investment_inr=0.0,
        max_investment_inr=1000.0,
        working_capital_required_inr=0.0,
        required_land_acres=0.0,
        required_space_type="none",
        water_requirement="none",
        daily_labor_hours=1.5,
        risk_level="low",
        payback_period_months=1,
        potential_annual_profit_inr=24000.0,
        potential_annual_savings_inr=0.0,
        summary="Leverages owned equipment (battery-operated knapsack sprayer, power weeder, diesel water pump, or tractor implements) during non-peak farm days to provide paid custom hiring services to adjacent smallholders.",
        market_commodity="Agricultural Equipment Custom Hiring Service",
        market_benchmark_price="₹150 - ₹250 / hour for power sprayer; ₹800 - ₹1,200 / acre for power weeder",
        market_source="Maharashtra State Department of Agriculture Custom Hiring Center Rates",
        market_verified=True,
        target_crops=["all"],
        key_assumptions=[
            "Asset already owned in good working order",
            "Service scheduled during off-days to avoid conflicting with own crop operations",
            "Hirer provides fuel / chemical inputs"
        ],
        key_risks=[
            "Wear and tear or breakdown during rental use",
            "Payment default from casual local hirers"
        ],
        source_attribution="ICAR Central Institute of Agricultural Engineering (CIAE) Custom Hiring Norms",
        minimum_viable_unit_description="Sharing of existing owned equipment 2-3 days per week",
        production_cycle_days=30,
        revenue_delay_months=1
    ),
    OpportunityCatalogItem(
        opportunity_id="OPP_POST_HARVEST_STORAGE_01",
        title="Post-Harvest Grain Protection & Storage Loss Reduction",
        category="zero_cash",
        is_cost_saving=True,
        tagline="Prevent 8-12% post-harvest grain losses through hermetic storage bags and neem treatment",
        min_investment_inr=0.0,
        max_investment_inr=3000.0,
        working_capital_required_inr=0.0,
        required_land_acres=0.0,
        required_space_type="shed",
        water_requirement="none",
        daily_labor_hours=0.5,
        risk_level="low",
        payback_period_months=2,
        potential_annual_profit_inr=0.0,
        potential_annual_savings_inr=16000.0,
        summary="Protects harvested grains from pulse beetle (bruchid), weevil damage, and moisture degradation using farm-dried neem leaf layering and proper hermetic sealing in an existing shed or dry room, preserving market quality.",
        market_commodity="Saved Grain Inventory Protection",
        market_benchmark_price="Preserves full ₹4,500 - ₹5,000 / quintal value against 10% insect spoilage",
        market_source="Indian Grain Storage Management and Research Institute (IGGMRI) Field Norms",
        market_verified=True,
        target_crops=["soybean", "jowar", "chickpea", "pigeonpea", "all"],
        key_assumptions=[
            "Grain sun-dried to below 10-12% moisture prior to packing",
            "Existing secure room or dry shed available",
            "Avoids distress sale during immediate post-harvest glut"
        ],
        key_risks=[
            "Rodent intrusion if bags are placed directly on floor without pallets",
            "Moisture condensation if room lacks adequate air circulation"
        ],
        source_attribution="IGGMRI Hapur / ICAR Post-Harvest Loss Assessment Norms",
        minimum_viable_unit_description="Proper drying and hermetic bagging of 25-35 quintals in existing shed",
        production_cycle_days=90,
        revenue_delay_months=3
    ),

    # -------------------------------------------------------------------------
    # CATEGORY B: Very Low-Investment Opportunities
    # -------------------------------------------------------------------------
    OpportunityCatalogItem(
        opportunity_id="OPP_FIELD_BUND_DRUMSTICK_01",
        title="Field Bund Horticultural Planting (PKM-1 Drumstick / Moringa)",
        category="very_low_cost",
        is_cost_saving=False,
        tagline="Productive utilization of farm perimeter bunds without taking any cultivated land",
        min_investment_inr=1500.0,
        max_investment_inr=3500.0,
        working_capital_required_inr=500.0,
        required_land_acres=0.0,
        required_space_type="bund",
        water_requirement="very_low",
        daily_labor_hours=0.5,
        risk_level="low",
        payback_period_months=8,
        potential_annual_profit_inr=22000.0,
        potential_annual_savings_inr=0.0,
        summary="Plants 25-30 PKM-1 or ODC3 annual moringa saplings along outer field bunds spaced 3m apart. Generates pods within 6-7 months with zero encroachment on primary field crops.",
        market_commodity="Fresh Drumsticks (Shenga)",
        market_benchmark_price="₹35 - ₹65 / kg at local taluka weekly bazaar",
        market_source="Agmarknet Solapur & Pune APMC Vegetables Section",
        market_verified=True,
        target_crops=["all"],
        key_assumptions=[
            "25 trees planted along 150m bund boundary",
            "Yield: 15-20 kg marketable pods per tree annually",
            "Minimal watering needed once taproots establish (after 60 days)"
        ],
        key_risks=[
            "Damage by stray cattle or wild boars during early sapling stage",
            "Hairy caterpillar infestation requiring neem spray"
        ],
        source_attribution="Tamil Nadu Agricultural University (TNAU) PKM-1 Moringa Protocol & MPKV Rahuri Agroforestry Norms",
        minimum_viable_unit_description="25 saplings along 150m outer farm bunds",
        production_cycle_days=210,
        revenue_delay_months=7
    ),
    OpportunityCatalogItem(
        opportunity_id="OPP_PRO_TRAY_NURSERY_01",
        title="Backyard Pro-Tray Seedling Raising (Tomato, Chilli & Onion)",
        category="very_low_cost",
        is_cost_saving=False,
        tagline="Raise disease-free seedling trays under domestic shade net for neighbors",
        min_investment_inr=3500.0,
        max_investment_inr=8000.0,
        working_capital_required_inr=1500.0,
        required_land_acres=0.02,
        required_space_type="yard",
        water_requirement="low",
        daily_labor_hours=1.0,
        risk_level="low",
        payback_period_months=3,
        potential_annual_profit_inr=32000.0,
        potential_annual_savings_inr=0.0,
        summary="Raises 2,500 to 3,500 high-germination seedlings in 98-cell pro-trays using cocopeat and vermicompost media under a simple green shade cloth. Serves vegetable-growing neighbors before transplanting season.",
        market_commodity="Hardened Vegetable Plug Seedlings",
        market_benchmark_price="₹0.90 - ₹1.30 per healthy seedling",
        market_source="Local Commercial Vegetable Clusters (Narayangaon, Junnar, Niphad)",
        market_verified=True,
        target_crops=["onion", "tomato", "chilli", "vegetables", "all"],
        key_assumptions=[
            "Capacity: 30 trays (2,940 seedlings) per batch, 4 batches/year",
            "Turnaround: 25-32 days per seedling batch",
            "Germination rate: > 90% using certified hybrid seed"
        ],
        key_risks=[
            "Damping-off fungal infection if over-watered during monsoon",
            "Unsold trays if regional planting is delayed due to dry spells"
        ],
        source_attribution="National Horticulture Board (NHB) Plug Nursery Unit Protocol",
        minimum_viable_unit_description="30 pro-trays (98 cells) under 150 sq ft domestic shade cloth",
        production_cycle_days=30,
        revenue_delay_months=2
    ),
    OpportunityCatalogItem(
        opportunity_id="OPP_MICRO_VERMICOMPOST_01",
        title="Micro-Scale Vermicompost Unit (Single HDPE Bed)",
        category="very_low_cost",
        is_cost_saving=True,
        tagline="Low-cost 12x4 ft HDPE vermi-bed producing worm castings and liquid vermiwash",
        min_investment_inr=4500.0,
        max_investment_inr=9500.0,
        working_capital_required_inr=1000.0,
        required_land_acres=0.01,
        required_space_type="yard",
        water_requirement="very_low",
        daily_labor_hours=0.5,
        risk_level="low",
        payback_period_months=4,
        potential_annual_profit_inr=12000.0,
        potential_annual_savings_inr=18000.0,
        summary="Single UV-stabilized HDPE vermiculture bed (12x4x2 ft) seeded with Eisenia fetida earthworms. Converts 3 tonnes of chopped farm stubble and dung into 1.8 tonnes of rich vermicompost and 100 litres of foliar vermiwash.",
        market_commodity="Vermicompost & Liquid Vermiwash",
        market_benchmark_price="₹8.00 - ₹10.00 / kg vermicompost; ₹40 / L vermiwash",
        market_source="Local Horticultural Orchard Growers & Urban Garden Centers",
        market_verified=True,
        target_crops=["soybean", "cotton", "onion", "sugarcane", "all"],
        key_assumptions=[
            "Single durable HDPE bed with aeration net windows and vermiwash tap",
            "Harvest cycle: 60 days per batch (4 batches per year)",
            "Dual benefit: half utilized on-farm for chemical saving, surplus sold"
        ],
        key_risks=[
            "Excessive heat (> 38°C) killing worms without shade net cover",
            "Ant or bird predation if top moisture cover is neglected"
        ],
        source_attribution="MPKV Rahuri Organic Farming Project & NABARD Smallholder Unit Norms",
        minimum_viable_unit_description="One 12x4 ft HDPE bed with 2 kg Eisenia fetida earthworm culture",
        production_cycle_days=60,
        revenue_delay_months=2
    ),

    # -------------------------------------------------------------------------
    # CATEGORY C: Low-to-Moderate-Investment Enterprises
    # -------------------------------------------------------------------------
    OpportunityCatalogItem(
        opportunity_id="OPP_SMALL_GOAT_2_PLUS_1",
        title="Small Homestead Osmanabadi Goat Unit (2 Does + 1 Buck)",
        category="moderate_enterprise",
        is_cost_saving=False,
        tagline="Affordable entry-level goat rearing scaled specifically for smallholders",
        min_investment_inr=18000.0,
        max_investment_inr=26000.0,
        working_capital_required_inr=3000.0,
        required_land_acres=0.05,
        required_space_type="shed",
        water_requirement="low",
        daily_labor_hours=1.0,
        risk_level="low",
        payback_period_months=10,
        potential_annual_profit_inr=24000.0,
        potential_annual_savings_inr=0.0,
        summary="A compact 2 Does + 1 Buck unit of hardy, drought-tolerant Osmanabadi breed. Feeds primarily on farm crop residues and tree loppings with minimal concentrate, providing manageable, low-risk supplementary income.",
        market_commodity="Live Meat Goats",
        market_benchmark_price="₹340 - ₹380 / kg live weight",
        market_source="Agmarknet Baramati, Solapur & Sangli Weekly Livestock Mandis",
        market_verified=True,
        target_crops=["jowar", "soybean", "cotton", "maize", "all"],
        key_assumptions=[
            "2 Does produce 4-5 kids annually (high twinning frequency)",
            "Kids reared to 20-25 kg live weight at 7-8 months",
            "Uses existing shaded lean-to shed or thatched shelter"
        ],
        key_risks=[
            "Kid diarrhea or pneumonia during cold or damp spells",
            "Delayed vaccinations leading to Enterotoxemia (ET)"
        ],
        source_attribution="NABARD Smallholder Goat Model Maharashtra & ICAR-CIRG Makhdoom Field Norms",
        minimum_viable_unit_description="2 breeding Does + 1 Buck with simple bamboo/thatched enclosure",
        production_cycle_days=240,
        revenue_delay_months=8
    ),
    OpportunityCatalogItem(
        opportunity_id="OPP_OSMANABADI_GOAT_10_PLUS_1",
        title="Commercial Osmanabadi Goat Rearing Unit (10+1)",
        category="moderate_enterprise",
        is_cost_saving=False,
        tagline="Standard commercial herd unit requiring dedicated capital and shelter",
        min_investment_inr=75000.0,
        max_investment_inr=120000.0,
        working_capital_required_inr=12000.0,
        required_land_acres=0.15,
        required_space_type="shed",
        water_requirement="low",
        daily_labor_hours=2.5,
        risk_level="moderate",
        payback_period_months=14,
        potential_annual_profit_inr=95000.0,
        potential_annual_savings_inr=0.0,
        summary="A commercial 10 Does + 1 Buck unit of Osmanabadi goats. Requires dedicated semi-intensive shed space, reliable green fodder arrangements, and disciplined vaccination schedules. Suitable only when capital and shed are confirmed.",
        market_commodity="Live Meat Goats",
        market_benchmark_price="₹330 - ₹370 / kg live weight",
        market_source="Agmarknet Solapur & Baramati Livestock Mandis",
        market_verified=True,
        target_crops=["jowar", "maize", "soybean", "all"],
        key_assumptions=[
            "10 Does produce 18-20 marketable kids annually",
            "Kidding interval: 8 months (3 kiddings in 2 years)",
            "Concentrate feeding during pregnancy and lactation"
        ],
        key_risks=[
            "High capital lock-in: first batch sales occur only after month 8",
            "PPR and Enterotoxemia outbreaks if biosecurity is breached"
        ],
        source_attribution="NABARD Maharashtra State Focus Paper FY26-27 (Animal Husbandry Chapter 4.1)",
        minimum_viable_unit_description="10 Does + 1 Buck with semi-intensive shed and paddock",
        production_cycle_days=240,
        revenue_delay_months=8
    ),
    OpportunityCatalogItem(
        opportunity_id="OPP_OYSTER_MUSHROOM_01",
        title="Oyster Mushroom Batch Cultivation in Shaded Room",
        category="moderate_enterprise",
        is_cost_saving=False,
        tagline="High-protein white oyster mushroom production on chopped soybean/paddy straw",
        min_investment_inr=18000.0,
        max_investment_inr=32000.0,
        working_capital_required_inr=4500.0,
        required_land_acres=0.01,
        required_space_type="room",
        water_requirement="low",
        daily_labor_hours=1.5,
        risk_level="moderate",
        payback_period_months=6,
        potential_annual_profit_inr=65000.0,
        potential_annual_savings_inr=0.0,
        summary="Cultivates Pleurotus sajor-caju (Oyster Mushroom) in polypropylene bags using pasteurized soybean/paddy straw. Requires a darkened, clean, ventilated room (10x12 ft) with 80-85% relative humidity maintained via light water misting.",
        market_commodity="Fresh Oyster Mushrooms",
        market_benchmark_price="₹140 - ₹200 / kg at local restaurants, grocery stores & weekly markets",
        market_source="Local Semi-Urban Food Markets (Pune, Nashik, Kolhapur)",
        market_verified=True,
        target_crops=["soybean", "rice", "wheat", "all"],
        key_assumptions=[
            "Batch size: 100 substrate bags yielding ~1.2 kg fresh mushrooms per bag over 3 flushes",
            "Production cycle: 45 days per batch (6 batches per year)",
            "Clean room with spray bottle/humidifier and temperature 22-28°C"
        ],
        key_risks=[
            "Green mold (Trichoderma) contamination if straw sterilization is incomplete",
            "Short shelf life (24-36 hrs fresh) requiring immediate local retail outlets"
        ],
        source_attribution="Directorate of Mushroom Research (ICAR-DMR) Chambaghat & MPKV Rahuri Technology Package",
        minimum_viable_unit_description="100 polypropylene straw bags in a clean, ventilated 10x12 ft domestic room",
        production_cycle_days=45,
        revenue_delay_months=2
    ),
    OpportunityCatalogItem(
        opportunity_id="OPP_BEEKEEPING_5_BOX",
        title="Smallholder Apiculture Unit (5 Indian Honeybee Boxes)",
        category="moderate_enterprise",
        is_cost_saving=False,
        tagline="Honey and wax harvesting with significant cross-pollination yield boost for crops",
        min_investment_inr=22000.0,
        max_investment_inr=35000.0,
        working_capital_required_inr=2500.0,
        required_land_acres=0.02,
        required_space_type="yard",
        water_requirement="very_low",
        daily_labor_hours=0.5,
        risk_level="moderate",
        payback_period_months=9,
        potential_annual_profit_inr=38000.0,
        potential_annual_savings_inr=0.0,
        summary="Maintains 5 ISI standard bee boxes of Apis cerana indica on shaded farm edges. Produces 40-50 kg raw honey annually while enhancing oilseed and pulse crop pollination by 15-20%.",
        market_commodity="Raw Unprocessed Honey & Beeswax",
        market_benchmark_price="₹400 - ₹550 / kg direct bottled honey",
        market_source="Khadi and Village Industries Commission (KVIC) Mahabaleshwar / Direct Farm-Gate",
        market_verified=True,
        target_crops=["soybean", "mustard", "sunflower", "pigeonpea", "horticulture", "all"],
        key_assumptions=[
            "5 active bee colonies with queens during blooming season",
            "Adequate flora (pollen/nectar forage) within 1.5 km radius",
            "Average 8-10 kg honey harvest per colony annually"
        ],
        key_risks=[
            "Colony desertion (absconding) if pesticide drift occurs from neighboring fields",
            "Wax moth infestation during monsoon dearth period"
        ],
        source_attribution="National Bee Board (NBB) Mission for Integrated Development of Horticulture & KVIC Standards",
        minimum_viable_unit_description="5 Apis cerana bee boxes with stands and protective veil/smoker",
        production_cycle_days=120,
        revenue_delay_months=4
    ),
    OpportunityCatalogItem(
        opportunity_id="OPP_DESI_POULTRY_100",
        title="Backyard Indigenous Desi Poultry (100 Birds - Kaveri/Satpuda)",
        category="moderate_enterprise",
        is_cost_saving=False,
        tagline="Dual-purpose brown egg and country chicken meat unit utilizing kitchen and farm scraps",
        min_investment_inr=28000.0,
        max_investment_inr=48000.0,
        working_capital_required_inr=6000.0,
        required_land_acres=0.05,
        required_space_type="shed",
        water_requirement="low",
        daily_labor_hours=1.5,
        risk_level="moderate",
        payback_period_months=8,
        potential_annual_profit_inr=45000.0,
        potential_annual_savings_inr=0.0,
        summary="Free-range backyard system with 100 disease-hardened indigenous birds (Kaveri or Satpuda crosses). Forages on weeds, insects, and spilled grains with supplemental broken pulses, selling premium brown eggs and meat.",
        market_commodity="Free-Range Desi Eggs & Country Chicken Meat",
        market_benchmark_price="₹10 - ₹12 per brown egg; ₹260 - ₹300 / kg live bird",
        market_source="Local Village Roadside Bazaars & Dhabas",
        market_verified=True,
        target_crops=["all"],
        key_assumptions=[
            "100 birds producing ~12,000 eggs annually with ~70 mature cocks marketed",
            "Night shelter: simple wire-mesh predator-proof shed (100 sq ft)",
            "Feed cost reduced 40% via daytime scavenging and farm green waste"
        ],
        key_risks=[
            "Predation by stray dogs, cats, or mongoose without secure night fencing",
            "Ranikhet (Newcastle) disease if Lasota/R2B vaccines are missed"
        ],
        source_attribution="ICAR Directorate of Poultry Research (DPR) Hyderabad & NABARD Backyard Poultry Guidelines",
        minimum_viable_unit_description="Night shelter shed (100 sq ft) with 100 night-secure free-range birds",
        production_cycle_days=180,
        revenue_delay_months=5
    ),

    # -------------------------------------------------------------------------
    # CATEGORY D: Alternative / Secondary Crop Cultivation
    # -------------------------------------------------------------------------
    OpportunityCatalogItem(
        opportunity_id="OPP_SUNFLOWER_INTERCROP_01",
        title="Sequential / Intercrop Sunflower Cultivation (KBSH-53 / Phule Raviraj)",
        category="crop_diversification",
        is_cost_saving=False,
        tagline="Drought-tolerant short-duration oilseed with high industrial crushing demand",
        min_investment_inr=8500.0,
        max_investment_inr=14000.0,
        working_capital_required_inr=3000.0,
        required_land_acres=0.5,
        required_space_type="field",
        water_requirement="low",
        daily_labor_hours=1.0,
        risk_level="moderate",
        payback_period_months=5,
        potential_annual_profit_inr=28000.0,
        potential_annual_savings_inr=0.0,
        summary="Cultivates 0.5 acre of hybrid sunflower as an intercrop or late-rabi sequential crop. Yields 5-7 quintals of oilseed under 2 protective irrigations, providing diversified cash revenue against mono-crop failure.",
        market_commodity="Sunflower Seed (40% Oil Content)",
        market_benchmark_price="₹5,800 - ₹6,400 / quintal at regional APMC",
        market_source="Agmarknet Solapur & Latur APMC Oilseeds Division",
        market_verified=True,
        target_crops=["soybean", "cotton", "fallow", "all"],
        key_assumptions=[
            "Grown on fallow or as sequential crop after short kharif pulse",
            "Yield: 5.5 quintals on 0.5 acre with balanced NPK and boron spray",
            "Opportunity cost: assumes land is unallocated or low-yielding stubble"
        ],
        key_risks=[
            "Parrot and bird damage during seed filling (anthesis to harvest)",
            "Poor seed setting without honeybee pollinators during flowering"
        ],
        source_attribution="ICAR-Indian Institute of Oilseeds Research (IIOR) Hyderabad & MPKV Rahuri Agronomy Guide",
        minimum_viable_unit_description="0.5 acre cultivation with 2.5 kg certified hybrid seed",
        production_cycle_days=95,
        revenue_delay_months=4
    ),

    # -------------------------------------------------------------------------
    # CATEGORY E: External / Group-Based Opportunities
    # -------------------------------------------------------------------------
    OpportunityCatalogItem(
        opportunity_id="OPP_FPO_COLLECTIVE_INPUT_01",
        title="FPO Collective Input Procurement & Bulk Purchasing Aggregation",
        category="group_external",
        is_cost_saving=True,
        tagline="Save 10-15% on wholesale seeds, bio-fertilizers, and pesticides through FPO pooling",
        min_investment_inr=500.0,
        max_investment_inr=2000.0,
        working_capital_required_inr=0.0,
        required_land_acres=0.0,
        required_space_type="none",
        water_requirement="none",
        daily_labor_hours=0.25,
        risk_level="low",
        payback_period_months=1,
        potential_annual_profit_inr=0.0,
        potential_annual_savings_inr=12000.0,
        summary="Combines seasonal seed and agro-chemical requirements with village Farmer Producer Company (FPC) bulk orders. Secures wholesale distributor pricing directly from manufacturers, eliminating retail markup.",
        market_commodity="Agricultural Input Cost Reduction",
        market_benchmark_price="12-16% savings on certified seeds, neem oil, and water-soluble fertilizers",
        market_source="MahaFPC / District FPO Federation Procurement Invoices",
        market_verified=True,
        target_crops=["all"],
        key_assumptions=[
            "Farmer is a registered shareholder or member of village FPO",
            "Orders booked 30 days prior to kharif/rabi sowing window",
            "Direct pickup at primary village aggregation point"
        ],
        key_risks=[
            "Logistical delays in delivery if bulk transport is stalled",
            "Specific desired proprietary brand may differ from FPO bulk tender"
        ],
        source_attribution="SFAC (Small Farmers Agribusiness Consortium) & NABARD FPO Operational Guidelines",
        minimum_viable_unit_description="Membership equity share (₹500-1000) and collective order booking",
        production_cycle_days=30,
        revenue_delay_months=1
    )
]

def get_income_catalog() -> List[OpportunityCatalogItem]:
    return list(EXTENDED_OPPORTUNITY_CATALOG)

def get_catalog_by_category(category: str) -> List[OpportunityCatalogItem]:
    if category == "all":
        return list(EXTENDED_OPPORTUNITY_CATALOG)
    return [o for o in EXTENDED_OPPORTUNITY_CATALOG if o.category == category]

def get_opportunity_by_id(opportunity_id: str) -> Optional[OpportunityCatalogItem]:
    return next((o for o in EXTENDED_OPPORTUNITY_CATALOG if o.opportunity_id == opportunity_id), None)
