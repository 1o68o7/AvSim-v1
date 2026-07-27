"""Tests coulisse / pieds / pod / IMU coque."""
from __future__ import annotations

import numpy as np
import pytest

from avsim.sensors.coulisse import CoulisseSensor
from avsim.sensors.force_pieds import ForcePiedsSensor
from avsim.sensors.imu_coque import ImuCoqueSensor
from avsim.sensors.pod_dorsal import PodDorsalSensor


def test_coulisse_sunlight_degrades_sigma() -> None:
    t = np.linspace(0, 1, 101)
    x = np.full_like(t, 0.5)
    std_dark, std_sun = [], []
    for seed in range(30):
        d = CoulisseSensor(rng_seed=seed)
        s = CoulisseSensor(rng_seed=seed)
        std_dark.append(d.sample(x, t, sunlight=False)["y"].std())
        std_sun.append(s.sample(x, t, sunlight=True)["y"].std())
    assert np.median(std_sun) > 3.0 * np.median(std_dark)


def test_coulisse_rate_100hz() -> None:
    t = np.arange(0, 1.0, 1 / 200)
    out = CoulisseSensor(rng_seed=0).sample(np.zeros_like(t), t)
    assert 95 <= out["t"].size <= 105


def test_force_pieds_two_channels() -> None:
    t = np.linspace(0, 0.5, 100)
    x = np.column_stack([np.full(100, 200.0), np.full(100, 210.0)])
    out = ForcePiedsSensor(rng_seed=0).sample(x, t)
    assert out["y"].shape == (out["t"].size, 2)


def test_pod_soft_tissue_increases_accel_noise() -> None:
    t = np.linspace(0, 1, 100)
    x = np.zeros((100, 6))
    std_soft, std_rigid = [], []
    for seed in range(20):
        soft = PodDorsalSensor(rng_seed=seed, soft_tissue_sigma=0.4)
        rigid = PodDorsalSensor(rng_seed=seed, soft_tissue_sigma=0.0)
        std_soft.append(soft.sample(x, t)["y"][:, 0].std())
        std_rigid.append(rigid.sample(x, t)["y"][:, 0].std())
    assert np.median(std_soft) > np.median(std_rigid)


def test_pod_bias_drift_separate() -> None:
    t = np.linspace(0, 3600, 100)
    x = np.zeros((100, 6))
    s = PodDorsalSensor(rng_seed=0, soft_tissue_sigma=0.0, drift_accel_per_hour=0.1)
    # silence noise densités en forçant via apply after zeroing rng noise — check drift end
    y = s.apply_errors(x, t)
    # ax channel drifted ~0.1 after 1 h (plus bruit)
    assert y[-1, 0] == pytest.approx(0.1, abs=0.05)


def test_imu_coque_faster_than_pod_and_has_vibration() -> None:
    t = np.arange(0, 1.0, 1 / 200)
    x = np.zeros((t.size, 6))
    imu = ImuCoqueSensor(rng_seed=0)
    out = imu.sample(x, t)
    assert out["t"].size >= 190
    # vibration → std accel > densité seule
    assert out["y"][:, 0].std() > 0.1
