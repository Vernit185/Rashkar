"""
RASHKAR — 30-Minute Cadence Forecast Scheduler & Shared Forecast Grid Cache.

Implements presentation architecture (Slides 3, 5 & 6):
1. 'Predict heat risk at 1 km resolution every 30 minutes, with a 0-6 hour forecast.'
2. '1 forecast grid serves multiple nearby farms.'
3. Cloud-only, zero hardware architecture.
4. Manages alert state lifecycle: generated -> delivered -> acknowledged -> updated -> expired.
"""

import time
import math
from datetime import datetime, timedelta, timezone
from typing import Dict, Any, Optional, Tuple, List
from cropnet.services.api.app.services.rashkar.timezone import now_utc


class ForecastGridCache:
    """
    In-memory spatial grid cache with 30-minute validity window.
    Groups coordinates by 0.1 degree resolution (~11 km), enabling multiple
    adjacent smallholder farms to share atmospheric NWP retrievals while
    running individualized farm-level elevation downscaling and worker personalizations.
    """

    def __init__(self, cache_ttl_seconds: int = 1800):
        # 1800s = 30 minutes cadence
        self.cache_ttl_seconds = cache_ttl_seconds
        self._grid_store: Dict[str, Dict[str, Any]] = {}
        self._alerts_store: Dict[str, Dict[str, Any]] = {}

    @staticmethod
    def get_grid_cell_key(latitude: float, longitude: float) -> str:
        """
        Rounds lat/lon to 0.1 degree grid bin (~11.1 km at equator).
        """
        grid_lat = round(latitude, 1)
        grid_lon = round(longitude, 1)
        return f"grid_{grid_lat:.1f}_{grid_lon:.1f}"

    def get_cached_forecast(self, latitude: float, longitude: float) -> Optional[Dict[str, Any]]:
        """
        Retrieves cached forecast payload if still within 30-minute validity.
        """
        grid_key = self.get_grid_cell_key(latitude, longitude)
        entry = self._grid_store.get(grid_key)
        if not entry:
            return None

        current_time = time.time()
        if current_time > entry["expires_at_epoch"]:
            # Expired
            return None

        # Return cached entry with remaining TTL
        entry["seconds_until_refresh"] = max(0, int(entry["expires_at_epoch"] - current_time))
        return entry

    def store_forecast(
        self,
        latitude: float,
        longitude: float,
        raw_weather_data: Dict[str, Any],
        source_model: str = "Open-Meteo GFS/ICON Global Seamless",
        base_grid_resolution_km: float = 11.0,
    ) -> Dict[str, Any]:
        """
        Stores atmospheric forecast for the grid cell with a 30-minute validity timestamp.
        """
        grid_key = self.get_grid_cell_key(latitude, longitude)
        current_epoch = time.time()
        expires_at_epoch = current_epoch + self.cache_ttl_seconds
        current_time_utc = now_utc()
        expires_at_utc = current_time_utc + timedelta(seconds=self.cache_ttl_seconds)

        cycle_id = f"cycle_{grid_key}_{int(current_epoch // 1800)}"

        entry = {
            "grid_key": grid_key,
            "cycle_id": cycle_id,
            "latitude_grid": round(latitude, 1),
            "longitude_grid": round(longitude, 1),
            "retrieved_at_utc": current_time_utc.isoformat(),
            "expires_at_utc": expires_at_utc.isoformat(),
            "expires_at_epoch": expires_at_epoch,
            "seconds_until_refresh": self.cache_ttl_seconds,
            "refresh_cadence_minutes": 30,
            "source_model": source_model,
            "base_grid_resolution_km": base_grid_resolution_km,
            "target_downscaled_resolution_km": 1.0,
            "raw_weather": raw_weather_data,
        }
        self._grid_store[grid_key] = entry
        return entry

    def register_alert(
        self,
        farm_id: str,
        alert_type: str,
        severity_level: str,
        message: str,
        score_0_100: float,
        valid_until_utc: datetime,
    ) -> Dict[str, Any]:
        """
        Registers an alert into the alert lifecycle tracking system.
        Lifecycle: generated -> delivered -> acknowledged -> updated -> expired
        """
        alert_id = f"alt_{farm_id}_{int(time.time())}"
        alert_payload = {
            "alert_id": alert_id,
            "farm_id": farm_id,
            "alert_type": alert_type,
            "severity_level": severity_level,
            "score_0_100": score_0_100,
            "message": message,
            "state": "generated",
            "created_at_utc": now_utc().isoformat(),
            "valid_until_utc": valid_until_utc.isoformat(),
            "delivery_channels": ["app_dashboard", "sms_simulated", "ivr_ready"],
        }
        self._alerts_store[alert_id] = alert_payload
        return alert_payload

    def update_alert_state(self, alert_id: str, new_state: str) -> Optional[Dict[str, Any]]:
        """
        Updates alert lifecycle state (e.g., 'acknowledged', 'expired').
        """
        valid_states = {"generated", "delivered", "acknowledged", "updated", "expired"}
        if new_state not in valid_states:
            raise ValueError(f"Invalid state: {new_state}. Valid states: {valid_states}")
        
        alert = self._alerts_store.get(alert_id)
        if not alert:
            return None
        
        alert["state"] = new_state
        alert["state_updated_at_utc"] = now_utc().isoformat()
        return alert

    def get_farm_active_alerts(self, farm_id: str) -> List[Dict[str, Any]]:
        """
        Returns all non-expired alerts for a specific farm.
        """
        now = now_utc()
        active = []
        for alert in self._alerts_store.values():
            if alert["farm_id"] == farm_id:
                valid_until = datetime.fromisoformat(alert["valid_until_utc"])
                if valid_until > now and alert["state"] != "expired":
                    active.append(alert)
        return active


# Global singleton instance for runtime application
grid_scheduler_cache = ForecastGridCache(cache_ttl_seconds=1800)
