import pytest
from cropnet.services.api.app.services.rashkar.wbgt_solver import (
    calculate_wbgt,
    dew_point_c,
    vapor_pressure_kpa,
    actual_vapor_pressure_kpa
)

def test_vapor_pressure_and_dewpoint():
    # At 25°C and 50% RH:
    # es(25°C) ~ 3.167 kPa, ea ~ 1.58 kPa, dew point ~ 13.8°C
    es = vapor_pressure_kpa(25.0)
    assert 3.1 < es < 3.3
    ea = actual_vapor_pressure_kpa(25.0, 50.0)
    assert 1.5 < ea < 1.7
    dp = dew_point_c(25.0, 50.0)
    assert 13.0 < dp < 15.0

def test_wbgt_physical_bounds():
    # Hot dry summer afternoon (38°C, 25% RH, wind 2 m/s, 700 W/m² solar)
    res_sun = calculate_wbgt(
        temp_c=38.0,
        rh_pct=25.0,
        wind_speed_ms=2.0,
        solar_irradiance_wm2=700.0,
        in_sun=True
    )
    # Tg must be warmer than air temperature in strong sun
    assert res_sun["black_globe_temp_c"] > res_sun["air_temp_c"]
    # Natural wet bulb must be between dew point and dry bulb
    dp = dew_point_c(38.0, 25.0)
    assert res_sun["natural_wet_bulb_c"] > dp
    assert res_sun["natural_wet_bulb_c"] < res_sun["air_temp_c"]

def test_wbgt_sun_vs_shade():
    res_sun = calculate_wbgt(
        temp_c=35.0,
        rh_pct=50.0,
        wind_speed_ms=1.5,
        solar_irradiance_wm2=800.0,
        in_sun=True
    )
    res_shade = calculate_wbgt(
        temp_c=35.0,
        rh_pct=50.0,
        wind_speed_ms=1.5,
        solar_irradiance_wm2=800.0,
        in_sun=False
    )
    # Sun WBGT must exceed shade WBGT
    assert res_sun["wbgt_estimated_c"] > res_shade["wbgt_estimated_c"]
    assert res_sun["black_globe_temp_c"] > res_shade["black_globe_temp_c"]
