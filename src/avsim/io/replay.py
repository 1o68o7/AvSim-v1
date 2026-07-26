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


def stroke_frame(
    st,
    *,
    boat_class: str,
    stroke_index: int,
    distance_m: float = 0.0,
) -> dict[str, Any]:
    """Une trame coup — même grain que le flux matériel futur."""
    en = st.energy()
    T = float(en["stroke_period_s"])
    v_mean = float(en["v_mean_ms"])
    return {
        "kind": "stroke",
        "source": "simulated",
        "boat_class": boat_class,
        "stroke_index": stroke_index,
        "T_s": T,
        "cadence_spm": 60.0 / max(T, 1e-9),
        "v_ms": v_mean,
        "distance_m": float(distance_m),
        "energy": phase2_metrics(st),
        "series": {
            "t_s": [float(x) for x in st.t],
            "V_ms": [float(x) for x in st.V],
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
        )
        yield frame
        if realtime:
            delay = float(frame["T_s"]) - (time.perf_counter() - t0)
            if delay > 0:
                _sleep(delay)
