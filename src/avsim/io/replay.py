"""Flux rejeu coup-à-coup — partagé CLI `avsim replay` et API SSE.

Même grain NDJSON (`kind=stroke`, `source=simulated`) pour la Surface
Produit. Aucune nouvelle physique : métriques via Stroke.energy().
"""
from __future__ import annotations

import time
from collections.abc import Callable, Iterator
from typing import Any

import numpy as np

from avsim.core.solver import Result
from avsim.io.coaching_viz import crew_coaching_payload

# Six grandeurs Phase 2 / §9.2 déjà dans Stroke.energy() — affichage seul.
PHASE2_KEYS = (
    "v_mean_ms",
    "P_rower_mean_W",
    "eta_blade",
    "check_factor",
    "v_min_ms",
    "v_max_ms",
)


def phase2_metrics(stroke) -> dict[str, float]:
    en = stroke.energy()
    return {k: float(en[k]) for k in PHASE2_KEYS}


def _crew_density(st, P: dict[str, Any] | None) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    """Densité par poste pour Coach live — force, timing, décalage brut.

    Aucun seuil de significativité (Mode D absent) : on signale seulement
    le poste au plus grand |timing_ms| vs médiane d'attaque du coup.
    """
    n = int(st.handle_force.shape[0])
    t = np.asarray(st.t, dtype=float)
    T = float(st.energy()["stroke_period_s"])
    offsets = (P or {}).get("crew", {}).get("phase_offset_ms", [0.0] * n)
    catch_t: list[float] = []
    for i in range(n):
        drive = np.asarray(st.immersion[i]) > 0.01
        if np.any(drive):
            catch_t.append(float(t[np.where(drive)[0][0]]))
        else:
            catch_t.append(float(t[0]))
    t_med = float(np.median(catch_t)) if catch_t else float(t[0])
    seats: list[dict[str, Any]] = []
    alert_seat = 1
    alert_lag = 0.0
    for i in range(n):
        F_peak = float(np.max(np.abs(st.handle_force[i])))
        e_i = float(np.trapezoid(st.handle_power[i], t))
        timing_ms = (catch_t[i] - t_med) * 1000.0
        off = float(offsets[i]) if i < len(offsets) else 0.0
        if abs(timing_ms) >= abs(alert_lag):
            alert_lag = timing_ms
            alert_seat = i + 1
        seats.append({
            "seat": i + 1,
            "F_peak_N": F_peak,
            "P_mean_W": e_i / max(T, 1e-9),
            "phase_offset_ms": off,
            "timing_ms": timing_ms,
        })
    sync = {
        "seat": alert_seat,
        "timing_ms": alert_lag,
        "note": (
            "Décalage brut vs médiane d'attaque — signification non calibrée "
            "(Mode D / Détectabilité non disponible)."
        ),
    }
    return seats, sync


def stroke_frame(
    st,
    *,
    boat_class: str,
    stroke_index: int,
    distance_m: float = 0.0,
    params: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Une trame coup — même grain que le flux matériel futur."""
    en = st.energy()
    T = float(en["stroke_period_s"])
    v_mean = float(en["v_mean_ms"])
    P = params if params is not None else getattr(st, "P", None)
    if P is None:
        # Result.stroke ne porte pas P — le caller passe params=
        P = {}
    crew, sync = _crew_density(st, P)
    # Longueur d'arc réalisée (poste 0) : Δθ drive en degrés
    th0 = np.degrees(np.asarray(st.theta[0], dtype=float))
    drive0 = np.asarray(st.immersion[0]) > 0.01
    if np.any(drive0):
        arc_deg = float(np.max(th0[drive0]) - np.min(th0[drive0]))
    else:
        arc_deg = float(np.max(th0) - np.min(th0)) if th0.size else 0.0
    phase_lag_ms = float(abs(sync["timing_ms"]))
    # Enrichissement coaching (barres / nesting / poisson) — même source
    coaching = crew_coaching_payload(st, P) if P else []
    # Fusion densité Coach live + métriques barre
    by_seat = {c["seat"]: c for c in coaching}
    crew_rich = []
    for row in crew:
        extra = by_seat.get(row["seat"], {})
        crew_rich.append({
            **row,
            "stroke_bar": extra.get("stroke_bar"),
            "drive": extra.get("drive"),
            "fish": extra.get("fish"),
        })
    t = np.asarray(st.t, dtype=float)
    V = np.asarray(st.V, dtype=float)
    A = np.gradient(V, t) if t.size > 1 else np.zeros_like(V)
    th0 = np.asarray(st.theta[0], dtype=float)
    w0 = np.asarray(st.theta_dot[0], dtype=float)
    return {
        "kind": "stroke",
        "source": "simulated",
        "boat_class": boat_class,
        "stroke_index": stroke_index,
        "T_s": T,
        "cadence_spm": 60.0 / max(T, 1e-9),
        "v_ms": v_mean,
        "distance_m": float(distance_m),
        "arc_deg": arc_deg,
        "phase_lag_ms": phase_lag_ms,
        "check_factor": float(en["check_factor"]),
        "P_rower_mean_W": float(en.get("P_rower_mean_W", 0.0)),
        "energy": phase2_metrics(st),
        "crew": crew_rich,
        "sync_alert": sync,
        "series": {
            "t_s": [float(x) for x in t],
            "V_ms": [float(x) for x in V],
            "A_ms2": [float(x) for x in A],
            "theta_deg": [float(x) for x in np.degrees(th0)],
            "theta_dot_deg_s": [float(x) for x in np.degrees(w0)],
            "handle_force_N": [float(x) for x in st.handle_force[0]],
        },
    }


def stroke_distance_m(st) -> float:
    """Distance parcourue sur le coup (∫ V dt)."""
    t = np.asarray(st.t, dtype=float)
    V = np.asarray(st.V, dtype=float)
    if t.size < 2:
        return 0.0
    return float(np.trapezoid(V, t))


def iter_stroke_frames(
    res: Result,
    *,
    boat_class: str,
    realtime: bool = True,
    sleep: Callable[[float], None] | None = None,
) -> Iterator[dict[str, Any]]:
    """Enchaîne les coups gardés ; si realtime, cadence à T (stroke_period)."""
    _sleep = sleep or time.sleep
    distance = 0.0
    for i in range(res.n_keep):
        t0 = time.perf_counter()
        st = res.stroke(i)
        distance += stroke_distance_m(st)
        frame = stroke_frame(
            st,
            boat_class=boat_class,
            stroke_index=i,
            distance_m=distance,
            params=res.P,
        )
        yield frame
        if realtime:
            delay = float(frame["T_s"]) - (time.perf_counter() - t0)
            if delay > 0:
                _sleep(delay)
