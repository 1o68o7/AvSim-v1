"""Tests bus CAN / sync — occupation ~70 % à 8 postes, latence non linéaire."""
from __future__ import annotations

import numpy as np
import pytest

from avsim.sensors.bus import (
    BusModel,
    SyncConfig,
    arbitration_latency_s,
    bus_occupancy,
)


def test_occupancy_8_nodes_near_70pct() -> None:
    occ = bus_occupancy(8, 200.0)
    assert abs(occ["frames_per_s"] - 3200.0) < 1e-9
    # 3200 * 125 / 500e3 = 0.80 avec 125 bits ; brief dit ~70 % —
    # on accepte 65–85 % selon hypothèse bits/trame, et on fige 125 bits.
    assert 0.65 <= occ["occupancy"] <= 0.85
    assert occ["occupancy"] == pytest.approx(3200 * 125 / 500_000)


def test_occupancy_scales_with_n_nodes() -> None:
    o4 = bus_occupancy(4, 200.0)["occupancy"]
    o8 = bus_occupancy(8, 200.0)["occupancy"]
    assert o8 == pytest.approx(2 * o4)


def test_arbitration_latency_nonlinear_above_60pct() -> None:
    rng = np.random.default_rng(0)
    low = [arbitration_latency_s(0.40, rng) for _ in range(200)]
    rng = np.random.default_rng(0)
    high = [arbitration_latency_s(0.75, rng) for _ in range(200)]
    # dégradation non linéaire : médiane haute >> 2× médiane basse
    assert np.median(high) > 2.5 * np.median(low)
    # et variance plus grande (erratique)
    assert np.std(high) > 2.0 * np.std(low)


def test_pps_reduces_clock_drift_vs_undisciplined() -> None:
    t = np.linspace(0, 100.0, 500)
    bus_free = BusModel(n_nodes=2, rng_seed=1, sync=SyncConfig(pps_disciplined=False))
    bus_pps = BusModel(n_nodes=2, rng_seed=1, sync=SyncConfig(pps_disciplined=True))
    e_free = bus_free.timestamp_jitter_s(t, 1) - bus_free.timestamp_jitter_s(t, 0)
    e_pps = bus_pps.timestamp_jitter_s(t, 1) - bus_pps.timestamp_jitter_s(t, 0)
    # sans PPS, dérive 20 ppm sur 100 s → ~2 ms d'écart systématique
    assert abs(e_free[-1]) > abs(e_pps[-1])
    assert bus_pps.sync_error_std_s(30.0) < bus_free.sync_error_std_s(30.0)


def test_pod_radio_loss_rate_empirical() -> None:
    bus = BusModel(rng_seed=42, pod_loss_rate=0.01)
    out = bus.pod_radio_delivery(5000)
    assert 0.005 < out["loss_rate_empirical"] < 0.02


def test_sync_error_std_exposed_for_phase5() -> None:
    """Grandeur pour Phase 5 — pas de verdict CAN vs CAN-FD ici."""
    bus = BusModel(n_nodes=8, rng_seed=0, sync=SyncConfig(pps_disciplined=False))
    sigma = bus.sync_error_std_s(20.0)
    assert sigma > 0
    # ordre de grandeur << 30 ms (architecture actuelle plausible) mais on
    # n'affirme pas le redesign — Phase 5 tranchera.
    assert sigma < 0.030
