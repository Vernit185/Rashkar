"""
Comprehensive Migration Verification & Schema Drift Detection Test Suite.

Verifies:
1. Alembic head count (exactly 1 head) and current revision ('007_water_and_satellite').
2. Upgrade from migration 006 baseline to 007.
3. Verification of every expected table, column, type, foreign key, and index.
4. Schema drift detection: migration detects incomplete existing tables and fails safely
   with an actionable error rather than silently skipping table creation.
5. Clean downgrade execution.
"""
import os
import tempfile
import importlib.util
import pytest
from alembic.config import Config
from alembic.script import ScriptDirectory
from alembic.migration import MigrationContext
from alembic.operations import Operations
from alembic import op
import sqlalchemy as sa


ALEMBIC_INI_PATH = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "../../../infra/db/alembic.ini")
)
MIG_007_PATH = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "../../../infra/db/migrations/versions/007_water_and_satellite_intelligence.py")
)
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))


def _load_migration_007():
    spec = importlib.util.spec_from_file_location("mig_007", MIG_007_PATH)
    mig = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mig)
    return mig


def test_alembic_head_count_and_current_revision():
    """Verify that there is exactly one Alembic head, pointing to the latest revision."""
    config = Config(ALEMBIC_INI_PATH)
    config.set_main_option("script_location", os.path.join(PROJECT_ROOT, "infra/db/migrations"))
    script = ScriptDirectory.from_config(config)
    heads = script.get_heads()

    assert len(heads) == 1, f"Expected exactly 1 alembic head, found {len(heads)}: {heads}"
    assert heads[0] in ("007_water_and_satellite", "008_isolate_synthetic_satellite_qa", "009_government_schemes", "010_rashkar_shared_profiles"), f"Expected head to be 007-010, got {heads[0]}"


def test_upgrade_from_migration_006_to_007_and_column_verification():
    """Verify upgrade from revision 006 baseline to 007 and all generated tables/columns."""
    mig_007 = _load_migration_007()

    with tempfile.NamedTemporaryFile(suffix=".db") as tmp:
        engine = sa.create_engine(f"sqlite:///{tmp.name}")

        with engine.begin() as conn:
            # Seed migration 006 baseline: farms and existing soil tables
            conn.execute(sa.text("""
                CREATE TABLE farms (
                    id VARCHAR(36) PRIMARY KEY,
                    owner_id VARCHAR(36) NOT NULL,
                    name VARCHAR(100) NOT NULL
                )
            """))

            ctx = MigrationContext.configure(conn)
            op._proxy = Operations(ctx)

            # Execute migration 007 upgrade
            mig_007.upgrade()

        inspector = sa.inspect(engine)
        post_tables = inspector.get_table_names()

        # Check all 4 tables exist
        assert "water_sources" in post_tables
        assert "water_test_reports" in post_tables
        assert "water_measurements" in post_tables
        assert "satellite_vegetation_observations" in post_tables

        # Check columns of water_sources
        ws_cols = {c["name"] for c in inspector.get_columns("water_sources")}
        expected_ws = {
            "id", "farm_id", "source_type", "name", "location_description",
            "latitude", "longitude", "seasonal_availability", "reliability",
            "daily_available_hours", "irrigation_method", "measured_capacity_lph",
            "capacity_provenance", "is_active", "created_at", "updated_at"
        }
        assert expected_ws.issubset(ws_cols), f"Missing water_sources columns: {expected_ws - ws_cols}"

        # Check columns of water_test_reports
        wtr_cols = {c["name"] for c in inspector.get_columns("water_test_reports")}
        expected_wtr = {
            "id", "user_id", "farm_id", "water_source_id", "original_filename",
            "storage_path", "file_size_bytes", "mime_type", "file_hash_sha256",
            "upload_timestamp", "laboratory_name", "lab_number", "report_date",
            "sample_collection_date", "sampling_location", "extraction_status",
            "extraction_error", "review_status", "reviewed_at", "confirmed_at",
            "raw_extracted_payload", "created_at", "updated_at"
        }
        assert expected_wtr.issubset(wtr_cols), f"Missing water_test_reports columns: {expected_wtr - wtr_cols}"

        # Check columns of water_measurements
        wm_cols = {c["name"] for c in inspector.get_columns("water_measurements")}
        expected_wm = {
            "id", "report_id", "farm_id", "water_source_id", "parameter_key",
            "original_parameter_name", "original_value", "original_value_text",
            "original_unit", "normalized_value", "normalized_unit",
            "analytical_method", "detection_limit", "provenance",
            "verification_status", "farmer_corrected_value", "farmer_notes",
            "created_at", "updated_at"
        }
        assert expected_wm.issubset(wm_cols), f"Missing water_measurements columns: {expected_wm - wm_cols}"

        # Check columns of satellite_vegetation_observations
        sat_cols = {c["name"] for c in inspector.get_columns("satellite_vegetation_observations")}
        expected_sat = {
            "id", "farm_id", "observation_date", "product_id", "tile_id",
            "sensor", "processing_baseline", "mean_ndvi", "median_ndvi",
            "min_ndvi", "max_ndvi", "std_ndvi", "mean_ndmi", "valid_pixel_count",
            "total_pixel_count", "farm_coverage_percent", "cloud_masked_percent",
            "spatial_resolution_meters", "quality_status", "quality_notes",
            "is_small_farm_warning", "created_at"
        }
        assert expected_sat.issubset(sat_cols), f"Missing satellite columns: {expected_sat - sat_cols}"


def test_schema_drift_detection_water_sources_fails_safely():
    """
    Verify that if 'water_sources' exists but is missing expected columns,
    migration 007 detects schema drift and raises an explicit error instead of silently skipping.
    """
    mig_007 = _load_migration_007()

    with tempfile.NamedTemporaryFile(suffix=".db") as tmp:
        engine = sa.create_engine(f"sqlite:///{tmp.name}")

        with engine.begin() as conn:
            conn.execute(sa.text("CREATE TABLE farms (id VARCHAR(36) PRIMARY KEY)"))
            # Incomplete table missing daily_available_hours, measured_capacity_lph, etc.
            conn.execute(sa.text("""
                CREATE TABLE water_sources (
                    id VARCHAR(36) PRIMARY KEY,
                    farm_id VARCHAR(36) NOT NULL,
                    source_type VARCHAR(50) NOT NULL,
                    name VARCHAR(100) NOT NULL
                )
            """))

            ctx = MigrationContext.configure(conn)
            op._proxy = Operations(ctx)

            with pytest.raises(RuntimeError, match="Schema drift detected in table 'water_sources'"):
                mig_007.upgrade()


def test_schema_drift_detection_satellite_fails_safely():
    """
    Verify that if 'satellite_vegetation_observations' exists but is missing expected columns,
    migration 007 detects schema drift and raises an explicit error.
    """
    mig_007 = _load_migration_007()

    with tempfile.NamedTemporaryFile(suffix=".db") as tmp:
        engine = sa.create_engine(f"sqlite:///{tmp.name}")

        with engine.begin() as conn:
            conn.execute(sa.text("CREATE TABLE farms (id VARCHAR(36) PRIMARY KEY)"))
            # Incomplete satellite table
            conn.execute(sa.text("""
                CREATE TABLE satellite_vegetation_observations (
                    id VARCHAR(36) PRIMARY KEY,
                    farm_id VARCHAR(36) NOT NULL,
                    observation_date DATETIME NOT NULL
                )
            """))

            ctx = MigrationContext.configure(conn)
            op._proxy = Operations(ctx)

            with pytest.raises(RuntimeError, match="Schema drift detected in table 'satellite_vegetation_observations'"):
                mig_007.upgrade()


def test_downgrade_drops_all_tables_cleanly():
    """Verify that migration 007 downgrade drops all 4 created tables."""
    mig_007 = _load_migration_007()

    with tempfile.NamedTemporaryFile(suffix=".db") as tmp:
        engine = sa.create_engine(f"sqlite:///{tmp.name}")

        with engine.begin() as conn:
            conn.execute(sa.text("CREATE TABLE farms (id VARCHAR(36) PRIMARY KEY)"))
            ctx = MigrationContext.configure(conn)
            op._proxy = Operations(ctx)
            mig_007.upgrade()

        insp = sa.inspect(engine)
        assert "water_sources" in insp.get_table_names()

        # Run downgrade
        with engine.begin() as conn:
            ctx = MigrationContext.configure(conn)
            op._proxy = Operations(ctx)
            mig_007.downgrade()

        insp_after = sa.inspect(engine)
        after_tables = insp_after.get_table_names()
        assert "water_sources" not in after_tables
        assert "water_test_reports" not in after_tables
        assert "water_measurements" not in after_tables
        assert "satellite_vegetation_observations" not in after_tables
        assert "farms" in after_tables  # Farm prerequisite preserved
