"""Tests force dame + angle dame — stats ≥500 tirages, biais/dérive séparés."""
from __future__ import annotations

import numpy as np
import pytest

from avsim.sensors.angle_dame import LSB_DEG, AngleDameSensor
from avsim.sensors.force_dame import FULL_SCALE_N, LSB_N, ForceDameSensor

N = 500


def test_force_dame_noise_std_near_spec() -> None:
    t = np.linspace(0, 1, 201)
    truth = np.full_like(t, 500.0)
    stds = []
    for seed in range(25):
        s = ForceDameSensor(rng_seed=seed, bias_N=0.0)
        # isoler le bruit : pas d'axial, temp constante, hyst/nl sur constant ~0
        out = s.sample(truth, t, temp_C=20.0, F_axial=0.0)
        err = out["y"] - 500.0
        stds.append(err.std(ddof=1))
    # σ attendu ~ 0.5 LSB après quantification — ordre de grandeur
    assert 0.3 * LSB_N < np.median(stds) < 3.0 * LSB_N


def test_force_dame_axial_crosstalk_is_material() -> None:
    t = np.linspace(0, 0.5, 100)
    truth = np.zeros_like(t)
    s = ForceDameSensor(rng_seed=1, axial_crosstalk=0.02, bias_N=0.0)
    y0 = s.sample(truth, t, F_axial=0.0, temp_C=20.0)["y"].mean()
    s2 = ForceDameSensor(rng_seed=1, axial_crosstalk=0.02, bias_N=0.0)
    y1 = s2.sample(truth, t, F_axial=1000.0, temp_C=20.0)["y"].mean()
    assert y1 - y0 == pytest.approx(20.0, abs=2.0)  # 2 % × 1000 N


def test_force_dame_thermal_drift_separate_from_noise() -> None:
    t = np.zeros(50)
    x = np.zeros(50)
    s = ForceDameSensor(rng_seed=0, bias_N=0.0)
    # sans bruit pour isoler : sigma→0 via monkeypatch en passant sigma_N=0
    s.sigma_N = 0.0
    y20 = s.apply_errors(x, t, temp_C=20.0, F_axial=0.0)
    s.rng = np.random.default_rng(0)
    y30 = s.apply_errors(x, t, temp_C=30.0, F_axial=0.0)
    expected = (0.002 / 100.0) * FULL_SCALE_N * 10.0
    assert abs((y30 - y20).mean() - expected) < 0.05


def test_force_dame_sample_rate_200hz() -> None:
    t = np.arange(0, 1.0, 1 / 200)
    s = ForceDameSensor(rng_seed=0)
    out = s.sample(np.zeros_like(t), t)
    assert abs(out["t"].size - 200) <= 2


def test_angle_dame_quantization_lsb() -> None:
    t = np.linspace(0, 1, 400)
    # angle lent
    th = np.linspace(0, np.radians(10), t.size)
    s = AngleDameSensor(rng_seed=0, eccentricity_deg=0.0, inl_deg=0.0, bias_deg=0.0)
    # bruit faible pour voir quantification
    out = s.sample(th, t)
    # différences entre niveaux ≈ k * LSB en radians
    uniq = np.unique(np.round(np.degrees(out["y"]) / LSB_DEG))
    assert uniq.size >= 2
    # échantillons à 200 Hz
    assert out["t"].size >= 190


def test_angle_dame_noise_mean_near_zero_over_draws() -> None:
    t = np.linspace(0, 0.2, 41)
    th = np.zeros_like(t)
    means = []
    for seed in range(N // 10):
        s = AngleDameSensor(rng_seed=seed, eccentricity_deg=0.0, inl_deg=0.0)
        err = np.degrees(s.sample(th, t)["y"])
        means.append(err.mean())
    assert abs(np.mean(means)) < 0.05
