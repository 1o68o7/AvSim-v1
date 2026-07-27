"""Barre de longueur de coup — brief-visuels-coaching-sources.md §1.

Seuil d'immersion effective : ``immersion > 0.5`` — même convention que
``Stroke.drive_mask`` (palette effectivement en prise). Le catch slip
angulaire (dynamics) produit le blanc initial ; la fenêtre leave produit
le blanc de sortie (washing out).

Pas de nesting / poisson / Team 4Q ici — étape 1 seule.
"""
from __future__ import annotations

from typing import Any

import numpy as np

# Seuil déjà utilisé par Stroke.drive_mask — immersion « effective ».
IMMERSION_EFFECTIVE = 0.5


def seat_u(theta: np.ndarray, th_catch: float, th_finish: float) -> np.ndarray:
    arc = max(float(th_catch - th_finish), 1e-9)
    return np.clip((th_catch - np.asarray(theta, dtype=float)) / arc, 0.0, 1.0)


def stroke_length_bar(
    theta: np.ndarray,
    immersion: np.ndarray,
    *,
    th_catch: float,
    th_finish: float,
    L_slide_m: float,
) -> dict[str, float]:
    """Métriques barre Peach/FM.

    - ``length_norm`` : arc réalisé / arc nominal (proxy course de coulisse)
    - ``catch_white`` : avant immersion effective (catch mou / slip)
    - ``immersed`` : immersion > 0.5
    - ``finish_white`` : après fin d'immersion effective (washing out)
    """
    th = np.asarray(theta, dtype=float)
    imm = np.asarray(immersion, dtype=float)
    u = seat_u(th, th_catch, th_finish)
    # Propulsion seule : u croît catch→finish ; le retour redescend u.
    in_drive = imm > 0.01
    effective = in_drive & (imm >= IMMERSION_EFFECTIVE)
    if effective.any():
        u0 = float(np.min(u[effective]))
        u1 = float(np.max(u[effective]))
    else:
        u0, u1 = 0.0, 0.0
    catch_white = float(np.clip(u0, 0.0, 1.0))
    finish_white = float(np.clip(1.0 - u1, 0.0, 1.0))
    immersed = float(np.clip(u1 - u0, 0.0, 1.0))
    s = catch_white + immersed + finish_white
    if s > 1e-9:
        catch_white /= s
        immersed /= s
        finish_white /= s
    nominal = max(float(th_catch - th_finish), 1e-9)
    if in_drive.any():
        realized = float(np.max(th[in_drive]) - np.min(th[in_drive]))
    else:
        realized = 0.0
    length_norm = float(np.clip(realized / nominal, 0.05, 1.25))
    return {
        "length_norm": length_norm,
        "catch_white": catch_white,
        "immersed": immersed,
        "finish_white": finish_white,
        "catch_angle_deg": float(np.degrees(th_catch)),
        "L_slide_m": float(L_slide_m),
        "immersion_threshold": float(IMMERSION_EFFECTIVE),
    }


def crew_stroke_bars(st: Any, P: dict[str, Any]) -> list[dict[str, Any]]:
    """Une barre par poste — enrichissement crew pour API / SSE."""
    n = int(st.handle_force.shape[0])
    th_c = float(np.radians(P["rig"]["theta_catch_deg"]))
    th_f = float(np.radians(P["rig"]["theta_finish_deg"]))
    L_slide = float(P["rig"]["L_slide_m"])
    t = np.asarray(st.t, dtype=float)
    T = float(st.energy()["stroke_period_s"])
    offsets = P.get("crew", {}).get("phase_offset_ms", [0.0] * n)
    rows: list[dict[str, Any]] = []
    for i in range(n):
        off = float(offsets[i]) if i < len(offsets) else 0.0
        e_i = float(np.trapezoid(st.handle_power[i], t))
        bar = stroke_length_bar(
            st.theta[i],
            st.immersion[i],
            th_catch=th_c,
            th_finish=th_f,
            L_slide_m=L_slide,
        )
        rows.append({
            "seat": i + 1,
            "phase_offset_ms": off,
            "E_handle_J": e_i,
            "P_mean_W": e_i / max(T, 1e-9),
            "stroke_bar": bar,
        })
    return rows
