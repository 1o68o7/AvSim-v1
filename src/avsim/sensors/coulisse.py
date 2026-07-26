"""Coulisse ToF — VL53L1X (100 Hz).

σ 1–3 mm ; **dégradation forte en plein soleil**.
"""
from __future__ import annotations

import numpy as np

from .base import VirtualSensor
from .primitives import bias, quantize, white_noise


class CoulisseSensor(VirtualSensor):
    name = "coulisse"
    cost_eur = 12.0
    mass_g = 8.0

    def __init__(
        self,
        fe_hz: float = 100.0,
        rng_seed: int | None = None,
        *,
        sigma_m: float = 0.002,  # 2 mm nominal
        sun_sigma_m: float = 0.015,  # dégradation plein soleil
        bias_m: float = 0.0,
        resolution_m: float = 0.001,
    ):
        super().__init__(fe_hz, rng_seed)
        self.sigma_m = float(sigma_m)
        self.sun_sigma_m = float(sun_sigma_m)
        self.bias_m = float(bias_m)
        self.resolution_m = float(resolution_m)

    def apply_errors(
        self,
        signal: np.ndarray,
        t: np.ndarray,
        *,
        sunlight: bool = False,
        **kwargs,
    ) -> np.ndarray:
        sigma = self.sun_sigma_m if sunlight else self.sigma_m
        y = bias(signal, self.bias_m)
        y = white_noise(y, sigma, self.rng)
        y = quantize(y, self.resolution_m)
        return y
