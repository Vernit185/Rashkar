import os
from typing import Generator
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from cropnet.services.api.app.core.config import settings

_sync_db_url = settings.SYNC_DATABASE_URL or "sqlite:///./cropnet_dev.db"

# Gracefully handle Mac/Linux sqlite paths on Windows if unresolvable
if _sync_db_url.startswith("sqlite:////") and not os.path.exists(_sync_db_url.replace("sqlite:////", "/")):
    _sync_db_url = "sqlite:///./cropnet_dev.db"

_engine_kwargs = {"pool_pre_ping": True}
if _sync_db_url.startswith("sqlite"):
    _engine_kwargs["connect_args"] = {"check_same_thread": False}
else:
    _engine_kwargs["pool_recycle"] = 300

engine = create_engine(
    _sync_db_url,
    **_engine_kwargs
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def get_db() -> Generator[Session, None, None]:
    """
    FastAPI dependency yielding a SQLAlchemy database session.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
