from datetime import datetime, timezone
import zoneinfo

# Standard project timezone for farmer-facing outputs
IST_ZONE = zoneinfo.ZoneInfo("Asia/Kolkata")
UTC_ZONE = timezone.utc

def now_ist() -> datetime:
    """Return current timezone-aware timestamp in Asia/Kolkata (IST)."""
    return datetime.now(IST_ZONE)

def now_utc() -> datetime:
    """Return current timezone-aware timestamp in UTC."""
    return datetime.now(UTC_ZONE)

def to_ist(dt: datetime) -> datetime:
    """Convert any aware or naive datetime to Asia/Kolkata."""
    if dt.tzinfo is None:
        # Naive datetime is assumed UTC
        dt = dt.replace(tzinfo=UTC_ZONE)
    return dt.astimezone(IST_ZONE)

def to_utc(dt: datetime) -> datetime:
    """Convert any aware or naive datetime to UTC for storage."""
    if dt.tzinfo is None:
        # If naive, assume IST since inputs are farmer-facing
        dt = dt.replace(tzinfo=IST_ZONE)
    return dt.astimezone(UTC_ZONE)

def format_ist_iso(dt: datetime) -> str:
    """Format datetime as ISO 8601 string with explicit +05:30 offset."""
    return to_ist(dt).isoformat()

to_ist_iso = format_ist_iso
