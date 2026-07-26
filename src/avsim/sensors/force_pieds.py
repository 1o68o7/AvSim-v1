"""Force pieds ×2 — shear-beam 100 kg (200 Hz).

0,03 %PE ; hystérésis ; dérive. Deux canaux (gauche/droite) si signal 2D.
"""
from __future__ import annotations

import numpy as np

from .base import VirtualSensor
from .primitives import bias, hysteresis, quantize, slow_drift, white_noise

FULL_SCALE_N = 100.0 * 9.80665  # 100 kg
NL_FRAC = 0.0003  # 0,03 % PE


class ForcePiedsSensor(VirtualSensor):
    name = "force_pieds"
    cost_eur = 60.0
    mass_g = 400.0

    def __init__(
        self,
        fe_hz: float = 200.0,
        rng_seed: int | None = None,
        *,
        bias_N: float = 0.0,
        hyst_N: float = 0.5,
        sigma_frac_PE: float = 0.0003,
    ):
        super().__init__(fe_hz, rng_seed)
        self.bias_N = float(bias_N)
        self.hyst_N = float(hyst_N)
        self.sigma_N = float(sigma_frac_PE) * FULL_SCALE_N

    def apply_errors(self, signal: np.ndarray, t: np.ndarray, **kwargs) -> np.ndarray:
        y = np.asarray(signal, dtype=float).copy()
        flat = y.ndim == 1
        if flat:
            y = y[:, None]
        out = np.empty_like(y)
        for c in range(y.shape[1]):
            col = y[:, c]
            col = hysteresis(col, self.hyst_N)
            col = bias(col, self.bias_N)
            col = slow_drift(col, t, rate_per_hour=0.1, rng=self.rng, phase=0.0)
            col = white_noise(col, self.sigma_N, self.rng)
            col = quantize(col, self.sigma_N)  # résolution ~ σ
            out[:, c] = col
        return out[:, 0] if flat else out
