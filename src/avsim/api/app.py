"""Application FastAPI — brief interface utilisateur §1 / brief-simulateur §10."""
from __future__ import annotations

import asyncio
import copy
import json
import time
from datetime import datetime, timedelta, timezone
from typing import Any

import numpy as np
from fastapi import Depends, FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
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
from avsim.io.coaching_viz import crew_stroke_bars
from avsim.io.events import STORE, StrokeMark
from avsim.io.rameur import (
    haptic_events_for_session,
    progression_multi_session,
    seat_force_history,
)
from avsim.io.replay import stroke_distance_m, stroke_frame

from .roles import Role, analyst_only, require_role

app = FastAPI(
    title="DataR0w avsim API",
    version="0.1.0",
    description="Deux surfaces (Analyste / Produit), un moteur. Sorties = Simulé.",
)

app.add_middleware(
    CORSMiddleware,
    # Usage restreint / interne pour l'instant. Avant toute exposition publique
    # durable, resserrer à l'URL réelle du frontend (ex. https://avsim-web.onrender.com)
    # — même caveat que le contrôle de rôle par en-tête X-DataR0w-Role
    # (convention d'interface, pas une auth forte ; voir roles.py).
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
    crew_rows = crew_stroke_bars(st, P)

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
            "L_slide_m": float(P["rig"]["L_slide_m"]),
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


@app.post("/api/jobs/sweep")
def jobs_sweep(role: Role = Depends(require_role)):
    analyst_only(role)
    raise HTTPException(
        501,
        "Mode sweep / Sobol non implémenté — Phase 5 (analysis/). Maquette UI seulement.",
    )


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
    _ = role
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
    _ = role
    try:
        return pose_series(
            boat_class, n=n, drive=drive,
            hull_builder=hull_builder, hull_mould=hull_mould,
        )
    except FileNotFoundError as exc:
        raise HTTPException(404, str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(400, str(exc)) from exc


class SessionCreate(BaseModel):
    boat_class: str = "2x"


class EventCreate(BaseModel):
    # Extensible : coach_voice | haptic_alert | …
    source: str = "coach_voice"
    audio_ref: str | None = None
    transcript: str | None = None
    tag: str | None = None
    t_utc: str | None = None


@app.get("/api/rameur/review")
def rameur_review(
    boat_class: str = Query("2x"),
    seat: int = Query(1, ge=1, le=8),
    n_prev: int = Query(10, ge=1, le=20),
    session_id: str | None = Query(
        None,
        description="Si fourni, joint les events source=haptic_alert",
    ),
    role: Role = Depends(require_role),
):
    """Vue Rameur §3.1 — courbe F dernier coup + n_prev, phase vs nage."""
    _ = role
    try:
        payload = seat_force_history(
            boat_class=boat_class, seat=seat, n_prev=n_prev,
        )
    except FileNotFoundError as exc:
        raise HTTPException(404, str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(400, str(exc)) from exc
    haptic: list[dict[str, Any]] = []
    if session_id is not None:
        try:
            haptic = haptic_events_for_session(session_id)
        except KeyError as exc:
            raise HTTPException(404, f"session inconnue : {session_id}") from exc
    payload["session_id"] = session_id
    payload["haptic_events"] = haptic
    return payload


@app.get("/api/rameur/progression")
def rameur_progression(
    boat_class: str = Query("2x"),
    cadence_tol_spm: float = Query(2.0, ge=0.0, le=10.0),
    role: Role = Depends(require_role),
):
    """Indice de progression multi-séances (conditions comparables)."""
    _ = role
    return progression_multi_session(
        boat_class=boat_class, cadence_tol_spm=cadence_tol_spm,
    )


@app.post("/api/sessions")
def create_session(body: SessionCreate, role: Role = Depends(require_role)):
    """Crée une séance Produit (rejeu) pour y attacher des events."""
    _ = role
    try:
        load_class(body.boat_class)
    except FileNotFoundError as exc:
        raise HTTPException(404, str(exc)) from exc
    sess = STORE.create_session(body.boat_class)
    return sess.to_dict()


@app.get("/api/sessions")
def list_sessions(role: Role = Depends(require_role)):
    _ = role
    return {"sessions": STORE.list_sessions()}


@app.get("/api/sessions/{session_id}")
def get_session(session_id: str, role: Role = Depends(require_role)):
    _ = role
    sess = STORE.get(session_id)
    if sess is None:
        raise HTTPException(404, f"session inconnue : {session_id}")
    return sess.to_dict()


@app.get("/api/sessions/{session_id}/events")
def list_events(session_id: str, role: Role = Depends(require_role)):
    _ = role
    sess = STORE.get(session_id)
    if sess is None:
        raise HTTPException(404, f"session inconnue : {session_id}")
    return {"session_id": session_id, "events": [e.to_dict() for e in sess.events]}


@app.post("/api/sessions/{session_id}/events")
def post_event(
    session_id: str,
    body: EventCreate,
    role: Role = Depends(require_role),
):
    """Annotation vocale / marqueur — schéma events (personas §6)."""
    _ = role
    try:
        ev = STORE.add_event(
            session_id,
            source=body.source,
            audio_ref=body.audio_ref,
            transcript=body.transcript,
            tag=body.tag,
            t_utc=body.t_utc,
        )
    except KeyError as exc:
        raise HTTPException(404, f"session inconnue : {session_id}") from exc
    nearest = STORE.nearest_stroke_index(session_id, ev.t_utc)
    return {**ev.to_dict(), "nearest_stroke_index": nearest}


@app.get("/api/sessions/{session_id}/compare")
def compare_around_event(
    session_id: str,
    event_id: str,
    n: int = Query(3, ge=1, le=20, description="Fenêtre N coups avant/après"),
    metric: str = Query(
        "cadence_spm",
        description="arc_deg | cadence_spm | phase_lag_ms",
    ),
    role: Role = Depends(require_role),
):
    """Écart brut avant/après — **sans** seuil Mode D (non disponible)."""
    _ = role
    sess = STORE.get(session_id)
    if sess is None:
        raise HTTPException(404, f"session inconnue : {session_id}")
    ev = next((e for e in sess.events if e.event_id == event_id), None)
    if ev is None:
        raise HTTPException(404, f"event inconnu : {event_id}")
    allowed = ("arc_deg", "cadence_spm", "phase_lag_ms")
    if metric not in allowed:
        raise HTTPException(400, f"metric inconnue : {metric} (attendu {allowed})")
    idx = STORE.nearest_stroke_index(session_id, ev.t_utc)
    if idx is None:
        raise HTTPException(400, "aucun coup enregistré pour joindre l'événement")
    by_i = {m.stroke_index: m for m in sess.strokes}

    def _val(m: StrokeMark) -> float:
        if metric == "arc_deg":
            return float(m.arc_deg)
        if metric == "cadence_spm":
            return float(m.cadence_spm)
        return float(m.phase_lag_ms)

    before_idx = [i for i in range(idx - n, idx) if i in by_i]
    after_idx = [i for i in range(idx + 1, idx + 1 + n) if i in by_i]
    before_vals = [_val(by_i[i]) for i in before_idx]
    after_vals = [_val(by_i[i]) for i in after_idx]
    mean_b = float(np.mean(before_vals)) if before_vals else None
    mean_a = float(np.mean(after_vals)) if after_vals else None
    delta = (
        (mean_a - mean_b)
        if mean_a is not None and mean_b is not None
        else None
    )
    return {
        "session_id": session_id,
        "event_id": event_id,
        "nearest_stroke_index": idx,
        "metric": metric,
        "n": n,
        "before": {"stroke_indices": before_idx, "values": before_vals, "mean": mean_b},
        "after": {"stroke_indices": after_idx, "values": after_vals, "mean": mean_a},
        "delta": delta,
        "significance": {
            "calibrated": False,
            "message": (
                "Signification non calibrée — Mode D (Détectabilité) non disponible. "
                "Écart brut affiché sans seuil de détectabilité."
            ),
        },
        "event": ev.to_dict(),
    }


def _json_default(obj: Any) -> Any:
    if isinstance(obj, (np.floating, np.integer)):
        return obj.item()
    if isinstance(obj, np.ndarray):
        return obj.tolist()
    raise TypeError(f"non JSON-serialisable : {type(obj)}")


@app.get("/api/replay/stream")
async def replay_stream(
    boat_class: str = Query("2x", description="Classe à rejouer (défaut 2x)"),
    n_strokes: int = Query(12, ge=2, le=40),
    n_discard: int = Query(4, ge=1, le=20),
    realtime: bool = Query(
        True,
        description="Cadencer chaque coup à T (stroke_period) — false pour tests",
    ),
    session_id: str | None = Query(
        None,
        description="Si fourni, enregistre les coups pour joindre les events",
    ),
    role: Role = Depends(require_role),
):
    """SSE — même trames NDJSON que `avsim replay --realtime`.

    Unidirectionnel → SSE (pas WebSocket). `source=simulated` sur chaque
    événement. Surface Produit / Team / Coach live.
    """
    _ = role  # les deux rôles ; badge Simulé côté client obligatoire
    try:
        P = load_class(boat_class)
    except FileNotFoundError as exc:
        raise HTTPException(404, str(exc)) from exc
    P = copy.deepcopy(P)
    P["numerics"]["n_strokes"] = int(n_strokes)
    P["numerics"]["n_discard"] = int(n_discard)
    if session_id is not None and STORE.get(session_id) is None:
        raise HTTPException(404, f"session inconnue : {session_id}")

    async def event_gen():
        res = await asyncio.to_thread(simulate, P)
        session = {
            "kind": "session",
            "source": "simulated",
            "boat_class": boat_class,
            "n_strokes": int(n_strokes),
            "n_discard": int(n_discard),
            "n_keep": int(res.n_keep),
            "session_id": session_id,
            "validation": class_validation_status(boat_class),
        }
        yield f"data: {json.dumps(session, default=_json_default)}\n\n"

        distance = 0.0
        # Timeline simulée pour joindre events↔coups (précision seconde).
        # En realtime=false, utc_now_second() collapserait tous les marks.
        t0_wall = datetime.now(timezone.utc).replace(microsecond=0)
        cum_s = 0.0
        for i in range(res.n_keep):
            t0 = time.perf_counter()
            st = res.stroke(i)
            distance += stroke_distance_m(st)
            frame = stroke_frame(
                st,
                boat_class=boat_class,
                stroke_index=i,
                distance_m=distance,
                params=P,
            )
            if session_id is not None:
                t_utc = (
                    t0_wall + timedelta(seconds=int(round(cum_s)))
                ).isoformat()
                STORE.add_stroke_mark(
                    session_id,
                    StrokeMark(
                        stroke_index=i,
                        t_utc=t_utc,
                        cadence_spm=float(frame["cadence_spm"]),
                        v_ms=float(frame["v_ms"]),
                        check_factor=float(frame["check_factor"]),
                        arc_deg=float(frame["arc_deg"]),
                        phase_lag_ms=float(frame["phase_lag_ms"]),
                        energy=dict(frame["energy"]),
                        stroke_bars=list(frame.get("stroke_bars") or []),
                    ),
                )
            yield f"data: {json.dumps(frame, default=_json_default)}\n\n"
            cum_s += float(frame["T_s"])
            if realtime:
                delay = float(frame["T_s"]) - (time.perf_counter() - t0)
                if delay > 0:
                    await asyncio.sleep(delay)
        yield f"data: {json.dumps({'kind': 'end', 'source': 'simulated'})}\n\n"

    return StreamingResponse(
        event_gen(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


def create_app() -> FastAPI:
    return app
