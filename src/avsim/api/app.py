"""Application FastAPI — brief interface utilisateur §1 / brief-simulateur §10."""
from __future__ import annotations

import copy
from typing import Any

import numpy as np
from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from avsim.core.catalog import (
    TARGETS_9_2,
    V_REF_MS,
    class_validation_status,
    list_classes,
    list_hull_moulds,
    load_class_annotated,
)
from avsim.core.params import load_class
from avsim.core.pose import pose_at_u, pose_series
from avsim.core.solver import simulate

from .roles import Role, analyst_only, require_role

app = FastAPI(
    title="DataR0w avsim API",
    version="0.1.0",
    description="Deux surfaces (Analyste / Produit), un moteur. Sorties = Simulé.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class SimulateRequest(BaseModel):
    boat_class: str
    hull_builder: str | None = None
    hull_mould: str | None = None
    overrides: dict[str, Any] = Field(default_factory=dict)
    n_strokes: int = 6
    n_discard: int = 2
    stroke_index: int = -1  # dernier coup gardé


def _apply_overrides(P: dict, overrides: dict[str, Any]) -> dict:
    """Surcharges 'section.key' ou nested dict — ne touche pas aux YAML disque."""
    out = copy.deepcopy(P)
    for key, val in overrides.items():
        if "." in key:
            sec, _, name = key.partition(".")
            if sec not in out or not isinstance(out[sec], dict):
                raise HTTPException(400, f"override inconnu : {key}")
            out[sec][name] = val
        elif isinstance(val, dict) and isinstance(out.get(key), dict):
            out[key].update(val)
        else:
            out[key] = val
    return out


def _series(a: np.ndarray) -> list[float]:
    return [float(x) for x in np.asarray(a).ravel()]


def _stroke_payload(st, idx: int, P: dict) -> dict[str, Any]:
    en = st.energy()
    t = st.t
    th0 = st.theta[0]
    fh0 = st.handle_force[0]
    imm0 = st.immersion[0]
    th_c = float(np.radians(P["rig"]["theta_catch_deg"]))
    th_f = float(np.radians(P["rig"]["theta_finish_deg"]))
    arc = max(th_c - th_f, 1e-9)
    u = np.clip((th_c - th0) / arc, 0.0, 1.0)
    drive = imm0 > 0.01
    T_drive = float("nan")
    if drive.any():
        ix = np.where(drive)[0]
        T_drive = float(t[ix[-1]] - t[ix[0]])

    n = int(P["meta"]["n_rowers"])
    crew_rows = []
    for i in range(n):
        offsets = P.get("crew", {}).get("phase_offset_ms", [0] * n)
        off = float(offsets[i]) if i < len(offsets) else 0.0
        e_i = float(np.trapezoid(st.handle_power[i], t))
        crew_rows.append({
            "seat": i + 1,
            "phase_offset_ms": off,
            "E_handle_J": e_i,
            "P_mean_W": e_i / max(en["stroke_period_s"], 1e-9),
        })

    code = P["meta"].get("boat_class") or P["meta"].get("code")
    v_ref = V_REF_MS.get(code)
    return {
        "source": "simulated",
        "stroke_index": idx,
        "validation": class_validation_status(code),
        "energy": {**en, "T_drive_s": T_drive},
        "targets_9_2": {
            "v_ref_ms": v_ref,
            "v_mean_band": (
                None if v_ref is None else [v_ref * 0.92, v_ref * 1.08]
            ),
            **{k: list(v) if isinstance(v, tuple) else v
               for k, v in TARGETS_9_2.items()},
        },
        "eta_note": (
            "η_blade hors cible §9.2 est un écart connu du modèle 1DOF "
            "(pas de contrôle actif d'incidence) — voir STATE.md / "
            "ROADMAP-PRODUCTION.md. Pas une erreur de calcul."
        ),
        "series": {
            "t_s": _series(t),
            "u": _series(u),
            "theta_deg": _series(np.degrees(th0)),
            "handle_force_N": _series(fh0),
            "V_ms": _series(st.V),
            "immersion": _series(imm0),
        },
        "crew": crew_rows,
        "boat": {
            "n_rowers": n,
            "sculling": bool(P["meta"].get("sculling", False)),
            "coxed": bool(P["meta"].get("coxed", False)),
            "theta_catch_deg": float(P["rig"]["theta_catch_deg"]),
            "theta_finish_deg": float(P["rig"]["theta_finish_deg"]),
            "geometry_source": P.get("geometry_source", "composite"),
        },
    }


@app.get("/api/health")
def health():
    return {"ok": True, "data_policy": "simulated_unless_measured"}


@app.get("/api/classes")
def get_classes(role: Role = Depends(require_role)):
    return {"classes": list_classes(), "role": role.value}


@app.get("/api/hull_moulds")
def get_hulls(
    boat_class: str | None = None,
    role: Role = Depends(require_role),
):
    return {"moulds": list_hull_moulds(boat_class), "role": role.value}


@app.get("/api/params/{code}")
def get_params(
    code: str,
    hull_builder: str | None = None,
    hull_mould: str | None = None,
    role: Role = Depends(require_role),
):
    analyst_only(role)
    try:
        return load_class_annotated(
            code, hull_builder=hull_builder, hull_mould=hull_mould
        )
    except FileNotFoundError as exc:
        raise HTTPException(404, str(exc)) from exc
    except KeyError as exc:
        raise HTTPException(400, str(exc)) from exc


@app.post("/api/validate")
def validate_params(body: SimulateRequest, role: Role = Depends(require_role)):
    """Contrôles légers pré-intégration (enveloppe complète = Phase 3)."""
    analyst_only(role)
    try:
        P = load_class(
            body.boat_class,
            hull_builder=body.hull_builder,
            hull_mould=body.hull_mould,
        )
        P = _apply_overrides(P, body.overrides)
    except (FileNotFoundError, KeyError, TypeError) as exc:
        raise HTTPException(400, str(exc)) from exc
    warnings = []
    st = class_validation_status(body.boat_class)
    if st["status"] == "beta":
        warnings.append({
            "level": "beta",
            "message": "Classe en test de fumée seulement — non calibrée",
        })
    return {
        "ok": True,
        "validation": st,
        "geometry_source": P.get("geometry_source", "composite"),
        "n_rowers": int(P["meta"]["n_rowers"]),
        "warnings": warnings,
    }


@app.post("/api/simulate")
def run_simulate(body: SimulateRequest, role: Role = Depends(require_role)):
    """Accessible Analyste ; Produit pourra s'en servir via rejeu (Phase produit)."""
    try:
        P = load_class(
            body.boat_class,
            hull_builder=body.hull_builder,
            hull_mould=body.hull_mould,
        )
        P = _apply_overrides(P, body.overrides)
        P["numerics"]["n_strokes"] = int(body.n_strokes)
        P["numerics"]["n_discard"] = int(body.n_discard)
        res = simulate(P)
        st = res.stroke(body.stroke_index)
        return _stroke_payload(st, body.stroke_index, P)
    except FileNotFoundError as exc:
        raise HTTPException(404, str(exc)) from exc
    except Exception as exc:  # noqa: BLE001 — remonter au client UI
        raise HTTPException(500, f"{type(exc).__name__}: {exc}") from exc


@app.get("/api/pose")
def get_pose(
    boat_class: str,
    u: float = 0.0,
    drive: bool = True,
    hull_builder: str | None = None,
    hull_mould: str | None = None,
    role: Role = Depends(require_role),
):
    """Pose sagittale à u — géométrie Python (StrokeGeometry), pas d'IK TS."""
    try:
        return pose_at_u(
            boat_class, u, drive=drive,
            hull_builder=hull_builder, hull_mould=hull_mould,
        )
    except FileNotFoundError as exc:
        raise HTTPException(404, str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(400, str(exc)) from exc


@app.get("/api/pose/series")
def get_pose_series(
    boat_class: str,
    n: int = 41,
    drive: bool = True,
    hull_builder: str | None = None,
    hull_mould: str | None = None,
    role: Role = Depends(require_role),
):
    """Série de poses u=0..1 pour animer StrokeGeometry."""
    try:
        return pose_series(
            boat_class, n=n, drive=drive,
            hull_builder=hull_builder, hull_mould=hull_mould,
        )
    except FileNotFoundError as exc:
        raise HTTPException(404, str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(400, str(exc)) from exc


@app.post("/api/jobs/sweep")
def jobs_sweep(role: Role = Depends(require_role)):
    analyst_only(role)
    raise HTTPException(
        501,
        "Mode sweep / Sobol non implémenté — Phase 5 (analysis/). Maquette UI seulement.",
    )


def create_app() -> FastAPI:
    return app
