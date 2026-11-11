"""
Non-destructive schema reconciliation and reference-data initializer for the
integrated Rashkar tables inside CropNet.

Inspects existing database columns before altering or seeding so pre-existing
records in `cropnet_dev.db` are preserved intact.
"""
import logging
from sqlalchemy import inspect, text
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session

from cropnet.services.api.app.models.soil_and_farm import Base
from cropnet.services.api.app.models.rashkar_profiles import (
    CanonicalCropMasterModel,
    CropStageReferenceModel,
    AgronomicThresholdRegistryModel,
    AgronomicAdvisoryCatalogueModel,
    IncomeOpportunityModel,
)

logger = logging.getLogger(__name__)

_ADDITIVE_COLUMNS = {
    "farmers": [
        ("age_range", "VARCHAR(30)"),
        ("work_preference", "VARCHAR(40)"),
        ("payback_horizon", "VARCHAR(40)"),
        ("family_management_role", "VARCHAR(40)"),
        ("default_workload_category", "VARCHAR(30)"),
        ("default_clothing_type", "VARCHAR(40)"),
        ("default_is_acclimatised", "BOOLEAN"),
        ("default_sun_exposure", "VARCHAR(30)"),
        ("default_exposure_duration_hours", "FLOAT"),
    ],
    "farmer_resource_profiles": [
        ("age_range", "VARCHAR(30)"),
        ("work_preference", "VARCHAR(40)"),
        ("payback_horizon", "VARCHAR(40)"),
        ("family_management_role", "VARCHAR(40)"),
        ("current_crop_code", "VARCHAR(50)"),
        ("current_crop_stage", "VARCHAR(50)"),
        ("profile_completed", "BOOLEAN DEFAULT 0"),
    ],
    "income_scenarios": [
        ("monthly_cash_flows", "JSON"),
    ],
}


def ensure_rashkar_columns(bind_engine: Engine) -> None:
    """Safely add genuinely missing additive columns on existing tables."""
    inspector = inspect(bind_engine)
    existing_tables = set(inspector.get_table_names())
    with bind_engine.begin() as conn:
        for table_name, cols in _ADDITIVE_COLUMNS.items():
            if table_name not in existing_tables:
                continue
            existing_cols = {c["name"] for c in inspector.get_columns(table_name)}
            for col_name, col_type in cols:
                if col_name not in existing_cols:
                    conn.execute(text(f"ALTER TABLE {table_name} ADD COLUMN {col_name} {col_type}"))


def seed_rashkar_reference_data(db: Session) -> None:
    """Populate canonical crop/stage/threshold/opportunity reference tables only when empty."""
    if db.query(CanonicalCropMasterModel).count() == 0:
        from cropnet.services.api.app.services.rashkar.crop_heat_engine import CROP_SPECIES_PHYSIOLOGY
        master_meta = {
            "soybean": ("Soybean", "सोयाबीन", "Glycine max", "oilseed", "kharif", True, "rule_and_baseline_supported"),
            "cotton": ("Cotton", "कापूस", "Gossypium hirsutum", "fibre", "kharif", True, "rule_and_baseline_supported"),
            "jowar": ("Jowar / Sorghum", "ज्वारी", "Sorghum bicolor", "cereal", "kharif", True, "rule_and_baseline_supported"),
            "sugarcane": ("Sugarcane", "ऊस", "Saccharum officinarum", "commercial", "perennial", True, "rule_and_baseline_supported"),
            "onion": ("Onion", "कांदा", "Allium cepa", "vegetable", "rabi", False, "advisory_only"),
            "wheat": ("Wheat", "गहू", "Triticum aestivum", "cereal", "rabi", False, "advisory_only"),
            "gram": ("Gram / Chickpea", "हरभरा", "Cicer arietinum", "pulse", "rabi", False, "advisory_only"),
            "tur": ("Tur / Pigeon Pea", "तूर / अरहर", "Cajanus cajan", "pulse", "kharif", False, "advisory_only"),
            "bajra": ("Bajra / Pearl Millet", "बाजरी", "Pennisetum glaucum", "millet", "kharif", False, "advisory_only"),
            "maize": ("Maize", "मका", "Zea mays", "cereal", "kharif", False, "advisory_only"),
            "groundnut": ("Groundnut", "भुईमूग", "Arachis hypogaea", "oilseed", "kharif", False, "advisory_only"),
        }
        for code in CROP_SPECIES_PHYSIOLOGY:
            en, mr, bot, cat, season, pilot, lvl = master_meta[code]
            db.add(CanonicalCropMasterModel(
                crop_code=code,
                common_name_en=en,
                common_name_mr=mr,
                botanical_name=bot,
                crop_category=cat,
                standard_season=season,
                is_pioneer_pilot_crop=pilot,
                support_level=lvl,
                apy_alias_list=[en],
            ))
        db.commit()

    if db.query(CropStageReferenceModel).count() == 0:
        stages = [
            CropStageReferenceModel(stage_id="SOY_VEG", crop_code="soybean", stage_code="VEGETATIVE", stage_name_en="Vegetative Growth", stage_name_mr="शाकीय वाढीची अवस्था", sequence_order=1, typical_duration_days=30, das_start_typical=0, das_end_typical=30, heat_sensitivity="low", drought_sensitivity="medium", excess_water_sensitivity="high", source_citation="ICAR-IISR Technical Bulletin 44"),
            CropStageReferenceModel(stage_id="SOY_FLOWER", crop_code="soybean", stage_code="R1_FLOWERING", stage_name_en="Flowering", stage_name_mr="फुलोरा अवस्था", sequence_order=2, typical_duration_days=20, das_start_typical=31, das_end_typical=50, heat_sensitivity="critical", drought_sensitivity="critical", excess_water_sensitivity="medium", source_citation="ICAR-IISR Technical Bulletin 44"),
            CropStageReferenceModel(stage_id="SOY_POD_FILL", crop_code="soybean", stage_code="R3_POD_FILLING", stage_name_en="Pod Formation & Seed Filling", stage_name_mr="शेंगा भरणे व दाणे भरणे", sequence_order=3, typical_duration_days=35, das_start_typical=51, das_end_typical=85, heat_sensitivity="high", drought_sensitivity="critical", excess_water_sensitivity="low", source_citation="ICAR-IISR Technical Bulletin 44"),
            CropStageReferenceModel(stage_id="SOY_MATURITY", crop_code="soybean", stage_code="R7_MATURITY", stage_name_en="Maturity & Harvest", stage_name_mr="पक्वता व काढणी", sequence_order=4, typical_duration_days=15, das_start_typical=86, das_end_typical=105, heat_sensitivity="low", drought_sensitivity="low", excess_water_sensitivity="high", source_citation="ICAR-IISR Technical Bulletin 44"),
            CropStageReferenceModel(stage_id="COT_VEG", crop_code="cotton", stage_code="VEGETATIVE", stage_name_en="Vegetative Growth & Square Formation", stage_name_mr="शाकीय वाढ व पाते लागणे", sequence_order=1, typical_duration_days=50, das_start_typical=0, das_end_typical=50, heat_sensitivity="medium", drought_sensitivity="medium", excess_water_sensitivity="high", source_citation="ICAR-CICR Cotton Production Manual 2023"),
            CropStageReferenceModel(stage_id="COT_FLOWER", crop_code="cotton", stage_code="FLOWERING_BOLL_DEV", stage_name_en="Peak Flowering & Boll Development", stage_name_mr="फुलोरा व बोंड लागणे", sequence_order=2, typical_duration_days=60, das_start_typical=51, das_end_typical=110, heat_sensitivity="critical", drought_sensitivity="critical", excess_water_sensitivity="high", source_citation="ICAR-CICR Cotton Production Manual 2023"),
        ]
        db.add_all(stages)
        db.commit()

    if db.query(AgronomicThresholdRegistryModel).count() == 0:
        thresholds = [
            AgronomicThresholdRegistryModel(threshold_id="THRESH_COT_HEAT_FLOWER", crop_code="cotton", applicable_variety="all", agro_ecological_zone="Maharashtra Statewide", growth_stage="FLOWERING_BOLL_DEV", environmental_variable="tmax_c", unit="celsius", critical_threshold=38.0, required_exposure_duration_hours=3, comparison_operator=">=", physiological_impact="Pollen desiccation and square/young boll shedding", source_institution="ICAR-Central Institute for Cotton Research (CICR) Nagpur", publication_citation="CICR Annual Scientific Report 2023, p. 58", publication_year=2023, evidence_grade="peer_reviewed_experimental", verification_status="verified_by_agronomist"),
            AgronomicThresholdRegistryModel(threshold_id="THRESH_COT_WARM_NIGHT", crop_code="cotton", applicable_variety="all", agro_ecological_zone="Maharashtra Statewide", growth_stage="FLOWERING_BOLL_DEV", environmental_variable="tmin_c", unit="celsius", critical_threshold=24.0, required_exposure_duration_hours=6, comparison_operator=">=", physiological_impact="Elevated dark respiration consuming plant carbohydrates and inducing square abortion", source_institution="ICAR-CICR Nagpur", publication_citation="CICR Technical Bulletin 2022", publication_year=2022, evidence_grade="extension_publication", verification_status="verified_by_agronomist"),
            AgronomicThresholdRegistryModel(threshold_id="THRESH_SOY_HEAT_POD", crop_code="soybean", applicable_variety="all", agro_ecological_zone="Maharashtra Statewide", growth_stage="R3_POD_FILLING", environmental_variable="tmax_c", unit="celsius", critical_threshold=35.0, required_exposure_duration_hours=4, comparison_operator=">=", physiological_impact="Accelerated senescence, reduced seed weight and shrivelled grain", source_institution="ICAR-Indian Institute of Soybean Research (IISR) Indore", publication_citation="IISR Research Bulletin 52, 2021", publication_year=2021, evidence_grade="peer_reviewed_experimental", verification_status="verified_by_agronomist"),
            AgronomicThresholdRegistryModel(threshold_id="THRESH_VERTISOL_PH_HIGH", crop_code="soybean", applicable_variety="all", agro_ecological_zone="Maharashtra Vertisols (Black Cotton Soils)", growth_stage="all", environmental_variable="ph", unit="pH_scale", critical_threshold=8.5, required_exposure_duration_hours=0, comparison_operator=">=", physiological_impact="Severe lime-induced iron (Fe) and zinc (Zn) deficiency, chlorosis", source_institution="Mahatma Phule Krishi Vidyapeeth (MPKV) Rahuri", publication_citation="MPKV Soil Science Advisory Manual 2020", publication_year=2020, evidence_grade="university_package_of_practices", verification_status="verified_by_agronomist"),
        ]
        db.add_all(thresholds)
        db.commit()

    if db.query(AgronomicAdvisoryCatalogueModel).count() == 0:
        advisories = [
            AgronomicAdvisoryCatalogueModel(action_id="ADV_SOY_DRY_01", crop_code="soybean", risk_dimension="dry_spell", title_en="Protective Supplemental Irrigation for Soybean", title_mr="सोयाबीन पिकास संरक्षित पाणी देणे", description_en="Apply light protective irrigation (25-30 mm) via sprinkler or drip during critical flowering/pod development to prevent flower drop.", description_mr="फुलोरा व शेंगा भरण्याच्या अवस्थेत पावसाचा १० दिवसांपेक्षा जास्त खंड पडल्यास तुषार किंवा ठिबक सिंचनाने एक संरक्षित पाणी द्यावे.", evidence_citation="MPKV Rahuri Soybean Package of Practices 2023, p. 14"),
            AgronomicAdvisoryCatalogueModel(action_id="ADV_COT_HEAT_01", crop_code="cotton", risk_dimension="crop_heat", title_en="Foliar 2% Potassium Nitrate Spray Alleviation", title_mr="२% पोटॅशियम नायट्रेट (१३:०:४५) फवारणी", description_en="Spray 2% KNO3 (20 g/L water) in late evening to improve stomatal regulation, reduce canopy temperature, and reduce square dropping.", description_mr="उष्णतेमुळे होणारी पातेगळ व फुलगळ रोखण्यासाठी संध्याकाळी २% १३:०:४५ (२० ग्रॅम प्रति लिटर पाणी) ची फवारणी करावी.", evidence_citation="ICAR-CICR Cotton Advisory 2023"),
        ]
        db.add_all(advisories)
        db.commit()

    if db.query(IncomeOpportunityModel).count() == 0:
        from cropnet.services.api.app.services.rashkar.income_knowledge_catalog import EXTENDED_OPPORTUNITY_CATALOG
        for item in EXTENDED_OPPORTUNITY_CATALOG:
            db.add(IncomeOpportunityModel(
                opportunity_id=item.opportunity_id,
                title=item.title,
                category=item.category,
                is_cost_saving=item.is_cost_saving,
                tagline=item.tagline,
                target_crops=item.target_crops,
                required_resources=[],
                min_investment_inr=item.min_investment_inr,
                max_investment_inr=item.max_investment_inr,
                working_capital_required_inr=item.working_capital_required_inr,
                payback_period_months=item.payback_period_months,
                potential_annual_profit_inr=item.potential_annual_profit_inr,
                potential_annual_savings_inr=item.potential_annual_savings_inr,
                risk_level=item.risk_level,
                summary=item.summary,
                market_commodity=item.market_commodity,
                market_benchmark_price=item.market_benchmark_price,
                market_source=item.market_source,
                key_assumptions=item.key_assumptions,
                key_risks=item.key_risks,
                source_attribution=item.source_attribution,
            ))
        db.commit()


def ensure_rashkar_schema_and_seed(bind_engine: Engine, session_factory) -> None:
    """Create missing Rashkar tables, add missing additive columns, and seed reference data."""
    import cropnet.services.api.app.models.rashkar_profiles  # noqa: F401
    Base.metadata.create_all(bind=bind_engine, checkfirst=True)
    ensure_rashkar_columns(bind_engine)
    db = session_factory()
    try:
        seed_rashkar_reference_data(db)
    finally:
        db.close()
