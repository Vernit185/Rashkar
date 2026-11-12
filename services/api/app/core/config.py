import os
import json
import logging
from typing import List, Optional, Any, Union
from pydantic import field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

logger = logging.getLogger(__name__)

DEFAULT_DEV_CORS_ORIGINS: List[str] = [
    "http://localhost:3000",
    "http://localhost:8000",
    "http://localhost:8080",
    "http://127.0.0.1:3000",
    "http://127.0.0.1:8000",
    "http://127.0.0.1:8080",
    "http://192.168.1.2:8080",
    "http://192.168.1.2:8000",
]


class Settings(BaseSettings):
    ENVIRONMENT: str = "development"
    APP_NAME: str = "CropNet AI Backend"
    API_V1_PREFIX: str = "/api/v1"
    LOG_LEVEL: str = "INFO"

    # CORS: Explicit origins list (replaces unsafe wildcard default)
    CORS_ORIGINS: List[str] = DEFAULT_DEV_CORS_ORIGINS

    @field_validator("CORS_ORIGINS", mode="before")
    @classmethod
    def parse_cors_origins(cls, v: Any) -> List[str]:
        """Parse CORS_ORIGINS from JSON array string or comma-delimited string."""
        if isinstance(v, str):
            v = v.strip()
            if v.startswith("[") and v.endswith("]"):
                try:
                    return json.loads(v)
                except (json.JSONDecodeError, ValueError, TypeError) as exc:
                    logger.warning("Failed to parse CORS_ORIGINS as JSON array: %s", exc)
            return [origin.strip() for origin in v.split(",") if origin.strip()]
        elif isinstance(v, (list, tuple, set)):
            return [str(origin).strip() for origin in v if str(origin).strip()]
        return v

    @model_validator(mode="after")
    def validate_cors_security(self) -> "Settings":
        """Reject insecure configurations in production environments."""
        is_production = self.ENVIRONMENT.lower() in ("production", "prod")
        if is_production:
            if any(origin == "*" for origin in self.CORS_ORIGINS):
                raise ValueError(
                    "Security violation: Wildcard CORS origin '*' is strictly prohibited in production environments. "
                    "Specify explicit allowed origins via CORS_ORIGINS."
                )
            if not self.CORS_ORIGINS:
                raise ValueError(
                    "Security violation: CORS_ORIGINS cannot be empty in production environments."
                )
            if self.ALLOW_DEV_AUTH_BYPASS:
                raise ValueError(
                    "Security violation: ALLOW_DEV_AUTH_BYPASS is strictly prohibited in production environments."
                )
        return self

    # Supabase Configuration
    SUPABASE_AUTH_ENABLED: bool = True
    SUPABASE_URL: Optional[str] = None
    SUPABASE_ANON_KEY: Optional[str] = None
    SUPABASE_SECRET_KEY: Optional[str] = None
    SUPABASE_SERVICE_ROLE_KEY: Optional[str] = None
    SUPABASE_JWT_SECRET: Optional[str] = None
    SUPABASE_DB_PASSWORD: Optional[str] = None
    SUPABASE_PROJECT_REF: Optional[str] = None
    
    # Development Auth Bypass Gate (Strictly opt-in, prohibited in production)
    ALLOW_DEV_AUTH_BYPASS: bool = False
    DEV_USER_ID: str = "00000000-0000-0000-0000-000000000001"
    DEV_USER_EMAIL: str = "dev@cropnet.local"

    # Government Schemes admin authorization.
    # Comma-separated (or JSON array) of Supabase user emails / IDs permitted to
    # create, edit, verify, publish and deactivate schemes.
    ADMIN_EMAILS: List[str] = []
    ADMIN_USER_IDS: List[str] = []

    @field_validator("ADMIN_EMAILS", "ADMIN_USER_IDS", mode="before")
    @classmethod
    def parse_admin_lists(cls, v: Any) -> List[str]:
        """Parse admin email/user-id lists from JSON array or comma-delimited strings."""
        if isinstance(v, str):
            v = v.strip()
            if not v:
                return []
            if v.startswith("[") and v.endswith("]"):
                try:
                    return [str(item).strip() for item in json.loads(v)]
                except (json.JSONDecodeError, ValueError, TypeError) as exc:
                    logger.warning("Failed to parse admin list as JSON array: %s", exc)
            return [item.strip() for item in v.split(",") if item.strip()]
        elif isinstance(v, (list, tuple, set)):
            return [str(item).strip() for item in v if str(item).strip()]
        return []

    # Database URLs (Strictly injected via environment variables; never hardcode credentials)
    # Credential Rotation: Set DATABASE_URL and SYNC_DATABASE_URL to new rotated credentials
    # in untracked environment files or container secret injection without source modification.
    DATABASE_URL: Optional[str] = None
    SYNC_DATABASE_URL: Optional[str] = None

    # Weather Provider (OpenWeather)
    OPENWEATHER_API_KEY: Optional[str] = None
    OPENWEATHER_API_KEY_FALLBACK: Optional[str] = None

    # Map Tile Provider (MapTiler)
    MAPTILER_API_KEY: Optional[str] = None
    MAPTILER_API_KEY_FALLBACK: Optional[str] = None

    # External Soil GIS Services
    SOILGRIDS_WCS_BASE_URL: str = "https://maps.isric.org/mapserv"
    SOILGRIDS_TIMEOUT_SECONDS: int = 25
    OPENLANDMAP_BASE_URL: str = "http://s3.opengeohub.org/global-soil/global_soil_props_v20250204_mosaics"
    BHOOMI_GEOSERVER_URL: str = "https://bhoomigeoportal-nbsslup.in/geoserver"
    NATMO_PORTAL_URL: str = "https://geoportal.natmo.gov.in"

    # Feature Flags
    ENABLE_LOCAL_RASTER_CACHE: bool = True
    LOCAL_RASTER_CACHE_DIR: str = "./data_cache/rasters"
    ENABLE_ECONOMIC_RANKING: bool = False
    ENABLE_YIELD_PREDICTION: bool = False

    # Local LLM Runtime (Ollama / Qwen3:8B)
    OLLAMA_BASE_URL: str = "http://127.0.0.1:11434"
    OLLAMA_MODEL: str = "qwen3:8b"
    OLLAMA_TIMEOUT_SECONDS: int = 40
    OLLAMA_TEMPERATURE: float = 0.1
    OLLAMA_MAX_TOKENS: int = 600
    OLLAMA_ENABLED: bool = True

    model_config = SettingsConfigDict(
        env_file=[
            os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__))))), ".env"),
            os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__)))), ".env"),
            ".env"
        ],
        env_file_encoding="utf-8",
        extra="ignore"
    )


settings = Settings()
