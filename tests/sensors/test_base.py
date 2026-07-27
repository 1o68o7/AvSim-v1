"""Tests VirtualSensor — ré-échantillonnage à fe propre."""
from __future__ import annotations

import numpy as np
import pytest

from avsim.sensors.base import VirtualSensor


class _Passthrough(VirtualSensor):
    name = "passthrough"

    def apply_errors(self, signal, t, **kwargs):
        return signal


def test_resample_impeller_like_1hz_not_200() -> None:
    fe_truth = 200.0
    t = np.arange(0, 5.0, 1 / fe_truth)
    x = np.sin(2 * np.pi * 0.2 * t)
    s = _Passthrough(fe_hz=1.0, rng_seed=0)
    out = s.sample(x, t)
    # ~5 s à 1 Hz → ~6 points (0..5 inclus)
    assert 5 <= out["t"].size <= 7
    assert out["y"].size == out["t"].size
    assert out["t"].size < 0.1 * t.size


def test_resample_preserves_endpoints_approx() -> None:
    t = np.linspace(0, 1, 201)
    x = t * 2
    s = _Passthrough(fe_hz=50.0, rng_seed=1)
    out = s.sample(x, t)
    assert out["t"][0] == pytest.approx(0.0)
    assert abs(out["y"][-1] - 2.0) < 0.05
