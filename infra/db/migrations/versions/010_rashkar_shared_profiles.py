"""Rashkar shared profiles, plot/crop cycles, risk audit logs, and extra income tables.

Revision ID: 010_rashkar_shared_profiles
Revises: 009_government_schemes
Create Date: 2026-11-10 16:15:00.000000

Non-destructively creates missing tables and adds shared farmer/worker/resource
columns to existing tables (`farmers`, `farmer_resource_profiles`, `income_scenarios`).
Preserves all existing `farms` and historical records in `cropnet_dev.db`.
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


revision: str = "010_rashkar_shared_profiles"
down_revision: Union[str, None] = "009_government_schemes"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _ensure_column(inspector, table_name: str, col: sa.Column) -> None:
    existing = {c["name"] for c in inspector.get_columns(table_name)}
    if col.name not in existing:
        op.add_column(table_name, col)


def upgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    existing_tables = set(inspector.get_table_names())

    if "farmers" not in existing_tables:
        op.create_table(
            "farmers",
            sa.Column("farmer_id", sa.String(50), primary_key=True),
            sa.Column("full_name", sa.String(100), nullable=False),
            sa.Column("phone_number", sa.String(20), nullable=True),
            sa.Column("state", sa.String(50), nullable=True),
            sa.Column("district", sa.String(50), nullable=False),
            sa.Column("taluka", sa.String(50), nullable=False),
            sa.Column("village", sa.String(100), nullable=True),
            sa.Column("preferred_language", sa.String(10), nullable=True),
            sa.Column("age_range", sa.String(30), nullable=True),
            sa.Column("work_preference", sa.String(40), nullable=True),
            sa.Column("payback_horizon", sa.String(40), nullable=True),
            sa.Column("family_management_role", sa.String(40), nullable=True),
            sa.Column("default_workload_category", sa.String(30), nullable=True),
            sa.Column("default_clothing_type", sa.String(40), nullable=True),
            sa.Column("default_is_acclimatised", sa.Boolean(), nullable=True),
            sa.Column("default_sun_exposure", sa.String(30), nullable=True),
            sa.Column("default_exposure_duration_hours", sa.Float(), nullable=True),
            sa.Column("created_at", sa.DateTime(), nullable=True),
            sa.Column("updated_at", sa.DateTime(), nullable=True),
        )
    else:
        for col in [
            sa.Column("age_range", sa.String(30), nullable=True),
            sa.Column("work_preference", sa.String(40), nullable=True),
            sa.Column("payback_horizon", sa.String(40), nullable=True),
            sa.Column("family_management_role", sa.String(40), nullable=True),
            sa.Column("default_workload_category", sa.String(30), nullable=True),
            sa.Column("default_clothing_type", sa.String(40), nullable=True),
            sa.Column("default_is_acclimatised", sa.Boolean(), nullable=True),
            sa.Column("default_sun_exposure", sa.String(30), nullable=True),
            sa.Column("default_exposure_duration_hours", sa.Float(), nullable=True),
        ]:
            _ensure_column(inspector, "farmers", col)

    if "farmer_user_accounts" not in existing_tables:
        op.create_table(
            "farmer_user_accounts",
            sa.Column("id", sa.String(36), primary_key=True),
            sa.Column("auth_provider", sa.String(50), nullable=False),
            sa.Column("auth_user_id", sa.String(50), nullable=False),
            sa.Column("farmer_id", sa.String(50), sa.ForeignKey("farmers.farmer_id", ondelete="CASCADE"), nullable=False),
            sa.Column("created_at", sa.DateTime(), nullable=True),
            sa.Column("verified_at", sa.DateTime(), nullable=True),
        )

    if "farm_plots" not in existing_tables:
        op.create_table(
            "farm_plots",
            sa.Column("plot_id", sa.String(50), primary_key=True),
            sa.Column("farm_id", sa.String(50), sa.ForeignKey("farms.id"), nullable=False),
            sa.Column("plot_name", sa.String(100), nullable=False),
            sa.Column("area_acres", sa.Float(), nullable=False),
            sa.Column("polygon_geojson", sa.JSON(), nullable=True),
            sa.Column("irrigation_type", sa.String(50), nullable=True),
            sa.Column("created_at", sa.DateTime(), nullable=True),
        )

    if "crop_cycles" not in existing_tables:
        op.create_table(
            "crop_cycles",
            sa.Column("cycle_id", sa.String(50), primary_key=True),
            sa.Column("plot_id", sa.String(50), sa.ForeignKey("farm_plots.plot_id"), nullable=False),
            sa.Column("crop_code", sa.String(50), nullable=False),
            sa.Column("variety_name", sa.String(100), nullable=True),
            sa.Column("season", sa.String(20), nullable=False),
            sa.Column("sowing_date", sa.Date(), nullable=False),
            sa.Column("harvest_date_actual", sa.Date(), nullable=True),
            sa.Column("planted_area_acres", sa.Float(), nullable=True),
            sa.Column("current_stage_code", sa.String(50), nullable=True),
            sa.Column("stage_updated_at", sa.DateTime(), nullable=True),
            sa.Column("is_active", sa.Boolean(), nullable=True),
            sa.Column("created_at", sa.DateTime(), nullable=True),
        )

    if "farmer_resource_profiles" not in existing_tables:
        op.create_table(
            "farmer_resource_profiles",
            sa.Column("farm_id", sa.String(50), primary_key=True),
            sa.Column("farmer_id", sa.String(50), nullable=False),
            sa.Column("available_investment_inr", sa.Float(), nullable=True),
            sa.Column("monthly_operating_budget_inr", sa.Float(), nullable=True),
            sa.Column("max_risk_capital_inr", sa.Float(), nullable=True),
            sa.Column("willing_to_borrow", sa.Boolean(), nullable=True),
            sa.Column("total_farm_acres", sa.Float(), nullable=True),
            sa.Column("cultivated_acres", sa.Float(), nullable=True),
            sa.Column("available_land_acres", sa.Float(), nullable=True),
            sa.Column("unused_land_acres", sa.Float(), nullable=True),
            sa.Column("field_bunds_available", sa.Boolean(), nullable=True),
            sa.Column("has_animal_shed", sa.Boolean(), nullable=True),
            sa.Column("has_storage_room", sa.Boolean(), nullable=True),
            sa.Column("has_shaded_space", sa.Boolean(), nullable=True),
            sa.Column("water_availability", sa.String(50), nullable=True),
            sa.Column("water_months_available", sa.JSON(), nullable=True),
            sa.Column("family_labor_hours_day", sa.Float(), nullable=True),
            sa.Column("hired_labor_possible", sa.Boolean(), nullable=True),
            sa.Column("existing_livestock", sa.String(50), nullable=True),
            sa.Column("existing_assets", sa.JSON(), nullable=True),
            sa.Column("crop_byproducts", sa.JSON(), nullable=True),
            sa.Column("byproduct_surplus_available", sa.Boolean(), nullable=True),
            sa.Column("interests", sa.JSON(), nullable=True),
            sa.Column("has_transport", sa.Boolean(), nullable=True),
            sa.Column("has_fpo_access", sa.Boolean(), nullable=True),
            sa.Column("distance_to_apmc_km", sa.Float(), nullable=True),
            sa.Column("risk_tolerance", sa.String(20), nullable=True),
            sa.Column("category_preference", sa.String(50), nullable=True),
            sa.Column("age_range", sa.String(30), nullable=True),
            sa.Column("work_preference", sa.String(40), nullable=True),
            sa.Column("payback_horizon", sa.String(40), nullable=True),
            sa.Column("family_management_role", sa.String(40), nullable=True),
            sa.Column("current_crop_code", sa.String(50), nullable=True),
            sa.Column("current_crop_stage", sa.String(50), nullable=True),
            sa.Column("profile_completed", sa.Boolean(), nullable=True),
            sa.Column("updated_at_utc", sa.DateTime(), nullable=True),
        )
    else:
        for col in [
            sa.Column("age_range", sa.String(30), nullable=True),
            sa.Column("work_preference", sa.String(40), nullable=True),
            sa.Column("payback_horizon", sa.String(40), nullable=True),
            sa.Column("family_management_role", sa.String(40), nullable=True),
            sa.Column("current_crop_code", sa.String(50), nullable=True),
            sa.Column("current_crop_stage", sa.String(50), nullable=True),
            sa.Column("profile_completed", sa.Boolean(), nullable=True),
        ]:
            _ensure_column(inspector, "farmer_resource_profiles", col)

    if "income_scenarios" in existing_tables:
        _ensure_column(inspector, "income_scenarios", sa.Column("monthly_cash_flows", sa.JSON(), nullable=True))

    if "saved_income_plans" not in existing_tables:
        op.create_table(
            "saved_income_plans",
            sa.Column("plan_id", sa.String(50), primary_key=True),
            sa.Column("farmer_id", sa.String(50), nullable=False),
            sa.Column("farm_id", sa.String(50), nullable=False),
            sa.Column("opportunity_id", sa.String(50), nullable=False),
            sa.Column("opportunity_title", sa.String(150), nullable=False),
            sa.Column("category", sa.String(50), nullable=False),
            sa.Column("chosen_budget_inr", sa.Float(), nullable=False),
            sa.Column("projected_annual_profit_inr", sa.Float(), nullable=False),
            sa.Column("projected_annual_savings_inr", sa.Float(), nullable=True),
            sa.Column("payback_months", sa.Float(), nullable=True),
            sa.Column("break_even_reached", sa.Boolean(), nullable=True),
            sa.Column("notes", sa.Text(), nullable=True),
            sa.Column("created_at_utc", sa.DateTime(), nullable=True),
        )


def downgrade() -> None:
    pass
