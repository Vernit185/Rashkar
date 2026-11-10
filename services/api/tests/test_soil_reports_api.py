"""
Unit and Integration Tests for Soil Laboratory Report Endpoints and Services.

Tests:
1. Valid PDF upload with metadata and signed URL generation
2. Valid image upload (JPEG and PNG)
3. Invalid document format rejection (e.g. .exe, .txt, .docx)
4. 15MB file size limit rejection
5. Empty file upload rejection
6. Strict farm ownership enforcement (HTTP 403 for unauthorized users across all operations)
7. Multi-sample and multi-depth listing for a farm
8. Report detail retrieval with measurements and signed download URL
9. Extracted measurements listing with filtering
10. Farmer measurement correction (PATCH / PUT) and audit trail preservation
11. Farmer report confirmation (all measurements confirmed)
12. Farmer report confirmation (selective measurement IDs)
13. Unconfirmed measurement isolation (EXTRACTED_UNVERIFIED not treated as confirmed)
14. Document reprocessing workflow
15. Document streaming with proper media-type and Content-Disposition headers
16. Time-limited signed URL generation
17. 404 handling on non-existent farm, report, and measurement
"""
import sys
import io
import uuid
import types
from datetime import datetime
from pathlib import Path
import pytest
from fastapi.testclient import TestClient

# Ensure current worktree is prioritized for all cropnet submodules
import os
_worktree_root = str(Path(__file__).resolve().parents[3])

class _WorktreePathFinder:
    @classmethod
    def find_spec(cls, fullname, path=None, target=None):
        if fullname.startswith("cropnet."):
            rel = fullname[len("cropnet"):].replace(".", "/")
            subpath = _worktree_root + rel
            parent_name = fullname.rsplit(".", 1)[0]
            if parent_name in sys.modules and hasattr(sys.modules[parent_name], "__path__"):
                parent_sub = _worktree_root + parent_name[len("cropnet"):].replace(".", "/")
                _p = sys.modules[parent_name].__path__
                if os.path.exists(parent_sub) and parent_sub not in _p:
                    if hasattr(_p, 'insert'):
                        _p.insert(0, parent_sub)
                    elif hasattr(_p, 'append'):
                        _p.append(parent_sub)
        return None

if not any(isinstance(finder, type) and finder.__name__ == "_WorktreePathFinder" for finder in sys.meta_path):
    sys.meta_path.insert(0, _WorktreePathFinder)

for _mod_name, _mod in list(sys.modules.items()):
    if _mod_name == "cropnet" or _mod_name.startswith("cropnet."):
        if hasattr(_mod, "__path__"):
            _rel = _mod_name[len("cropnet"):].replace(".", "/")
            _subpath = _worktree_root + _rel
            _p = _mod.__path__
            if os.path.exists(_subpath) and _subpath not in _p:
                if hasattr(_p, 'insert'):
                    _p.insert(0, _subpath)
                elif hasattr(_p, 'append'):
                    _p.append(_subpath)

from cropnet.services.api.app.models.soil_and_farm import Base
from cropnet.services.api.app.models.soil_reports import SoilTestReportModel, SoilMeasurementModel
from cropnet.services.api.app.schemas.soil_reports import (
    ExtractionStatus,
    ReviewStatus,
    MeasurementVerificationStatus,
)
from cropnet.services.api.app.api.v1.endpoints.soil_reports import router as soil_reports_router
from cropnet.services.api.app.core.config import settings
from cropnet.services.api.app.main import app

# Ensure router is registered on app instance
_has_soil_reports = any(
    "soil-reports" in getattr(r, "path", "") or
    any("soil-reports" in getattr(sub, "path", "") for sub in getattr(r, "routes", []))
    for r in app.routes
)
if not _has_soil_reports:
    app.include_router(soil_reports_router, prefix=settings.API_V1_PREFIX)

client = TestClient(app)


@pytest.fixture(autouse=True)
def setup_soil_report_tables(isolated_test_session):
    """Ensure soil report tables exist in SQLite in-memory test engine."""
    Base.metadata.create_all(bind=isolated_test_session.get_bind())
    yield


def _create_test_farm(owner_id: str, name: str = "Test Baramati Farm") -> str:
    """Helper to create a farm for testing."""
    payload = {
        "name": name,
        "taluka": "Baramati",
        "district": "Pune",
        "state": "Maharashtra",
        "village": "Malegaon",
        "irrigation_type": "irrigated",
        "water_source": "canal",
        "geometry": {
            "type": "Polygon",
            "coordinates": [[
                [74.525, 18.175],
                [74.535, 18.175],
                [74.535, 18.185],
                [74.525, 18.185],
                [74.525, 18.175]
            ]]
        }
    }
    resp = client.post("/api/v1/farms", json=payload, headers={"X-Dev-User-Id": owner_id})
    assert resp.status_code == 201, f"Failed to create farm: {resp.text}"
    return resp.json()["id"]


# =========================================================================
# 1. Document Upload Tests
# =========================================================================

def test_upload_pdf_report_success():
    """Test uploading a valid PDF document with laboratory and sampling metadata."""
    user_id = str(uuid.uuid4())
    farm_id = _create_test_farm(user_id)

    pdf_bytes = b"%PDF-1.4 sample PDF soil testing report for Baramati farm"
    files = {"file": ("soil_report_2026.pdf", io.BytesIO(pdf_bytes), "application/pdf")}
    data = {
        "laboratory_name": "Krishi Vigyan Kendra Soil Testing Lab",
        "report_date": "2026-11-01",
        "sample_collection_date": "2026-10-25",
        "sample_depth_interval": "0-15cm",
        "sampling_point_name": "North Field - Plot A",
    }

    resp = client.post(
        f"/api/v1/farms/{farm_id}/soil-reports",
        files=files,
        data=data,
        headers={"X-Dev-User-Id": user_id}
    )
    assert resp.status_code == 201
    result = resp.json()

    assert result["farm_id"] == farm_id
    assert result["user_id"] == user_id
    assert result["original_filename"] == "soil_report_2026.pdf"
    assert result["laboratory_name"] == "Krishi Vigyan Kendra Soil Testing Lab"
    assert result["sample_depth_interval"] == "0-15cm"
    assert result["sampling_point_name"] == "North Field - Plot A"
    assert result["extraction_status"] in (ExtractionStatus.UPLOADED.value, ExtractionStatus.PROCESSING.value, ExtractionStatus.NEEDS_REVIEW.value, ExtractionStatus.FAILED.value)
    assert result["review_status"] == ReviewStatus.NEEDS_REVIEW.value
    assert result["signed_document_url"] is not None
    assert result["file_size_bytes"] == len(pdf_bytes)


def test_upload_image_report_jpeg_and_png_success():
    """Test uploading laboratory reports as JPEG and PNG images."""
    user_id = str(uuid.uuid4())
    farm_id = _create_test_farm(user_id)

    # 1. JPEG Upload
    jpeg_bytes = b"\xFF\xD8\xFF\xE0 sample jpeg soil report content"
    files_jpeg = {"file": ("lab_report.jpg", io.BytesIO(jpeg_bytes), "image/jpeg")}
    resp_jpeg = client.post(
        f"/api/v1/farms/{farm_id}/soil-reports/upload",
        files=files_jpeg,
        data={"laboratory_name": "District Soil Testing Lab Pune"},
        headers={"X-Dev-User-Id": user_id}
    )
    assert resp_jpeg.status_code == 201
    assert resp_jpeg.json()["mime_type"] == "image/jpeg"

    # 2. PNG Upload
    png_bytes = b"\x89PNG\r\n\x1a\n sample png soil report content"
    files_png = {"file": ("lab_report.png", io.BytesIO(png_bytes), "image/png")}
    resp_png = client.post(
        f"/api/v1/farms/{farm_id}/soil-reports/upload",
        files=files_png,
        data={"laboratory_name": "ICAR-NRC on Pomegranate Lab"},
        headers={"X-Dev-User-Id": user_id}
    )
    assert resp_png.status_code == 201
    assert resp_png.json()["mime_type"] == "image/png"


def test_upload_invalid_format_rejected():
    """Verify rejection of unsupported file formats (e.g. .exe, .txt, .docx)."""
    user_id = str(uuid.uuid4())
    farm_id = _create_test_farm(user_id)

    files = {"file": ("malicious_payload.exe", io.BytesIO(b"MZ executable content"), "application/x-msdownload")}
    resp = client.post(
        f"/api/v1/farms/{farm_id}/soil-reports",
        files=files,
        headers={"X-Dev-User-Id": user_id}
    )
    assert resp.status_code == 400
    assert "Unsupported file format" in resp.json()["detail"]


def test_upload_signature_mismatch_rejected():
    """Verify rejection when file extension does not match file magic bytes."""
    user_id = str(uuid.uuid4())
    farm_id = _create_test_farm(user_id)

    # 1. Fake PDF with text bytes
    files_fake_pdf = {"file": ("fake.pdf", io.BytesIO(b"This is a text file masquerading as pdf"), "application/pdf")}
    resp = client.post(
        f"/api/v1/farms/{farm_id}/soil-reports",
        files=files_fake_pdf,
        headers={"X-Dev-User-Id": user_id}
    )
    assert resp.status_code == 400
    assert "signature" in resp.json()["detail"].lower()

    # 2. Fake JPEG with text bytes
    files_fake_jpeg = {"file": ("fake.jpg", io.BytesIO(b"Not a jpeg file"), "image/jpeg")}
    resp_jpeg = client.post(
        f"/api/v1/farms/{farm_id}/soil-reports",
        files=files_fake_jpeg,
        headers={"X-Dev-User-Id": user_id}
    )
    assert resp_jpeg.status_code == 400
    assert "signature" in resp_jpeg.json()["detail"].lower()


def test_upload_browser_octet_stream_normalized():
    """Verify that browser-uploaded files with application/octet-stream are normalized by extension."""
    user_id = str(uuid.uuid4())
    farm_id = _create_test_farm(user_id)

    pdf_bytes = b"%PDF-1.4 baramati official soil test"
    files = {"file": ("browser_report.pdf", io.BytesIO(pdf_bytes), "application/octet-stream")}
    resp = client.post(
        f"/api/v1/farms/{farm_id}/soil-reports",
        files=files,
        data={"lab_name": "Government Agriculture Lab"},
        headers={"X-Dev-User-Id": user_id}
    )
    assert resp.status_code == 201
    assert resp.json()["mime_type"] == "application/pdf"
    assert resp.json()["laboratory_name"] == "Government Agriculture Lab"


def test_upload_empty_file_rejected():
    """Verify rejection of zero-byte file uploads."""
    user_id = str(uuid.uuid4())
    farm_id = _create_test_farm(user_id)

    files = {"file": ("empty.pdf", io.BytesIO(b""), "application/pdf")}
    resp = client.post(
        f"/api/v1/farms/{farm_id}/soil-reports",
        files=files,
        headers={"X-Dev-User-Id": user_id}
    )
    assert resp.status_code == 400
    assert "empty" in resp.json()["detail"].lower()


def test_upload_file_size_limit_exceeded_rejected():
    """Verify rejection of files exceeding the 15MB limit."""
    user_id = str(uuid.uuid4())
    farm_id = _create_test_farm(user_id)

    # 15MB + 1 byte
    oversized_bytes = b"0" * (15 * 1024 * 1024 + 1)
    files = {"file": ("huge_report.pdf", io.BytesIO(oversized_bytes), "application/pdf")}
    resp = client.post(
        f"/api/v1/farms/{farm_id}/soil-reports",
        files=files,
        headers={"X-Dev-User-Id": user_id}
    )
    assert resp.status_code == 400
    assert "15MB" in resp.json()["detail"]


# =========================================================================
# 2. Multi-Tenant Farm Ownership Enforcement Tests
# =========================================================================

def test_farm_ownership_enforcement():
    """
    Verify that an authenticated user cannot access, upload, list,
    or modify soil reports for another farmer's farm (HTTP 403 Forbidden).
    """
    farmer_a = str(uuid.uuid4())
    farmer_b = str(uuid.uuid4())

    farm_a_id = _create_test_farm(farmer_a, "Farmer A Farm")

    # 1. Farmer A uploads a report
    pdf_bytes = b"%PDF-1.4 Report for Farm A"
    files = {"file": ("report_a.pdf", io.BytesIO(pdf_bytes), "application/pdf")}
    upload_resp = client.post(
        f"/api/v1/farms/{farm_a_id}/soil-reports",
        files=files,
        headers={"X-Dev-User-Id": farmer_a}
    )
    assert upload_resp.status_code == 201
    report_a_id = upload_resp.json()["id"]

    # 2. Farmer B attempts to upload to Farm A -> 403 Forbidden
    resp = client.post(
        f"/api/v1/farms/{farm_a_id}/soil-reports",
        files={"file": ("unauthorized.pdf", io.BytesIO(pdf_bytes), "application/pdf")},
        headers={"X-Dev-User-Id": farmer_b}
    )
    assert resp.status_code == 403

    # 3. Farmer B attempts to list reports for Farm A -> 403 Forbidden
    resp = client.get(
        f"/api/v1/farms/{farm_a_id}/soil-reports",
        headers={"X-Dev-User-Id": farmer_b}
    )
    assert resp.status_code == 403

    # 4. Farmer B attempts to get report detail -> 403 Forbidden
    resp = client.get(
        f"/api/v1/farms/{farm_a_id}/soil-reports/{report_a_id}",
        headers={"X-Dev-User-Id": farmer_b}
    )
    assert resp.status_code == 403

    # 5. Farmer B attempts to get measurements -> 403 Forbidden
    resp = client.get(
        f"/api/v1/farms/{farm_a_id}/soil-reports/{report_a_id}/measurements",
        headers={"X-Dev-User-Id": farmer_b}
    )
    assert resp.status_code == 403

    # 6. Farmer B attempts to confirm report -> 403 Forbidden
    resp = client.post(
        f"/api/v1/farms/{farm_a_id}/soil-reports/{report_a_id}/confirm",
        headers={"X-Dev-User-Id": farmer_b}
    )
    assert resp.status_code == 403

    # 7. Farmer B attempts to stream document -> 403 Forbidden
    resp = client.get(
        f"/api/v1/farms/{farm_a_id}/soil-reports/{report_a_id}/document",
        headers={"X-Dev-User-Id": farmer_b}
    )
    assert resp.status_code == 403


# =========================================================================
# 3. Listing & Multi-Depth Support Tests
# =========================================================================

def test_list_soil_reports_multi_depth():
    """Test listing multiple reports supporting distinct sampling depths for one farm."""
    user_id = str(uuid.uuid4())
    farm_id = _create_test_farm(user_id)

    # Upload Topsoil Sample (0-15cm)
    client.post(
        f"/api/v1/farms/{farm_id}/soil-reports",
        files={"file": ("topsoil.pdf", io.BytesIO(b"%PDF topsoil"), "application/pdf")},
        data={"sample_depth_interval": "0-15cm", "sampling_point_name": "Point 1"},
        headers={"X-Dev-User-Id": user_id}
    )

    # Upload Subsoil Sample (15-30cm)
    client.post(
        f"/api/v1/farms/{farm_id}/soil-reports",
        files={"file": ("subsoil.pdf", io.BytesIO(b"%PDF subsoil"), "application/pdf")},
        data={"sample_depth_interval": "15-30cm", "sampling_point_name": "Point 1"},
        headers={"X-Dev-User-Id": user_id}
    )

    # Retrieve list
    resp = client.get(
        f"/api/v1/farms/{farm_id}/soil-reports",
        headers={"X-Dev-User-Id": user_id}
    )
    assert resp.status_code == 200
    reports = resp.json()
    assert len(reports) == 2

    depths = {r["sample_depth_interval"] for r in reports}
    assert "0-15cm" in depths
    assert "15-30cm" in depths


# =========================================================================
# 4. Measurement Extraction, Correction, and Confirmation Tests
# =========================================================================

def test_measurements_lifecycle_and_farmer_correction(isolated_test_session):
    """
    Test end-to-end measurement lifecycle:
    1. Seed extracted unverified measurements
    2. Retrieve measurements list
    3. Submit farmer correction
    4. Verify original value preserved and corrected value recorded
    5. Confirm report transcription
    6. Verify status transitions to FARMER_CONFIRMED
    """
    user_id = str(uuid.uuid4())
    farm_id = _create_test_farm(user_id)

    # Create report directly
    report_id = str(uuid.uuid4())
    report = SoilTestReportModel(
        id=report_id,
        user_id=user_id,
        farm_id=farm_id,
        original_filename="sample_report.pdf",
        storage_path=f"{farm_id}/{report_id}/sample_report.pdf",
        file_size_bytes=1024,
        mime_type="application/pdf",
        upload_timestamp=datetime.utcnow(),
        laboratory_name="Baramati Lab",
        extraction_status=ExtractionStatus.NEEDS_REVIEW.value,
        review_status=ReviewStatus.NEEDS_REVIEW.value,
    )
    isolated_test_session.add(report)

    # Seed 3 measurements
    m_ph = SoilMeasurementModel(
        id=str(uuid.uuid4()),
        report_id=report_id,
        farm_id=farm_id,
        parameter_key="soil_ph",
        original_parameter_name="Soil pH",
        original_value=7.5,
        original_unit="pH",
        normalized_value=7.5,
        normalized_unit="pH",
        verification_status=MeasurementVerificationStatus.EXTRACTED_UNVERIFIED.value,
    )
    m_n = SoilMeasurementModel(
        id=str(uuid.uuid4()),
        report_id=report_id,
        farm_id=farm_id,
        parameter_key="available_nitrogen",
        original_parameter_name="Available Nitrogen",
        original_value=240.0,
        original_unit="kg/ha",
        normalized_value=240.0,
        normalized_unit="kg/ha",
        verification_status=MeasurementVerificationStatus.EXTRACTED_UNVERIFIED.value,
    )
    m_p = SoilMeasurementModel(
        id=str(uuid.uuid4()),
        report_id=report_id,
        farm_id=farm_id,
        parameter_key="available_phosphorus",
        original_parameter_name="Available Phosphorus (P2O5)",
        original_value=18.0,
        original_unit="kg/ha",
        normalized_value=18.0,
        normalized_unit="kg/ha",
        verification_status=MeasurementVerificationStatus.EXTRACTED_UNVERIFIED.value,
    )
    isolated_test_session.add_all([m_ph, m_n, m_p])
    isolated_test_session.commit()

    # 1. GET Measurements list
    resp = client.get(
        f"/api/v1/farms/{farm_id}/soil-reports/{report_id}/measurements",
        headers={"X-Dev-User-Id": user_id}
    )
    assert resp.status_code == 200
    measurements = resp.json()
    assert len(measurements) == 3
    assert all(m["verification_status"] == MeasurementVerificationStatus.EXTRACTED_UNVERIFIED.value for m in measurements)

    # 2. Farmer corrects Available Nitrogen (OCR misread 240, report says 280)
    corr_payload = {
        "corrected_value": 280.0,
        "corrected_unit": "kg/ha",
        "farmer_notes": "Lab report clearly specifies 280 kg/ha in table row 2"
    }
    patch_resp = client.patch(
        f"/api/v1/farms/{farm_id}/soil-reports/{report_id}/measurements/{m_n.id}",
        json=corr_payload,
        headers={"X-Dev-User-Id": user_id}
    )
    assert patch_resp.status_code == 200
    updated_m = patch_resp.json()
    assert updated_m["original_value"] == 240.0  # Original preserved!
    assert updated_m["farmer_corrected_value"] == 280.0
    assert updated_m["verification_status"] == MeasurementVerificationStatus.FARMER_CORRECTED.value
    assert updated_m["farmer_notes"] == "Lab report clearly specifies 280 kg/ha in table row 2"

    # 3. Confirm Report Transcription
    confirm_resp = client.post(
        f"/api/v1/farms/{farm_id}/soil-reports/{report_id}/confirm",
        headers={"X-Dev-User-Id": user_id}
    )
    assert confirm_resp.status_code == 200
    assert confirm_resp.json()["status"] == "confirmed"
    assert confirm_resp.json()["confirmed_measurement_count"] == 3

    # 4. Verify all measurements are now FARMER_CONFIRMED
    resp_after = client.get(
        f"/api/v1/farms/{farm_id}/soil-reports/{report_id}/measurements",
        headers={"X-Dev-User-Id": user_id}
    )
    assert resp_after.status_code == 200
    measurements_after = resp_after.json()
    assert all(m["verification_status"] == MeasurementVerificationStatus.FARMER_CONFIRMED.value for m in measurements_after)


def test_selective_measurement_confirmation(isolated_test_session):
    """Test confirming only a subset of measurements."""
    user_id = str(uuid.uuid4())
    farm_id = _create_test_farm(user_id)

    report_id = str(uuid.uuid4())
    report = SoilTestReportModel(
        id=report_id,
        user_id=user_id,
        farm_id=farm_id,
        original_filename="sample.pdf",
        storage_path=f"{farm_id}/{report_id}/sample.pdf",
        upload_timestamp=datetime.utcnow(),
    )
    isolated_test_session.add(report)

    m1 = SoilMeasurementModel(
        id=str(uuid.uuid4()),
        report_id=report_id,
        farm_id=farm_id,
        parameter_key="soil_ph",
        original_parameter_name="pH",
        original_value=6.8,
        original_unit="pH",
        verification_status=MeasurementVerificationStatus.EXTRACTED_UNVERIFIED.value,
    )
    m2 = SoilMeasurementModel(
        id=str(uuid.uuid4()),
        report_id=report_id,
        farm_id=farm_id,
        parameter_key="electrical_conductivity",
        original_parameter_name="EC",
        original_value=0.45,
        original_unit="dS/m",
        verification_status=MeasurementVerificationStatus.EXTRACTED_UNVERIFIED.value,
    )
    isolated_test_session.add_all([m1, m2])
    isolated_test_session.commit()

    # Confirm only m1
    confirm_resp = client.post(
        f"/api/v1/farms/{farm_id}/soil-reports/{report_id}/confirm",
        json={"measurement_ids": [m1.id]},
        headers={"X-Dev-User-Id": user_id}
    )
    assert confirm_resp.status_code == 200
    assert confirm_resp.json()["confirmed_measurement_count"] == 1

    # Verify m1 is confirmed, m2 remains unverified
    resp = client.get(
        f"/api/v1/farms/{farm_id}/soil-reports/{report_id}/measurements",
        headers={"X-Dev-User-Id": user_id}
    )
    items = {m["id"]: m["verification_status"] for m in resp.json()}
    assert items[m1.id] == MeasurementVerificationStatus.FARMER_CONFIRMED.value
    assert items[m2.id] == MeasurementVerificationStatus.EXTRACTED_UNVERIFIED.value


# =========================================================================
# 5. Document Streaming, Signed URLs, and Reprocessing Tests
# =========================================================================

def test_stream_document_and_signed_url_generation():
    """Test retrieving document content and requesting time-limited signed URL."""
    user_id = str(uuid.uuid4())
    farm_id = _create_test_farm(user_id)

    pdf_content = b"%PDF-1.4 Test document streaming content"
    upload_resp = client.post(
        f"/api/v1/farms/{farm_id}/soil-reports",
        files={"file": ("test_doc.pdf", io.BytesIO(pdf_content), "application/pdf")},
        headers={"X-Dev-User-Id": user_id}
    )
    assert upload_resp.status_code == 201
    report_id = upload_resp.json()["id"]

    # 1. Stream Document
    stream_resp = client.get(
        f"/api/v1/farms/{farm_id}/soil-reports/{report_id}/document",
        headers={"X-Dev-User-Id": user_id}
    )
    assert stream_resp.status_code == 200
    assert stream_resp.content == pdf_content
    assert stream_resp.headers["content-type"] == "application/pdf"
    assert "inline" in stream_resp.headers["content-disposition"]

    # 2. Get Fresh Signed URL
    url_resp = client.get(
        f"/api/v1/farms/{farm_id}/soil-reports/{report_id}/document-url?expires_in_seconds=1800",
        headers={"X-Dev-User-Id": user_id}
    )
    assert url_resp.status_code == 200
    assert "signed_url" in url_resp.json()
    assert url_resp.json()["expires_in_seconds"] == 1800


def test_reprocess_soil_report(isolated_test_session):
    """Test retriggering document extraction clears unconfirmed measurements."""
    user_id = str(uuid.uuid4())
    farm_id = _create_test_farm(user_id)

    report_id = str(uuid.uuid4())
    report = SoilTestReportModel(
        id=report_id,
        user_id=user_id,
        farm_id=farm_id,
        original_filename="failed_ocr.pdf",
        storage_path=f"{farm_id}/{report_id}/failed_ocr.pdf",
        extraction_status=ExtractionStatus.FAILED.value,
        extraction_error="OCR parser timeout",
        review_status=ReviewStatus.NEEDS_REVIEW.value,
    )
    isolated_test_session.add(report)

    # Add an unconfirmed measurement
    m = SoilMeasurementModel(
        id=str(uuid.uuid4()),
        report_id=report_id,
        farm_id=farm_id,
        parameter_key="soil_ph",
        original_parameter_name="pH",
        original_value=5.5,
        original_unit="pH",
        verification_status=MeasurementVerificationStatus.EXTRACTED_UNVERIFIED.value,
    )
    isolated_test_session.add(m)
    isolated_test_session.commit()

    # Reprocess
    reprocess_resp = client.post(
        f"/api/v1/farms/{farm_id}/soil-reports/{report_id}/reprocess",
        headers={"X-Dev-User-Id": user_id}
    )
    assert reprocess_resp.status_code == 200
    rep_data = reprocess_resp.json()
    assert rep_data["extraction_status"] == ExtractionStatus.PROCESSING.value
    assert rep_data["extraction_error"] is None

    # Verify unconfirmed measurement was purged
    measurements_resp = client.get(
        f"/api/v1/farms/{farm_id}/soil-reports/{report_id}/measurements",
        headers={"X-Dev-User-Id": user_id}
    )
    assert len(measurements_resp.json()) == 0


# =========================================================================
# 6. Error Handling Tests (404s)
# =========================================================================

def test_not_found_errors():
    """Verify 404 responses for non-existent entities."""
    user_id = str(uuid.uuid4())
    farm_id = _create_test_farm(user_id)
    non_existent = str(uuid.uuid4())

    # Non-existent report
    resp = client.get(
        f"/api/v1/farms/{farm_id}/soil-reports/{non_existent}",
        headers={"X-Dev-User-Id": user_id}
    )
    assert resp.status_code == 404

    # Non-existent farm
    resp = client.get(
        f"/api/v1/farms/{non_existent}/soil-reports",
        headers={"X-Dev-User-Id": user_id}
    )
    assert resp.status_code == 404


def test_upload_real_pdf_triggers_ocr_and_inserts_measurements():
    """Upload representative Soil Health Card and verify OCR bridge inserts measurements."""
    user_id = str(uuid.uuid4())
    farm_id = _create_test_farm(user_id)

    pdf_path = Path(_worktree_root) / "services/api/tests/evaluation/soil_reports_corpus/tc01_shc_pune_digital.pdf"
    assert pdf_path.exists(), f"Corpus PDF missing at {pdf_path}"
    pdf_bytes = pdf_path.read_bytes()

    resp = client.post(
        f"/api/v1/farms/{farm_id}/soil-reports",
        files={"file": ("tc01_shc_pune_digital.pdf", io.BytesIO(pdf_bytes), "application/pdf")},
        headers={"X-Dev-User-Id": user_id}
    )
    assert resp.status_code == 201
    result = resp.json()
    assert result["extraction_status"] in (ExtractionStatus.PROCESSING.value, ExtractionStatus.NEEDS_REVIEW.value)
    assert result["review_status"] == ReviewStatus.NEEDS_REVIEW.value

    # Fetch updated report from DB after background processing completes
    detail_resp = client.get(
        f"/api/v1/farms/{farm_id}/soil-reports/{result['id']}",
        headers={"X-Dev-User-Id": user_id}
    )
    assert detail_resp.status_code == 200
    report_detail = detail_resp.json()
    assert report_detail["extraction_status"] == ExtractionStatus.NEEDS_REVIEW.value
    assert len(report_detail["measurements"]) > 0

    # Verify measurements are in EXTRACTED_UNVERIFIED status
    m_keys = [m["parameter_key"] for m in report_detail["measurements"]]
    assert "soil_ph" in m_keys
    assert "available_nitrogen" in m_keys
    for m in report_detail["measurements"]:
        assert m["verification_status"] == MeasurementVerificationStatus.EXTRACTED_UNVERIFIED.value

    # Verify reprocess re-extracts the document
    rep_resp = client.post(
        f"/api/v1/farms/{farm_id}/soil-reports/{result['id']}/reprocess",
        headers={"X-Dev-User-Id": user_id}
    )
    assert rep_resp.status_code == 200
    assert rep_resp.json()["extraction_status"] == ExtractionStatus.NEEDS_REVIEW.value
    assert len(rep_resp.json()["measurements"]) > 0
