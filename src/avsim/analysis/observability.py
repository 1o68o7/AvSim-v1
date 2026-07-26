"""Mode C — Observabilité / valeur du capteur — **pilote 2x uniquement**.

Étiquetage permanent (pas une astuce temporaire) :

    « Pilote classe 2x uniquement — les 7 autres classes restent
    bloquées par les limites 1DOF documentées (STATE.md). Non
    représentatif des autres classes tant que Phase 1 n'avance pas. »

Parcours : sélection avant gloutonne sur un catalogue réduit (pas les
4096 sous-ensembles). 200 vérités terrain admissibles
(`ignore_known_1dof_limits=True`).
"""
from __future__ import annotations

import copy
import json
import time
from concurrent.futures import ProcessPoolExecutor, as_completed
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any, Callable

import numpy as np

from avsim.core.boat_class import BoatClass
from avsim.core.envelope import check_inputs, check_outputs, is_admissible
from avsim.core.params import load_class
from avsim.core.solver import simulate
from avsim.estimation.ekf import DashboardEKF, EKFConfig
from avsim.sensors.coulisse import CoulisseSensor
from avsim.sensors.gnss import GnssRtkSensor, GnssStandardSensor
from avsim.sensors.imu_coque import ImuCoqueSensor
from avsim.sensors.impeller import ImpellerSensor
from avsim.sensors.pod_dorsal import PodDorsalSensor

PILOT_LABEL = (
    "Pilote classe 2x uniquement — les 7 autres classes restent bloquées, "
    "cf. STATE.md. Non représentatif des autres classes tant que Phase 1 "
    "n'avance pas plus loin."
)

BOAT_CLASS = "2x"


@dataclass(frozen=True)
class SensorSpec:
    """Capteur Mode C — canal tableau de bord (V ou CdM) + coût/masse."""
    id: str
    label: str
    channel: str  # "velocity" | "com" | "accel"
    cost_eur: float
    mass_g: float
    R: float  # variance de mesure pour l'EKF


# Catalogue réduit (sélection gloutonne — pas 2^12). Capteurs Phase 4.
SENSOR_CATALOG: dict[str, SensorSpec] = {
    "impeller": SensorSpec(
        "impeller", "Impeller NK", "velocity", 80.0, 50.0, 0.04**2,
    ),
    "gnss_standard": SensorSpec(
        "gnss_standard", "GNSS standard", "velocity", 45.0, 30.0, 0.05**2,
    ),
    "gnss_rtk": SensorSpec(
        "gnss_rtk", "GNSS RTK", "velocity", 270.0, 60.0, 0.02**2,
    ),
    "imu_coque": SensorSpec(
        "imu_coque", "IMU coque", "accel", 28.0, 25.0, 0.5**2,
    ),
    "coulisse": SensorSpec(
        "coulisse", "Coulisse ToF", "com", 12.0, 8.0, 0.025**2,
    ),
    "pod_dorsal": SensorSpec(
        "pod_dorsal", "Pod dorsal", "com", 28.0, 30.0, 0.06**2,
    ),
}


@dataclass
class TruthStroke:
    """Une vérité terrain 2x (dernier coup établi)."""
    truth_id: int
    t: np.ndarray
    V: np.ndarray
    x_com: np.ndarray
    accel: np.ndarray
    params_delta: dict[str, float] = field(default_factory=dict)

    def to_serializable(self) -> dict[str, Any]:
        return {
            "truth_id": self.truth_id,
            "t": self.t.tolist(),
            "V": self.V.tolist(),
            "x_com": self.x_com.tolist(),
            "accel": self.accel.tolist(),
            "params_delta": self.params_delta,
        }

    @classmethod
    def from_serializable(cls, d: dict[str, Any]) -> "TruthStroke":
        return cls(
            truth_id=int(d["truth_id"]),
            t=np.asarray(d["t"], dtype=float),
            V=np.asarray(d["V"], dtype=float),
            x_com=np.asarray(d["x_com"], dtype=float),
            accel=np.asarray(d["accel"], dtype=float),
            params_delta=dict(d.get("params_delta") or {}),
        )


def _sample_params(rng: np.random.Generator) -> tuple[dict, dict[str, float]]:
    """Petites perturbations technique.* dans l'enveloppe 2x."""
    P = copy.deepcopy(load_class(BOAT_CLASS))
    P["numerics"]["n_strokes"] = 6
    P["numerics"]["n_discard"] = 3
    delta: dict[str, float] = {}
    rate = float(np.clip(rng.normal(36.0, 1.5), 32.0, 40.0))
    P["technique"]["rate_spm"] = rate
    delta["technique.rate_spm"] = rate
    # léger décalage poste 2 (ms) — n_rowers=2
    off = float(np.clip(rng.normal(0.0, 15.0), -40.0, 40.0))
    P["crew"]["phase_offset_ms"] = [0.0, off]
    delta["crew.phase_offset_ms_1"] = off
    return P, delta


def _simulate_one(args: tuple[int, int]) -> dict[str, Any] | None:
    """Worker process — retourne TruthStroke sérialisé ou None si rejeté."""
    truth_id, seed = args
    rng = np.random.default_rng(seed)
    P, delta = _sample_params(rng)
    cls = BoatClass.from_params(P)
    vin = check_inputs(P, cls)
    if not is_admissible(vin, ignore_known_1dof_limits=True):
        return None
    res = simulate(P)
    vout = check_outputs(res, P, cls)
    if not is_admissible(vin + vout, ignore_known_1dof_limits=True):
        return None
    st = res.last_stroke()
    t = np.asarray(st.t, dtype=float)
    V = np.asarray(st.V, dtype=float)
    x_com = np.asarray(st.com_rel, dtype=float)
    accel = np.gradient(V, t)
    return TruthStroke(
        truth_id=truth_id, t=t, V=V, x_com=x_com, accel=accel,
        params_delta=delta,
    ).to_serializable()


def draw_truths_2x(
    n: int = 200,
    *,
    seed: int = 42,
    max_workers: int | None = None,
    max_attempts_factor: int = 4,
) -> list[TruthStroke]:
    """Tire ``n`` vérités 2x admissibles (Phase 5 gate)."""
    rng = np.random.default_rng(seed)
    need = n
    # File d'attente bornée (= n_workers) : dès que n réussites, on arrête
    # sans laisser 4×n jobs orphelins terminer.
    truths: list[TruthStroke] = []
    workers = max_workers or 4
    attempt_i = 0
    max_attempts = n * max_attempts_factor
    with ProcessPoolExecutor(max_workers=workers) as pool:
        in_flight: dict = {}
        while (len(truths) < need) and (
            attempt_i < max_attempts or in_flight
        ):
            while (
                len(in_flight) < workers
                and attempt_i < max_attempts
                and len(truths) < need
            ):
                job = (attempt_i, int(rng.integers(0, 2**31 - 1)))
                attempt_i += 1
                in_flight[pool.submit(_simulate_one, job)] = job
            if not in_flight:
                break
            done = next(as_completed(list(in_flight.keys())))
            in_flight.pop(done, None)
            raw = done.result()
            if raw is None:
                continue
            th = TruthStroke.from_serializable(raw)
            th.truth_id = len(truths)
            truths.append(th)
        for fut in list(in_flight):
            fut.cancel()
    if len(truths) < need:
        raise RuntimeError(
            f"seulement {len(truths)}/{need} vérités 2x admissibles "
            f"(augmenter max_attempts_factor)"
        )
    return truths[:need]


def _make_sensor(spec: SensorSpec, seed: int):
    if spec.id == "impeller":
        return ImpellerSensor(rng_seed=seed)
    if spec.id == "gnss_standard":
        return GnssStandardSensor(rng_seed=seed)
    if spec.id == "gnss_rtk":
        return GnssRtkSensor(rng_seed=seed)
    if spec.id == "imu_coque":
        return ImuCoqueSensor(rng_seed=seed)
    if spec.id == "coulisse":
        return CoulisseSensor(rng_seed=seed)
    if spec.id == "pod_dorsal":
        return PodDorsalSensor(rng_seed=seed)
    raise KeyError(spec.id)


def sense_subset(
    truth: TruthStroke,
    subset: list[str],
    *,
    seed: int = 0,
) -> dict[str, Any]:
    """Génère les sorties bruitées du sous-ensemble, réalignées sur t vérité."""
    t = truth.t
    v_channels: list[np.ndarray] = []
    v_weights: list[float] = []
    com_channels: list[np.ndarray] = []
    com_weights: list[float] = []
    accel = None
    for i, sid in enumerate(subset):
        spec = SENSOR_CATALOG[sid]
        sens = _make_sensor(spec, seed + 17 * i + truth.truth_id)
        if spec.channel == "velocity":
            gt = truth.V
            if sid.startswith("gnss"):
                out = sens.sample(gt, t, channel="velocity")
            else:
                out = sens.sample(gt, t)
            y = np.interp(t, out["t"], np.asarray(out["y"], dtype=float).ravel())
            v_channels.append(y)
            v_weights.append(1.0 / max(spec.R, 1e-12))
        elif spec.channel == "com":
            out = sens.sample(truth.x_com, t)
            y = np.interp(t, out["t"], np.asarray(out["y"], dtype=float).ravel())
            com_channels.append(y)
            com_weights.append(1.0 / max(spec.R, 1e-12))
        elif spec.channel == "accel":
            out = sens.sample(truth.accel, t)
            accel = np.interp(
                t, out["t"], np.asarray(out["y"], dtype=float).ravel()
            )
    v_meas = None
    v_R = 0.05**2
    if v_channels:
        w = np.asarray(v_weights, dtype=float)
        v_meas = sum(w[i] * v_channels[i] for i in range(len(v_channels))) / w.sum()
        v_R = 1.0 / w.sum()
    com_meas = None
    com_R = 0.03**2
    if com_channels:
        w = np.asarray(com_weights, dtype=float)
        com_meas = (
            sum(w[i] * com_channels[i] for i in range(len(com_channels))) / w.sum()
        )
        com_R = 1.0 / w.sum()
    return {
        "t": t,
        "v_meas": v_meas,
        "v_R": float(v_R),
        "com_meas": com_meas,
        "com_R": float(com_R),
        "accel": accel,
    }


def evaluate_subset(
    truths: list[TruthStroke],
    subset: list[str],
    *,
    seed: int = 0,
) -> dict[str, float]:
    """RMSE moyen V et x_com sur les vérités pour un sous-ensemble."""
    if not subset:
        # aucune mesure — erreur = écart au prior EKF
        err_v, err_c = [], []
        for th in truths:
            ekf = DashboardEKF(EKFConfig(v0=float(np.mean(th.V)), x_com0=0.0))
            out = ekf.run(th.t)
            err_v.append(float(np.sqrt(np.mean((out["V"] - th.V) ** 2))))
            err_c.append(float(np.sqrt(np.mean((out["x_com"] - th.x_com) ** 2))))
        return {
            "rmse_V": float(np.mean(err_v)),
            "rmse_com": float(np.mean(err_c)),
            "rmse_combined": float(np.mean(err_v) + 10.0 * np.mean(err_c)),
        }
    err_v, err_c = [], []
    for th in truths:
        meas = sense_subset(th, subset, seed=seed)
        ekf = DashboardEKF(
            EKFConfig(v0=float(th.V[0]), x_com0=float(th.x_com[0]))
        )
        out = ekf.run(
            meas["t"],
            v_meas=meas["v_meas"],
            v_R=meas["v_R"],
            com_meas=meas["com_meas"],
            com_R=meas["com_R"],
            accel=meas["accel"],
        )
        err_v.append(float(np.sqrt(np.mean((out["V"] - th.V) ** 2))))
        err_c.append(float(np.sqrt(np.mean((out["x_com"] - th.x_com) ** 2))))
    rmse_V = float(np.mean(err_v))
    rmse_com = float(np.mean(err_c))
    return {
        "rmse_V": rmse_V,
        "rmse_com": rmse_com,
        # CdM en cm-équivalent dans le score glouton (×10)
        "rmse_combined": rmse_V + 10.0 * rmse_com,
    }


def subset_cost_mass(subset: list[str]) -> tuple[float, float]:
    cost = sum(SENSOR_CATALOG[s].cost_eur for s in subset)
    mass = sum(SENSOR_CATALOG[s].mass_g for s in subset)
    return float(cost), float(mass)


def greedy_forward_observe(
    truths: list[TruthStroke],
    *,
    catalog: dict[str, SensorSpec] | None = None,
    seed: int = 0,
) -> dict[str, Any]:
    """Sélection avant gloutonne — front coût/erreur le long du chemin."""
    cat = catalog or SENSOR_CATALOG
    remaining = list(cat.keys())
    selected: list[str] = []
    path: list[dict[str, Any]] = []
    baseline = evaluate_subset(truths, [], seed=seed)
    path.append({
        "subset": [],
        "cost_eur": 0.0,
        "mass_g": 0.0,
        **baseline,
        "added": None,
    })
    while remaining:
        best_id = None
        best_metrics = None
        best_score = path[-1]["rmse_combined"]
        for sid in remaining:
            trial = selected + [sid]
            m = evaluate_subset(truths, trial, seed=seed)
            if m["rmse_combined"] < best_score - 1e-12:
                best_score = m["rmse_combined"]
                best_id = sid
                best_metrics = m
        if best_id is None or best_metrics is None:
            # aucun ajout n'améliore — arrêt glouton
            break
        selected.append(best_id)
        remaining.remove(best_id)
        cost, mass = subset_cost_mass(selected)
        path.append({
            "subset": list(selected),
            "cost_eur": cost,
            "mass_g": mass,
            **best_metrics,
            "added": best_id,
        })
    # table capteur → gain (réduction de rmse_combined à l'ajout)
    gains: list[dict[str, Any]] = []
    for i in range(1, len(path)):
        prev, cur = path[i - 1], path[i]
        sid = cur["added"]
        spec = cat[sid]
        gains.append({
            "sensor_id": sid,
            "label": spec.label,
            "channel": spec.channel,
            "cost_eur": spec.cost_eur,
            "mass_g": spec.mass_g,
            "gain_rmse_combined": prev["rmse_combined"] - cur["rmse_combined"],
            "gain_rmse_V": prev["rmse_V"] - cur["rmse_V"],
            "gain_rmse_com": prev["rmse_com"] - cur["rmse_com"],
            "order": i,
        })
    # front de Pareto (coût / rmse_combined) le long du chemin glouton
    pareto = []
    best_err = float("inf")
    for p in path:
        if p["rmse_combined"] < best_err - 1e-12:
            best_err = p["rmse_combined"]
            pareto.append({
                "subset": p["subset"],
                "cost_eur": p["cost_eur"],
                "mass_g": p["mass_g"],
                "rmse_V": p["rmse_V"],
                "rmse_com": p["rmse_com"],
                "rmse_combined": p["rmse_combined"],
            })
    return {
        "pilot_label": PILOT_LABEL,
        "boat_class": BOAT_CLASS,
        "n_truths": len(truths),
        "greedy_path": path,
        "sensor_gains": gains,
        "pareto_cost_error": pareto,
    }


def run_mode_c_2x(
    n_truths: int = 200,
    *,
    seed: int = 42,
    max_workers: int | None = None,
    truths: list[TruthStroke] | None = None,
) -> dict[str, Any]:
    """Pipeline Mode C complet — 2x seulement."""
    t0 = time.perf_counter()
    if truths is None:
        truths = draw_truths_2x(
            n_truths, seed=seed, max_workers=max_workers,
        )
    result = greedy_forward_observe(truths, seed=seed)
    result["elapsed_s"] = time.perf_counter() - t0
    result["source"] = "simulated"
    result["note"] = PILOT_LABEL
    return result


def save_results(result: dict[str, Any], path: Path | str) -> Path:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(result, indent=2), encoding="utf-8")
    return path


def load_results(path: Path | str) -> dict[str, Any]:
    return json.loads(Path(path).read_text(encoding="utf-8"))


DEFAULT_RESULTS_PATH = Path("data/observability_2x_pilot.json")
