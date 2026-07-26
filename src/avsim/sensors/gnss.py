"""GNSS standard NEO-M9N (10 Hz) et RTK ZED-F9P (10 Hz)."""
from __future__ import annotations

import numpy as np

from .base import VirtualSensor
from .primitives import bias, white_noise


class GnssStandardSensor(VirtualSensor):
    name = "gnss_standard"
    cost_eur = 45.0
    mass_g = 30.0

    def __init__(
        self,
        fe_hz: float = 10.0,
        rng_seed: int | None = None,
        *,
        pos_sigma_m: float = 1.5,  # ~CEP 1,5 m → σ ordre CEP
        vel_sigma_ms: float = 0.05,
        multipath_sigma_m: float = 0.8,
    ):
        super().__init__(fe_hz, rng_seed)
        self.pos_sigma_m = float(pos_sigma_m)
        self.vel_sigma_ms = float(vel_sigma_ms)
        self.multipath_sigma_m = float(multipath_sigma_m)

    def apply_errors(
        self,
        signal: np.ndarray,
        t: np.ndarray,
        *,
        near_bank: bool = False,
        channel: str = "position",
        **kwargs,
    ) -> np.ndarray:
        """signal = position (m) ou vitesse (m/s) selon `channel`."""
        y = np.asarray(signal, dtype=float).copy()
        if channel == "velocity":
            return white_noise(y, self.vel_sigma_ms, self.rng)
        sigma = self.pos_sigma_m
        if near_bank:
            sigma = np.hypot(sigma, self.multipath_sigma_m)
        return white_noise(y, sigma, self.rng)


class GnssRtkSensor(VirtualSensor):
    name = "gnss_rtk"
    cost_eur = 270.0
    mass_g = 60.0

    def __init__(
        self,
        fe_hz: float = 10.0,
        rng_seed: int | None = None,
        *,
        pos_sigma_m: float = 0.015,  # 1–2 cm
        vel_sigma_ms: float = 0.02,
        float_sigma_m: float = 1.2,  # sans fix → ~GNSS standard
    ):
        super().__init__(fe_hz, rng_seed)
        self.pos_sigma_m = float(pos_sigma_m)
        self.vel_sigma_ms = float(vel_sigma_ms)
        self.float_sigma_m = float(float_sigma_m)

    def apply_errors(
        self,
        signal: np.ndarray,
        t: np.ndarray,
        *,
        under_trees: bool = False,
        channel: str = "position",
        **kwargs,
    ) -> np.ndarray:
        """**Perte de fix sous les arbres** → bascule en solution float/bruitée."""
        y = np.asarray(signal, dtype=float).copy()
        if channel == "velocity":
            sig = self.vel_sigma_ms * (5.0 if under_trees else 1.0)
            return white_noise(y, sig, self.rng)
        sigma = self.float_sigma_m if under_trees else self.pos_sigma_m
        return white_noise(y, sigma, self.rng)
