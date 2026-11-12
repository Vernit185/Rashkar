from fastapi import APIRouter
from cropnet.services.api.app.api.v1.endpoints import (
    health,
    farms,
    soil,
    crops,
    agriculture,
    farm_health,
    schemes,
    crop_doctor,
    heat_risk,
    rashkar_shared,
    risk,
    income,
)

api_router = APIRouter()

api_router.include_router(health.router, tags=["Health"])
api_router.include_router(farms.router, prefix="/farms", tags=["Farms"])
api_router.include_router(rashkar_shared.router, prefix="/farms", tags=["Farms Shared Profile"])
api_router.include_router(farm_health.router)
api_router.include_router(soil.router, prefix="/soil", tags=["Soil Intelligence"])
api_router.include_router(crops.router, prefix="/crops", tags=["Crop Knowledge Base"])
api_router.include_router(agriculture.router, prefix="/agriculture", tags=["Agricultural Reference"])
api_router.include_router(schemes.router, prefix="/schemes", tags=["Government Schemes"])
api_router.include_router(crop_doctor.router, prefix="/crop-doctor", tags=["Crop Doctor AI"])
api_router.include_router(heat_risk.router, prefix="/heat-risk", tags=["Heat Risk Engine"])
api_router.include_router(risk.router, prefix="/risk", tags=["Risk Intelligence"])
api_router.include_router(income.router, prefix="/income", tags=["Extra Income"])
