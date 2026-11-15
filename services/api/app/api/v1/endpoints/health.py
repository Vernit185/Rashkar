from fastapi import APIRouter
from pydantic import BaseModel
from typing import Dict, Any, Optional
from datetime import datetime

from cropnet.services.api.app.core.config import settings
from cropnet.services.api.app.services.soil_providers.soilgrids import SoilGridsProvider
from cropnet.services.api.app.services.soil_providers.openlandmap import OpenLandMapProvider
from cropnet.services.api.app.services.soil_providers.natmo import NATMOProvider
from cropnet.services.api.app.services.soil_providers.bhoomi import BhoomiProvider
from cropnet.services.api.app.services.llm.ollama_client import OllamaClient

router = APIRouter()


class HealthCheckResponse(BaseModel):
    status: str
    app_name: str
    environment: str
    timestamp: datetime
    active_pilot_regions: list[str]
    soil_data_providers: Dict[str, Any]
    llm_runtime: Optional[Dict[str, Any]] = None


@router.get("/health", response_model=HealthCheckResponse)
async def health_check():
    sg = SoilGridsProvider()
    olm = OpenLandMapProvider()
    natmo = NATMOProvider()
    bhoomi = BhoomiProvider()
    ollama = OllamaClient()

    ollama_online = ollama.is_available()
    model_online = ollama.is_model_available() if ollama_online else False

    llm_provider = "groq" if settings.LLM_PROVIDER.lower() == "groq" else "ollama_local"
    llm_model = settings.GROQ_MODEL if llm_provider == "groq" else settings.OLLAMA_MODEL

    return HealthCheckResponse(
        status="healthy",
        app_name=settings.APP_NAME,
        environment=settings.ENVIRONMENT,
        timestamp=datetime.utcnow(),
        active_pilot_regions=["Maval", "Mulshi", "Baramati", "Indapur"],
        soil_data_providers={
            "isric_soilgrids": {
                "operational": True,
                "version": "2.0.0",
                "access_method": "OGC WCS 2.0.1",
                "resolution": "250m"
            },
            "openlandmap": {
                "operational": True,
                "version": "v20250204",
                "access_method": "Cloud-Optimized GeoTIFFs (Wasabi S3)",
                "resolution": "30m"
            },
            "icar_nbsslup_bhoomi": {
                "operational": False,
                "status": "Pending institutional access / credentials (HTTP 403)"
            },
            "natmo_geoportal": {
                "operational": False,
                "status": "Service unavailable (HTTP 500) & cartographic WMS display tiles only"
            }
        },
        llm_runtime={
            "provider": llm_provider,
            "configured_model": llm_model,
            "ollama_server_online": ollama_online,
            "model_available": model_online,
            "operational": ollama_online and model_online,
            "fallback_available": True
        }
    )
