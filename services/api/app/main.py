import os
import time
import uuid
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from starlette.responses import JSONResponse

from cropnet.services.api.app.core.config import settings
from cropnet.services.api.app.core.logging import setup_logging
from cropnet.services.api.app.core.database import engine, SessionLocal
from cropnet.services.api.app.api.v1.router import api_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    setup_logging()
    if not os.environ.get("PYTEST_CURRENT_TEST"):
        try:
            from cropnet.services.api.app.services.rashkar.db_init import ensure_rashkar_schema_and_seed
            ensure_rashkar_schema_and_seed(engine, SessionLocal)
        except Exception:
            pass
    yield


app = FastAPI(
    title=settings.APP_NAME,
    version="1.0.0",
    description="CropNet AI Soil Intelligence & Optimal Crop Selection Backend",
    openapi_url=f"{settings.API_V1_PREFIX}/openapi.json",
    docs_url=f"{settings.API_V1_PREFIX}/docs",
    redoc_url=f"{settings.API_V1_PREFIX}/redoc",
    lifespan=lifespan
)

# Safe CORS Middleware Setup
# allow_credentials=True must only be paired with explicit permitted origins (never wildcard '*')
has_wildcard_cors = any(origin == "*" for origin in settings.CORS_ORIGINS)
if has_wildcard_cors and settings.ENVIRONMENT.lower() in ("production", "prod"):
    raise RuntimeError(
        "CRITICAL SECURITY CONFIGURATION ERROR: Wildcard CORS origins '*' are forbidden in production with credentials."
    )

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=not has_wildcard_cors,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "Accept", "X-Dev-User-Id", "X-Request-ID"],
)


@app.middleware("http")
async def request_middleware(request: Request, call_next):
    request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))
    start_time = time.time()
    try:
        response = await call_next(request)
    except Exception as exc:
        process_time = time.time() - start_time
        return JSONResponse(
            status_code=500,
            content={"detail": "Internal server error", "request_id": request_id},
            headers={"X-Request-ID": request_id, "X-Process-Time": f"{process_time:.4f}s"}
        )
    process_time = time.time() - start_time
    response.headers["X-Request-ID"] = request_id
    response.headers["X-Process-Time"] = f"{process_time:.4f}s"
    return response


# Include API v1 router
app.include_router(api_router, prefix=settings.API_V1_PREFIX)

try:
    from cropnet.services.api.app.api.v1.endpoints.soil_reports import router as soil_reports_router
except ImportError:
    from .api.v1.endpoints.soil_reports import router as soil_reports_router

try:
    from cropnet.services.api.app.api.v1.endpoints.water import router as water_router
except ImportError:
    from .api.v1.endpoints.water import router as water_router

try:
    from cropnet.services.api.app.api.v1.endpoints.satellite import router as satellite_router
except ImportError:
    from .api.v1.endpoints.satellite import router as satellite_router

app.include_router(soil_reports_router, prefix=settings.API_V1_PREFIX)
app.include_router(water_router, prefix=settings.API_V1_PREFIX)
app.include_router(satellite_router, prefix=settings.API_V1_PREFIX)


@app.get("/")
async def root():
    return {
        "app": settings.APP_NAME,
        "environment": settings.ENVIRONMENT,
        "docs": f"{settings.API_V1_PREFIX}/docs",
        "health": f"{settings.API_V1_PREFIX}/health"
    }
