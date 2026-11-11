"""
Verifies Alembic migration 010_rashkar_shared_profiles upgrades cleanly both
from empty baseline and when pre-existing unattached Rashkar tables already exist,
without dropping rows or altering existing CropNet `farms` data.
"""
import importlib.util
import os
from alembic.config import Config
from alembic.script import ScriptDirectory
from alembic.migration import MigrationContext
from alembic.operations import Operations
from alembic import op
import sqlalchemy as sa


ALEMBIC_INI_PATH = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "../../../infra/db/alembic.ini")
)
MIG_010_PATH = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "../../../infra/db/migrations/versions/010_rashkar_shared_profiles.py")
)
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))


def _load_mig_010():
    spec = importlib.util.spec_from_file_location("mig_010", MIG_010_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def test_alembic_single_head_is_010():
    config = Config(ALEMBIC_INI_PATH)
    config.set_main_option("script_location", os.path.join(PROJECT_ROOT, "infra/db/migrations"))
    heads = ScriptDirectory.from_config(config).get_heads()
    assert heads == ["010_rashkar_shared_profiles"]


def test_migration_010_preserves_existing_rows_and_adds_shared_columns(tmp_path):
    db_file = tmp_path / "test_mig010.db"
    engine = sa.create_engine(f"sqlite:///{db_file}")
    mig_010 = _load_mig_010()

    with engine.begin() as conn:
        conn.execute(sa.text("CREATE TABLE farms (id VARCHAR(36) PRIMARY KEY, owner_id VARCHAR(36), name VARCHAR(100))"))
        conn.execute(sa.text("INSERT INTO farms VALUES ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000001', 'Existing Farm')"))
        # Simulate pre-existing legacy Rashkar `farmers` & `farmer_resource_profiles` without new columns
        conn.execute(sa.text("""
            CREATE TABLE farmers (
                farmer_id VARCHAR(50) PRIMARY KEY,
                full_name VARCHAR(100) NOT NULL,
                district VARCHAR(50) NOT NULL,
                taluka VARCHAR(50) NOT NULL
            )
        """))
        conn.execute(sa.text("INSERT INTO farmers VALUES ('farmer_demo_01', 'Ramesh Patil', 'Pune', 'Baramati')"))
        conn.execute(sa.text("CREATE TABLE farmer_resource_profiles (farm_id VARCHAR(50) PRIMARY KEY, farmer_id VARCHAR(50) NOT NULL)"))
        conn.execute(sa.text("INSERT INTO farmer_resource_profiles VALUES ('farm_old_1', 'farmer_demo_01')"))

        ctx = MigrationContext.configure(conn)
        op._proxy = Operations(ctx)
        mig_010.upgrade()

    insp = sa.inspect(engine)
    assert "farm_plots" in insp.get_table_names()
    assert "crop_cycles" in insp.get_table_names()
    assert "saved_income_plans" in insp.get_table_names()

    farmer_cols = {c["name"] for c in insp.get_columns("farmers")}
    assert {"age_range", "default_workload_category", "default_clothing_type", "default_is_acclimatised"}.issubset(farmer_cols)

    rp_cols = {c["name"] for c in insp.get_columns("farmer_resource_profiles")}
    assert {"age_range", "profile_completed", "current_crop_code"}.issubset(rp_cols)

    with engine.connect() as conn:
        assert conn.execute(sa.text("SELECT name FROM farms WHERE id='11111111-1111-1111-1111-111111111111'")).scalar() == "Existing Farm"
        assert conn.execute(sa.text("SELECT full_name FROM farmers WHERE farmer_id='farmer_demo_01'")).scalar() == "Ramesh Patil"
        assert conn.execute(sa.text("SELECT farmer_id FROM farmer_resource_profiles WHERE farm_id='farm_old_1'")).scalar() == "farmer_demo_01"
