"""Efforts hydrodynamiques : palette, coque, air.

Brief 3.4, 3.5, 3.6.
"""
from __future__ import annotations

import csv
from functools import lru_cache
from pathlib import Path

import numpy as np

from .geometry import angle_of_attack, blade_normal, blade_velocity_water

_DATA = Path(__file__).resolve().parents[3] / "data"


# --------------------------------------------------------------- fluides
def rho_water(T_C):
    """Masse volumique de l'eau douce. Ajustement quadratique 0-30 C."""
    return 1000.0 * (1.0 - 7.0e-6 * (np.asarray(T_C, float) - 4.0) ** 2)


def nu_water(T_C):
    """Viscosite cinematique de l'eau douce, m2/s. Ajustement 0-30 C.

    Varie d'environ 35 % entre 5 et 25 C : c'est ce qui rend la temperature
    d'eau non negligeable sur C_f (brief 3.4).
    """
    T = np.asarray(T_C, float)
    return 1.0e-6 * (1.79 / (1.0 + 0.0337 * T + 0.000221 * T * T))


def rho_air(T_C, p_hPa, rh_pct):
    """Masse volumique de l'air humide (approximation de Tetens pour p_vap)."""
    T = np.asarray(T_C, float)
    p_sat = 6.1078 * 10 ** (7.5 * T / (T + 237.3))          # hPa
    p_v = np.clip(rh_pct, 0, 100) / 100.0 * p_sat
    p_d = np.asarray(p_hPa, float) - p_v
    return (p_d * 100 / (287.058 * (T + 273.15))
            + p_v * 100 / (461.495 * (T + 273.15)))


# --------------------------------------------------------------- palette
@lru_cache(maxsize=1)
def _blade_table():
    a, cl, cd = [], [], []
    with open(_DATA / "blade_coefficients.csv", encoding="utf-8") as fh:
        for row in csv.DictReader(l for l in fh if not l.startswith("#")):
            a.append(float(row["alpha_deg"]))
            cl.append(float(row["C_L"]))
            cd.append(float(row["C_D"]))
    return np.radians(a), np.array(cl), np.array(cd)


def blade_coefficients(alpha):
    a, cl, cd = _blade_table()
    return np.interp(alpha, a, cl), np.interp(alpha, a, cd)


def blade_force(theta, theta_dot, V, P, rho_w, immersion=1.0):
    """Effort hydrodynamique de l'eau SUR la palette, en (fx, fy).

    `immersion` in [0,1] lisse l'entree et la sortie de palette.
    Retourne aussi la puissance dissipee dans l'eau (positive = perte).
    """
    L_out = P["rig"]["L_out_m"]
    A = P["rig"]["A_blade_m2"]

    vx, vy = blade_velocity_water(theta, theta_dot, V, L_out)
    speed = np.hypot(vx, vy)
    alpha = angle_of_attack(theta, vx, vy)
    C_L, C_D = blade_coefficients(alpha)

    q = 0.5 * rho_w * A * speed ** 2 * immersion
    safe = np.where(speed > 1e-9, speed, 1.0)
    ux, uy = vx / safe, vy / safe

    # trainee : opposee au mouvement de la palette dans l'eau
    fdx, fdy = -C_D * q * ux, -C_D * q * uy
    # portance : perpendiculaire a l'ecoulement, orientee du cote de la normale.
    # C_L est SIGNE : au-dela de 90 deg d'incidence il devient negatif et la
    # portance tourne de 180 deg (Caplan & Gardner 2007).
    px, py = -uy, ux
    nx, ny = blade_normal(theta)
    sign = np.where(px * nx + py * ny >= 0.0, 1.0, -1.0)
    flx, fly = C_L * q * px * sign, C_L * q * py * sign

    fx, fy = fdx + flx, fdy + fly
    # puissance cedee a l'eau par la palette (perte)
    p_loss = -(fx * vx + fy * vy)
    return fx, fy, p_loss, alpha, speed


# --------------------------------------------------------------- coque
def hull_drag(V, P, rho_w, nu_w):
    """Trainee de coque. Modele 'simple' (calibrable) ou 'ittc' (physique)."""
    model = P["numerics"]["drag_model"]
    V = np.asarray(V, float)
    if model == "simple":
        n = P["boat"]["drag_exponent"]
        return P["boat"]["k_drag"] * np.abs(V) ** n * np.sign(V)

    L = P["boat"]["L_wl_m"]
    Re = np.maximum(np.abs(V) * L / nu_w, 1.0e4)
    C_f = 0.075 / (np.log10(Re) - 2.0) ** 2
    D_f = 0.5 * rho_w * P["boat"]["S_wet_m2"] * C_f * P["boat"]["form_factor"] * V ** 2
    Fr = np.abs(V) / np.sqrt(9.81 * L)
    D_w = 0.5 * rho_w * P["boat"]["S_wet_m2"] * (0.15 * Fr ** 4) * V ** 2
    return (D_f + D_w) * np.sign(V)


def aero_drag(V_ground, P, rho_a, wind_axial):
    """Trainee aerodynamique sur le vent apparent. Vent de face = axial positif."""
    V_app = np.asarray(V_ground, float) + wind_axial
    return 0.5 * rho_a * P["boat"]["CdA_m2"] * V_app ** 2 * np.sign(V_app), V_app
