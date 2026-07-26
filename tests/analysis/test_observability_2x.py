"""Mode C pilote 2x — glouton + Pareto (n_truths réduit pour CI)."""
from __future__ import annotations

import numpy as np
import pytest

from avsim.analysis.observability import (
    BOAT_CLASS,
    PILOT_LABEL,
    SENSOR_CATALOG,
    TruthStroke,
    evaluate_subset,
    greedy_forward_observe,
    run_mode_c_2x,
)


def _synthetic_truths(n: int = 4, seed: int = 0) -> list[TruthStroke]:
    """Vérités synthétiques (pas de simulate) — unitaires rapides."""
    rng = np.random.default_rng(seed)
    out: list[TruthStroke] = []
    for i in range(n):
        t = np.linspace(0.0, 1.6, 80)
        V = 3.8 + 0.3 * np.sin(2 * np.pi * t / 1.6) + 0.05 * i
        x_com = 0.2 * np.sin(2 * np.pi * t / 1.6 + 0.3)
        accel = np.gradient(V, t)
        out.append(TruthStroke(i, t, V, x_com, accel, {}))
    return out


def test_pilot_label_and_catalog_2x_only():
    assert BOAT_CLASS == "2x"
    assert "2x" in PILOT_LABEL
    assert "STATE.md" in PILOT_LABEL
    assert len(SENSOR_CATALOG) >= 4
    assert "coulisse" in SENSOR_CATALOG and "impeller" in SENSOR_CATALOG


def test_greedy_improves_combined_error():
    truths = _synthetic_truths(5)
    res = greedy_forward_observe(truths, seed=1)
    assert res["boat_class"] == "2x"
    assert res["pilot_label"] == PILOT_LABEL
    path = res["greedy_path"]
    assert path[0]["subset"] == []
    assert path[-1]["rmse_combined"] <= path[0]["rmse_combined"]
    # chaque ajout du chemin glouton réduit strictement le score
    for i in range(1, len(path)):
        assert path[i]["rmse_combined"] < path[i - 1]["rmse_combined"]
    assert len(res["sensor_gains"]) == len(path) - 1
    assert len(res["pareto_cost_error"]) >= 1
    assert res["pareto_cost_error"][0]["cost_eur"] == 0.0


def test_velocity_sensor_beats_empty_on_V():
    truths = _synthetic_truths(3)
    empty = evaluate_subset(truths, [])
    with_imp = evaluate_subset(truths, ["impeller"], seed=2)
    assert with_imp["rmse_V"] < empty["rmse_V"]


def test_com_sensor_beats_empty_on_com():
    truths = _synthetic_truths(3)
    empty = evaluate_subset(truths, [])
    with_c = evaluate_subset(truths, ["coulisse"], seed=3)
    assert with_c["rmse_com"] < empty["rmse_com"]


def test_coulisse_alone_does_not_worsen_rmse_V():
    """Init unifiée : coulisse (canal CdM) ne doit plus gonfler rmse_V."""
    truths = _synthetic_truths(5)
    empty = evaluate_subset(truths, [])
    with_c = evaluate_subset(truths, ["coulisse"], seed=3)
    # V non observé + même prior → RMSE_V identique (pas d'artefact V[0])
    assert abs(with_c["rmse_V"] - empty["rmse_V"]) < 1e-9
    assert with_c["rmse_com"] < empty["rmse_com"]


@pytest.mark.slow
def test_run_mode_c_2x_small_live_sims():
    """Smoke : 2 vérités simulées 2x + glouton (lent — marqué slow)."""
    res = run_mode_c_2x(n_truths=2, seed=7, max_workers=2)
    assert res["n_truths"] == 2
    assert res["source"] == "simulated"
    assert "Pilote" in res["note"]
    assert res["greedy_path"][-1]["cost_eur"] > 0
