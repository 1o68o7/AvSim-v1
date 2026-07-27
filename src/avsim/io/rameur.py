"""Données Vue Rameur (Surface Produit §3.1) — force, phase vs nage, progression.

Pas de comparaison entre rameurs hors poste de nage (référence bateau).
Grandeurs en watts = indice tant que D3 (traînée réelle) n'est pas calibré.
"""
from __future__ import annotations

import copy
from typing import Any

import numpy as np

from avsim.core.catalog import class_validation_status
from avsim.core.params import load_class
from avsim.core.solver import simulate
from avsim.io.events import STORE


def _catch_times_s(st) -> list[float]:
    t = np.asarray(st.t, dtype=float)
    n = int(st.handle_force.shape[0])
    out: list[float] = []
    for i in range(n):
        drive = np.asarray(st.immersion[i]) > 0.01
        if np.any(drive):
            out.append(float(t[np.where(drive)[0][0]] - t[0]))
        else:
            out.append(0.0)
    return out


def _series(a: np.ndarray) -> list[float]:
    return [float(x) for x in np.asarray(a).ravel()]


def seat_force_history(
    *,
    boat_class: str = "2x",
    seat: int = 1,
    n_prev: int = 10,
) -> dict[str, Any]:
    """Dernier coup + n_prev précédents : F(t) pour un poste, phase vs nage."""
    P = copy.deepcopy(load_class(boat_class))
    n_rowers = int(P["meta"]["n_rowers"])
    if seat < 1 or seat > n_rowers:
        raise ValueError(
            f"poste {seat} hors 1…{n_rowers} pour la classe {boat_class}"
        )
    need = n_prev + 1
    P["numerics"]["n_strokes"] = need + 4
    P["numerics"]["n_discard"] = 4
    res = simulate(P)
    start = max(0, res.n_keep - need)
    strokes: list[dict[str, Any]] = []
    for i in range(start, res.n_keep):
        st = res.stroke(i)
        t0 = float(st.t[0])
        t_rel = np.asarray(st.t, dtype=float) - t0
        F = np.asarray(st.handle_force[seat - 1], dtype=float)
        catches = _catch_times_s(st)
        # Poste 1 = nage (référence bateau, cf. defaults.yaml crew)
        lag_ms = (catches[seat - 1] - catches[0]) * 1000.0
        e_i = float(np.trapezoid(st.handle_power[seat - 1], st.t))
        T = float(st.energy()["stroke_period_s"])
        i_peak = int(np.argmax(np.abs(F)))
        strokes.append({
            "stroke_index": i,
            "t_s": _series(t_rel),
            "handle_force_N": _series(F),
            "F_peak_N": float(np.max(np.abs(F))),
            "t_peak_s": float(t_rel[i_peak]),
            "phase_lag_ms_vs_stroke": float(lag_ms),
            "P_mean_W": e_i / max(T, 1e-9),
            "cadence_spm": 60.0 / max(T, 1e-9),
        })
    last = strokes[-1] if strokes else None
    return {
        "source": "simulated",
        "boat_class": boat_class,
        "seat": seat,
        "stroke_seat": 1,
        "reference_label": "rameur de nage",
        "n_prev": n_prev,
        "strokes": strokes,
        "last_phase_lag_ms": None if last is None else last["phase_lag_ms_vs_stroke"],
        "last_P_mean_W": None if last is None else last["P_mean_W"],
        "power_calibration": {
            "status": "indice",
            "message": (
                "Puissance non calibrée — coefficient de traînée réel (D3) "
                "indisponible. Badge « indice », distinct de Simulé/Mesuré."
            ),
        },
        "boat": {
            "n_rowers": n_rowers,
            "sculling": bool(P["meta"].get("sculling", False)),
            "coxed": bool(P["meta"].get("coxed", False)),
        },
        "validation": class_validation_status(boat_class),
    }


def haptic_events_for_session(session_id: str) -> list[dict[str, Any]]:
    sess = STORE.get(session_id)
    if sess is None:
        raise KeyError(session_id)
    out: list[dict[str, Any]] = []
    for ev in sess.events:
        if ev.source != "haptic_alert":
            continue
        nearest = STORE.nearest_stroke_index(session_id, ev.t_utc)
        out.append({**ev.to_dict(), "nearest_stroke_index": nearest})
    return out


def progression_multi_session(
    *,
    boat_class: str = "2x",
    cadence_tol_spm: float = 2.0,
) -> dict[str, Any]:
    """Tendance multi-séances à cadence comparable — pas une valeur isolée.

    Métrique : P_rower_mean_W moyenne des marks (badge indice, D3 absent).
    Aucune comparaison entre rameurs.
    """
    summaries = STORE.list_sessions()
    points: list[dict[str, Any]] = []
    for s in summaries:
        if s["boat_class"] != boat_class:
            continue
        sess = STORE.get(s["session_id"])
        if sess is None or not sess.strokes:
            continue
        cads = [float(m.cadence_spm) for m in sess.strokes]
        powers = [
            float(m.energy["P_rower_mean_W"])
            for m in sess.strokes
            if m.energy and "P_rower_mean_W" in m.energy
        ]
        if not powers:
            continue
        points.append({
            "session_id": sess.session_id,
            "t_start_utc": sess.t_start_utc,
            "n_strokes": len(sess.strokes),
            "cadence_spm_mean": float(np.mean(cads)),
            "P_mean_W": float(np.mean(powers)),
        })
    points.sort(key=lambda p: p["t_start_utc"])

    trend: dict[str, Any] | None = None
    if len(points) >= 2:
        # Ancre = cadence de la dernière séance ; ne garder que les
        # séances dans ±cadence_tol (conditions comparables).
        anchor = points[-1]["cadence_spm_mean"]
        comparable = [
            p for p in points
            if abs(p["cadence_spm_mean"] - anchor) <= cadence_tol_spm
        ]
        if len(comparable) >= 2:
            first, last = comparable[0], comparable[-1]
            trend = {
                "n_sessions": len(comparable),
                "cadence_anchor_spm": anchor,
                "cadence_tol_spm": cadence_tol_spm,
                "P_first_W": first["P_mean_W"],
                "P_last_W": last["P_mean_W"],
                "delta_W": last["P_mean_W"] - first["P_mean_W"],
                "direction": (
                    "up" if last["P_mean_W"] > first["P_mean_W"] + 1e-9
                    else "down" if last["P_mean_W"] < first["P_mean_W"] - 1e-9
                    else "flat"
                ),
            }

    return {
        "source": "simulated",
        "boat_class": boat_class,
        "metric": "P_mean_W",
        "metric_badge": "indice",
        "points": points,
        "trend": trend,
        "note": (
            "Tendance sur plusieurs séances à cadence comparable. "
            "Puissance en indice (D3 non calibré) — pas une mesure absolue."
        ),
    }
