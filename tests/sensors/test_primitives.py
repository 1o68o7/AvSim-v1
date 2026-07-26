"""Tests isolés des primitives — propriétés statistiques, pas d'égalités exactes."""
from __future__ import annotations

import numpy as np
import pytest

from avsim.sensors.primitives import (
    bandwidth_limit,
    bias,
    hysteresis,
    quantize,
    slow_drift,
    thermal_sensitivity,
    white_noise,
)


N_DRAWS = 600


def test_white_noise_mean_near_zero_std_matches_sigma() -> None:
    rng = np.random.default_rng(42)
    x = np.zeros(N_DRAWS)
    sigmas = []
    means = []
    for _ in range(40):
        y = white_noise(x, sigma=2.5, rng=rng)
        means.append(y.mean())
        sigmas.append(y.std(ddof=1))
    assert abs(np.mean(means)) < 0.15
    assert abs(np.mean(sigmas) - 2.5) < 0.2


def test_bias_is_pure_offset() -> None:
    x = np.linspace(-1, 1, 50)
    y = bias(x, 3.0)
    np.testing.assert_allclose(y - x, 3.0)


def test_slow_drift_separated_from_white_noise() -> None:
    """Dérive linéaire testée seule — pas mélangée au bruit blanc."""
    t = np.linspace(0, 3600, 1001)  # 1 h
    x = np.zeros_like(t)
    rng = np.random.default_rng(7)
    y = slow_drift(x, t, rate_per_hour=1.0, rng=rng, phase=0.0)
    # après 1 h : +1.0
    assert abs(y[-1] - 1.0) < 1e-9
    assert abs(y[0]) < 1e-9


def test_quantize_resolution() -> None:
    x = np.array([0.0, 0.04, 0.06, 0.14])
    y = quantize(x, 0.1)
    np.testing.assert_allclose(y, [0.0, 0.0, 0.1, 0.1])


def test_bandwidth_limit_attenuates_high_freq() -> None:
    fe = 200.0
    t = np.arange(0, 1.0, 1 / fe)
    # 80 Hz >> cutoff 5 Hz
    x = np.sin(2 * np.pi * 80 * t)
    y = bandwidth_limit(x, cutoff_hz=5.0, fe_hz=fe)
    assert y.std() < 0.25 * x.std()


def test_thermal_sensitivity_scales_with_delta_T() -> None:
    x = np.ones(10)
    T = np.full(10, 30.0)  # +10 °C vs 20
    y = thermal_sensitivity(x, coeff_per_degC=0.01, temp_profile=T, t_ref_C=20.0)
    np.testing.assert_allclose(y, 1.0 + 0.1)


def test_hysteresis_holds_in_deadband() -> None:
    x = np.array([0.0, 0.05, 0.08, 0.5, 0.45])
    y = hysteresis(x, width=0.1)
    assert y[1] == y[0]
    assert y[2] == y[0]
    assert y[3] == pytest.approx(0.4)
