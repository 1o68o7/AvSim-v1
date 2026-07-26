"""Tests GNSS, impeller, météo."""
from __future__ import annotations

import numpy as np
import pytest

from avsim.sensors.gnss import GnssRtkSensor, GnssStandardSensor
from avsim.sensors.impeller import ImpellerSensor
from avsim.sensors.meteo import AnemoEmbarqueSensor, AnemoRiveSensor, TemperatureEauSensor


def test_gnss_standard_multipath_near_bank() -> None:
    t = np.linspace(0, 10, 101)
    x = np.zeros_like(t)
    open_std, bank_std = [], []
    for seed in range(25):
        g = GnssStandardSensor(rng_seed=seed)
        open_std.append(g.sample(x, t, near_bank=False)["y"].std())
        bank_std.append(g.sample(x, t, near_bank=True)["y"].std())
    assert np.median(bank_std) > np.median(open_std)


def test_gnss_rtk_loses_fix_under_trees() -> None:
    t = np.linspace(0, 5, 51)
    x = np.zeros_like(t)
    fix_std, tree_std = [], []
    for seed in range(25):
        g = GnssRtkSensor(rng_seed=seed)
        fix_std.append(g.sample(x, t, under_trees=False)["y"].std())
        tree_std.append(g.sample(x, t, under_trees=True)["y"].std())
    assert np.median(tree_std) > 10 * np.median(fix_std)


def test_gnss_rate_10hz() -> None:
    t = np.arange(0, 2.0, 1 / 200)
    out = GnssStandardSensor(rng_seed=0).sample(np.zeros_like(t), t)
    assert 18 <= out["t"].size <= 22


def test_impeller_not_200hz() -> None:
    t = np.arange(0, 10.0, 1 / 200)
    out = ImpellerSensor(rng_seed=0).sample(np.full_like(t, 3.0), t)
    assert out["t"].size <= 12


def test_impeller_nonlinear_below_2ms() -> None:
    t = np.linspace(0, 5, 6)
    low = ImpellerSensor(rng_seed=0, calib_error_frac=0.0, fouling_frac=0.0)
    high = ImpellerSensor(rng_seed=0, calib_error_frac=0.0, fouling_frac=0.0)
    # forcer scale=1
    low._scale = high._scale = 1.0
    y_low = low.apply_errors(np.full(6, 1.0), t).mean()
    y_high = high.apply_errors(np.full(6, 4.0), t).mean()
    assert y_low < 1.0  # extra frac under 2 m/s
    assert abs(y_high - 4.0) < 0.3


def test_anemo_rive_period_16s_hides_gusts() -> None:
    # Rafales 2 s à 200 Hz — le capteur 0.06 Hz n'en voit qu'un point / 16 s
    fe = 200.0
    t = np.arange(0, 32.0, 1 / fe)
    wind = np.ones_like(t)
    wind[(t > 5) & (t < 7)] = 8.0  # rafale
    s = AnemoRiveSensor(rng_seed=0)
    out = s.sample(wind, t)
    assert out["t"].size <= 4  # 32 s / 16 s
    # max observé << 8 si la rafale tombe entre deux échantillons, ou un seul point
    assert out["y"].max() < 8.5


def test_anemo_embarque_flow_bias() -> None:
    t = np.linspace(0, 5, 11)
    s = AnemoEmbarqueSensor(rng_seed=0, flow_bias_ms=0.2, sigma_ms=0.01)
    y = s.sample(np.zeros_like(t), t)["y"]
    assert y.mean() == pytest.approx(0.2, abs=0.05)


def test_temp_eau_time_constant() -> None:
    t = np.linspace(0, 60, 13)  # 0.2 Hz
    x = np.where(t < 1, 15.0, 25.0)
    s = TemperatureEauSensor(rng_seed=0, sigma_C=0.01, tau_s=10.0)
    y = s.apply_errors(x, t)
    # à t≈10 s après le saut, ~63 % de la marche
    i = np.argmin(np.abs(t - 11.0))
    assert 20.0 < y[i] < 24.0
