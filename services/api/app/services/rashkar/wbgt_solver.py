"""
Liljegren et al. (2008) Outdoor & Indoor Wet Bulb Globe Temperature (WBGT) Solver.

Reference:
    Liljegren, J. C., Carhart, R. A., Lawday, P., Tschopp, S., & Sharp, R. (2008).
    Modeling the Wet Bulb Globe Temperature Using Standard Meteorological Measurements.
    Journal of Occupational and Environmental Hygiene, 5(10), 645-655.
    DOI: 10.1080/15459620802310770

Physical constants and equations:
    - Natural wet bulb temperature (Tnw): Energy balance on unventilated cylindrical wick
      accounting for convective heat transfer, radiative exchange, latent heat of vaporization,
      and solar irradiance absorption.
    - Black globe temperature (Tg): Energy balance on a standard matte-black globe
      accounting for convective dissipation, shortwave solar radiation, and longwave IR radiation.
    - WBGT Outdoor: 0.7 * Tnw + 0.2 * Tg + 0.1 * Ta
    - WBGT Shade/Indoor: 0.7 * Tnw + 0.3 * Tg
"""

import math
from typing import Dict, Any

# Physical constants
STEFAN_BOLTZMANN = 5.670374e-8  # W / (m^2 * K^4)
STANDARD_PRESSURE_KPA = 101.325 # kPa at sea level

def vapor_pressure_kpa(temp_c: float) -> float:
    """
    Saturated vapor pressure using Buck (1981) formula.
    Accurate to +/- 0.05% over -20°C to +50°C.
    """
    return 0.61121 * math.exp((17.502 * temp_c) / (temp_c + 240.97))

def actual_vapor_pressure_kpa(temp_c: float, rh_pct: float) -> float:
    """Actual vapor pressure in kPa from air temperature (°C) and RH (%)."""
    rh_bounded = max(1.0, min(100.0, rh_pct))
    return (rh_bounded / 100.0) * vapor_pressure_kpa(temp_c)

def dew_point_c(temp_c: float, rh_pct: float) -> float:
    """Calculates dew point (°C) using Magnus-Tetens approximation."""
    ea = actual_vapor_pressure_kpa(temp_c, rh_pct)
    alpha = math.log(max(1e-5, ea / 0.61121))
    return (240.97 * alpha) / (17.502 - alpha)

def solve_natural_wet_bulb(
    temp_c: float,
    rh_pct: float,
    wind_speed_ms: float,
    solar_irradiance_wm2: float,
    pressure_kpa: float = STANDARD_PRESSURE_KPA
) -> float:
    """
    Solves for natural wet bulb temperature (Tnw) in °C using heat balance iteration.
    For an unventilated natural wet-bulb wick:
      h_c * (Ta - Tnw) + F_rad + F_sol - (h_c / gamma) * (e_s(Tnw) - e_a) = 0
    """
    ea = actual_vapor_pressure_kpa(temp_c, rh_pct)
    u = max(0.15, wind_speed_ms)  # Bound min wind to avoid zero-division in natural convection
    ta_k = temp_c + 273.15

    # Wick cylinder diameter = 0.007 m (Liljegren standard 7mm diameter)
    d_wick = 0.007
    alpha_wick = 0.4  # Solar absorptivity of natural wet cotton wick

    # Convective heat transfer coefficient (hc) for cross-flow cylinder
    hc = max(15.0, 12.0 * (u ** 0.6) / (d_wick ** 0.4))
    
    # Psychrometric constant gamma (kPa / K)
    gamma = 0.00066 * pressure_kpa

    # Net shortwave solar absorption per unit area:
    q_solar = alpha_wick * max(0.0, solar_irradiance_wm2) * 0.5  # Cylinder projected profile factor

    # Bounded interval for bisection
    t_low = dew_point_c(temp_c, rh_pct) - 1.0
    t_high = temp_c + max(0.0, (q_solar / hc)) + 5.0

    def balance(tnw: float) -> float:
        es_tnw = vapor_pressure_kpa(tnw)
        sensible = hc * (temp_c - tnw)
        latent = (hc / gamma) * (es_tnw - ea)
        tnw_k = tnw + 273.15
        rad = 0.95 * STEFAN_BOLTZMANN * (ta_k ** 4 - tnw_k ** 4)
        return sensible + rad + q_solar - latent

    # Numerical solver: 25 bisection steps is accurate to ~0.005°C
    for _ in range(25):
        t_mid = 0.5 * (t_low + t_high)
        f_mid = balance(t_mid)
        if balance(t_low) * f_mid <= 0:
            t_high = t_mid
        else:
            t_low = t_mid
        if abs(t_high - t_low) < 0.01:
            break

    return round(0.5 * (t_low + t_high), 2)

def solve_black_globe_temp(
    temp_c: float,
    wind_speed_ms: float,
    solar_irradiance_wm2: float
) -> float:
    """
    Solves for 5cm standard matte-black globe temperature (Tg) in °C.
    Energy balance:
      hc_globe * (Tg - Ta) = alpha_globe * S_w / 4 + epsilon_globe * sigma * (T_rad^4 - Tg^4)
    """
    u = max(0.15, wind_speed_ms)
    ta_k = temp_c + 273.15
    d_globe = 0.05  # 50mm globe (standard portable sensor size)
    alpha_globe = 0.95
    epsilon_globe = 0.95

    # Convection coefficient for sphere
    hc = max(10.0, 6.3 * (u ** 0.6) / (d_globe ** 0.4))
    q_solar = (alpha_globe * max(0.0, solar_irradiance_wm2)) / 4.0

    # Iterative solution:
    tg_c = temp_c + (q_solar / hc)  # Initial guess
    for _ in range(20):
        tg_k = tg_c + 273.15
        f = hc * (tg_c - temp_c) + epsilon_globe * STEFAN_BOLTZMANN * (tg_k ** 4 - ta_k ** 4) - q_solar
        df = hc + 4.0 * epsilon_globe * STEFAN_BOLTZMANN * (tg_k ** 3)
        step = f / df
        tg_c -= step
        if abs(step) < 0.005:
            break

    return round(tg_c, 2)

def calculate_wbgt(
    temp_c: float,
    rh_pct: float,
    wind_speed_ms: float = 1.5,
    solar_irradiance_wm2: float = 600.0,
    in_sun: bool = True,
    pressure_kpa: float = STANDARD_PRESSURE_KPA
) -> Dict[str, Any]:
    """
    Calculates estimated WBGT (°C), natural wet bulb (Tnw), and black globe temp (Tg).
    Provides both outdoor (with solar) and shade values.
    """
    actual_solar = max(0.0, solar_irradiance_wm2) if in_sun else 0.0

    tnw = solve_natural_wet_bulb(
        temp_c=temp_c,
        rh_pct=rh_pct,
        wind_speed_ms=wind_speed_ms,
        solar_irradiance_wm2=actual_solar,
        pressure_kpa=pressure_kpa
    )

    tg = solve_black_globe_temp(
        temp_c=temp_c,
        wind_speed_ms=wind_speed_ms,
        solar_irradiance_wm2=actual_solar
    )

    if in_sun and actual_solar > 20.0:
        # Standard outdoor WBGT formulation
        wbgt_est = 0.7 * tnw + 0.2 * tg + 0.1 * temp_c
    else:
        # Indoor or complete shaded WBGT formulation
        wbgt_est = 0.7 * tnw + 0.3 * tg

    return {
        "wbgt_estimated_c": round(wbgt_est, 2),
        "natural_wet_bulb_c": round(tnw, 2),
        "black_globe_temp_c": round(tg, 2),
        "air_temp_c": round(temp_c, 2),
        "relative_humidity_pct": round(rh_pct, 1),
        "wind_speed_ms": round(wind_speed_ms, 2),
        "solar_irradiance_wm2": round(actual_solar, 1),
        "in_sun": in_sun,
        "calculation_method": "Liljegren_et_al_2008_numerical_solver"
    }
