"""Métriques Phase 1 (§9.2) — une seule source pour plausibility / scaling.

Enveloppe §3.3 (rejet structurel) et plausibilité §9.2 (cible plus stricte)
sont voulues distinctes ; les métriques portent les deux pour que
test_plausibility enchaîne is_admissible → bornes §9.2.
"""
from __future__ import annotations

from typing import Any

import numpy as np

from avsim.core.boat_class import BoatClass
from avsim.core.catalog import V_REF_MS
from avsim.core.envelope import check_inputs, check_outputs, is_admissible
from avsim.core.geometry import blade_normal_speed
from avsim.core.params import load_class
from avsim.core.solver import simulate

# Brief §9.2 — régime établi (pas le stopgap diagnostic n_strokes=6).
N_STROKES = 20
N_DISCARD = 10

ALL_CLASSES = ("1x", "2-", "2x", "4-", "4x", "4+", "8+", "8x")
VALIDATED = frozenset({"8+", "1x"})
BETA = frozenset(c for c in ALL_CLASSES if c not in VALIDATED)

# η≈0,62 sur 8+/1x : écart connu modèle 1DOF (STATE.md, ROADMAP Phase 1).
# Pas un assouplissement de seuil — xfail documenté si hors bande.
KNOWN_ETA_GAP_CLASSES = frozenset({"8+", "1x"})

_CACHE: dict[tuple[str, int, int], dict[str, Any]] = {}


def check_factor_band(code: str) -> tuple[float, float]:
    """Peak-to-peak V_max−V_min ; brief ±0,25–0,40 (8+) → 0,50–0,80 ; 1x jusqu'à ±0,50."""
    if code == "8+":
        return (0.50, 0.80)
    if code == "1x":
        return (0.50, 1.00)
    return (0.50, 1.00)


def steady_stroke_metrics(
    code: str,
    *,
    n_strokes: int = N_STROKES,
    n_discard: int = N_DISCARD,
) -> dict[str, Any]:
    key = (code, n_strokes, n_discard)
    if key in _CACHE:
        return _CACHE[key]

    P = load_class(code)
    P["numerics"]["n_strokes"] = int(n_strokes)
    P["numerics"]["n_discard"] = int(n_discard)
    cls = BoatClass.from_params(P)
    res = simulate(P)
    st = res.last_stroke()
    en = st.energy()

    E_h = en["E_hull_drag_J"]
    E_b = en["E_blade_loss_J"]
    E_a = en["E_aero_J"]
    denom = E_h + E_b + E_a
    if denom <= 0:
        part_h = part_b = part_a = float("nan")
    else:
        part_h, part_b, part_a = E_h / denom, E_b / denom, E_a / denom

    # Glissement moyen |v_n| pendant le drive (poste 0, représentatif si sync).
    L_out = float(P["rig"]["L_out_m"])
    vn = blade_normal_speed(st.theta[0], st.theta_dot[0], st.V, L_out)
    drive = st.immersion[0] > 0.01
    slip = float(np.abs(vn[drive]).mean()) if drive.any() else float("nan")

    env_violations = check_inputs(P, cls) + check_outputs(res, P, cls)

    v_ref = V_REF_MS[code]
    out = {
        "code": code,
        "status": "validated" if code in VALIDATED else "beta",
        "v_ref_ms": v_ref,
        "v_mean_ms": en["v_mean_ms"],
        "P_rower_mean_W": en["P_rower_mean_W"],
        "eta_blade": en["eta_blade"],
        "part_hydro": float(part_h),
        "part_blade": float(part_b),
        "part_aero": float(part_a),
        "check_factor": en["check_factor"],
        "slip_mean_ms": slip,
        "energy": en,
        "envelope_violations": env_violations,
        "envelope_admissible": is_admissible(env_violations),
    }
    _CACHE[key] = out
    return out
