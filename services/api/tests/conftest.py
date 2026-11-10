"""
Shared Pytest configuration and isolation fixtures for CropNet API tests.

Guarantees 100% test isolation from external databases:
- Strict block on any remote/production database connections via engine.connect monkeypatch.
- Function-scoped isolated database sessions using SQLite in-memory with automatic per-test rollback.
- Guaranteed cleanup of FastAPI dependency_overrides after every single test.
- Prevents test order dependencies and cross-test state leakage.
"""
import pytest
from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.pool import StaticPool
from fastapi.testclient import TestClient

from cropnet.services.api.app.models.soil_and_farm import Base
import cropnet.services.api.app.models.crops
import cropnet.services.api.app.models.rashkar_profiles
from cropnet.services.api.app.services.crop_knowledge.crop_service import CropKnowledgeService
from cropnet.services.api.app.services.rashkar.db_init import ensure_rashkar_schema_and_seed
from cropnet.services.api.app.core import database
from cropnet.services.api.app.core.config import settings
from cropnet.services.api.app.core.database import get_db
from cropnet.services.api.app.main import app

# Enable opt-in dev auth bypass for isolated unit tests
settings.ALLOW_DEV_AUTH_BYPASS = True


# 1. Global in-memory test engine for isolated test suites
_test_engine = create_engine(
    "sqlite:///:memory:",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool
)
_TestingSession = sessionmaker(autocommit=False, autoflush=False, bind=_test_engine)

# Initialize schema and seed baseline knowledge base once on test engine
Base.metadata.create_all(bind=_test_engine)
_seed_session = _TestingSession()
_service = CropKnowledgeService()
_service.seed_knowledge_base(_seed_session)
_seed_session.close()
ensure_rashkar_schema_and_seed(_test_engine, _TestingSession)


@pytest.fixture(scope="session", autouse=True)
def guard_against_production_database_connections():
    """
    Session-level guard that strictly prevents any test from connecting to
    remote Supabase or any production PostgreSQL database.
    """
    def _blocked_connect(*args, **kwargs):
        raise RuntimeError(
            "CRITICAL SECURITY VIOLATION: A test attempted to connect to the "
            "remote production database! All tests must execute against isolated test fixtures."
        )

    original_connect = database.engine.connect
    database.engine.connect = _blocked_connect
    yield
    database.engine.connect = original_connect


@pytest.fixture(autouse=True)
def isolated_test_session():
    """
    Function-scoped fixture providing transaction-isolated database access.
    Each test receives a fresh transaction that is automatically rolled back
    upon test completion. Dependency overrides are always cleared.
    """
    connection = _test_engine.connect()
    transaction = connection.begin()
    session = _TestingSession(bind=connection)

    def _override_get_db():
        try:
            yield session
        finally:
            pass

    app.dependency_overrides[get_db] = _override_get_db

    orig_bypass = settings.ALLOW_DEV_AUTH_BYPASS
    orig_env = settings.ENVIRONMENT

    yield session

    session.close()
    transaction.rollback()
    connection.close()
    app.dependency_overrides.clear()
    settings.ALLOW_DEV_AUTH_BYPASS = orig_bypass
    settings.ENVIRONMENT = orig_env


@pytest.fixture
def test_client():
    """
    Isolated FastAPI test client.
    """
    return TestClient(app)
