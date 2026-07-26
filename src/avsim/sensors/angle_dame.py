"""Angle dame — AS5600 (200 Hz).

12 bits = 0,088° ; INL 0,3° ; excentration d'aimant.
"""
from __future__ import annotations

import numpy as np

from .base import VirtualSensor
from .primitives import bias, quantize, white_noise

LSB_DEG = 360.0 / 4096.0  # 0,08789° ≈ 0,088°
INL_DEG = 0.3


class AngleDameSensor(VirtualSensor):
    name = "angle_dame"
    cost_eur = 4.0
    mass_g = 10.0

    def __init__(
        self,
        fe_hz: float = 200.0,
        rng_seed: int | None = None,
        *,
        bias_deg: float = 0.0,
        eccentricity_deg: float = 0.15,
        inl_deg: float = INL_DEG,
    ):
        super().__init__(fe_hz, rng_seed)
        self.bias_deg = float(bias_deg)
        self.eccentricity_deg = float(eccentricity_deg)
        self.inl_deg = float(inl_deg)
        # phase d'excentration fixe pour une graine
        self._ecc_phase = float(self.rng.uniform(0, 2 * np.pi))

    def apply_errors(self, signal: np.ndarray, t: np.ndarray, **kwargs) -> np.ndarray:
        # signal en radians → travail en degrés
        deg = np.degrees(signal.astype(float, copy=True))
        # INL : erreur sinusoïdale d'amplitude inl (harmonique 1 sur le tour)
        deg = deg + self.inl_deg * np.sin(np.radians(deg))
        # Excentration d'aimant → erreur 1× tour
        deg = deg + self.eccentricity_deg * np.sin(
            np.radians(deg) + self._ecc_phase
        )
        deg = bias(deg, self.bias_deg)
        # bruit ~ ½ LSB
        deg = white_noise(deg, LSB_DEG * 0.5, self.rng)
        deg = quantize(deg, LSB_DEG)
        return np.radians(deg)
