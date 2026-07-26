"""Impeller NK (~1 Hz).

1–2 % après étalonnage ; non linéaire sous 2 m/s ; salissure.
"""
from __future__ import annotations

import numpy as np

from .base import VirtualSensor
from .primitives import bias, white_noise


class ImpellerSensor(VirtualSensor):
    name = "impeller"
    cost_eur = 80.0
    mass_g = 50.0

    def __init__(
        self,
        fe_hz: float = 1.0,
        rng_seed: int | None = None,
        *,
        calib_error_frac: float = 0.015,  # 1,5 %
        fouling_frac: float = 0.0,
        low_speed_threshold_ms: float = 2.0,
        low_speed_extra_frac: float = 0.05,
    ):
        super().__init__(fe_hz, rng_seed)
        self.calib_error_frac = float(calib_error_frac)
        self.fouling_frac = float(fouling_frac)
        self.low_speed_threshold_ms = float(low_speed_threshold_ms)
        self.low_speed_extra_frac = float(low_speed_extra_frac)
        self._scale = 1.0 + float(self.rng.normal(0.0, self.calib_error_frac))

    def apply_errors(self, signal: np.ndarray, t: np.ndarray, **props) -> np.ndarray:
        v = np.asarray(signal, dtype=float).copy()
        scale = self._scale * (1.0 - self.fouling_frac)
        y = v * scale
        # non-linéaire sous 2 m/s
        low = np.abs(v) < self.low_speed_threshold_ms
        y = np.where(low, y * (1.0 - self.low_speed_extra_frac), y)
        sigma = 0.01 * np.maximum(np.abs(v), 0.5)
        y = white_noise(y, float(np.mean(sigma)), self.rng)
        return y
