"""Add missing soil_test_reports columns to match SoilTestReportModel.

Revision ID: 010_soil_test_reports_missing_cols
Revises: 009_government_schemes
Create Date: 2026-11-15
"""
from alembic import op
import sqlalchemy as sa

revision = "010_soil_test_reports_missing_cols"
down_revision = "009_government_schemes"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    existing = {col["name"] for col in inspector.get_columns("soil_test_reports")}

    if "lab_number" not in existing:
        op.add_column("soil_test_reports", sa.Column("lab_number", sa.String(length=100), nullable=True))
    if "date_received" not in existing:
        op.add_column("soil_test_reports", sa.Column("date_received", sa.DateTime(), nullable=True))
    if "date_processed" not in existing:
        op.add_column("soil_test_reports", sa.Column("date_processed", sa.DateTime(), nullable=True))
    if "depth_provenance" not in existing:
        op.add_column(
            "soil_test_reports",
            sa.Column("depth_provenance", sa.String(length=50), nullable=True, server_default="UNKNOWN"),
        )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    existing = {col["name"] for col in inspector.get_columns("soil_test_reports")}

    for col_name in ("depth_provenance", "date_processed", "date_received", "lab_number"):
        if col_name in existing:
            op.drop_column("soil_test_reports", col_name)
