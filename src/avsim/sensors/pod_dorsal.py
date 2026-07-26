"""Pod dorsal IMU — ICM-42688-P (100 Hz).

accel 70 µg/√Hz ; gyro 2,8 mdps/√Hz ; **dérive de biais** ;
artefacts de fixation sur tissu mou.
"""
from __future__ import annotations

import numpy as np

from .base import VirtualSensor
from .primitives import bias, slow_drift, white_noise

# Densités spectrales → σ sur bande ~fe/2
ACCEL_ND = 70e-6 * 9.80665  # m/s²/√Hz
GYRO_ND = np.radians(2.8e-3)  # rad/s/√Hz


class PodDorsalSensor(VirtualSensor):
    name = "pod_dorsal"
    cost_eur = 28.0
    mass_g = 30.0

    def __init__(
        self,
        fe_hz: float = 100.0,
        rng_seed: int | None = None,
        *,
        soft_tissue_sigma: float = 0.4,  # m/s² artefacts tissu
        bias_accel: float = 0.0,
        bias_gyro: float = 0.0,
        drift_accel_per_hour: float = 0.05,
        drift_gyro_per_hour: float = np.radians(10.0),  # ~10 °/h
    ):
        super().__init__(fe_hz, rng_seed)
        self.soft_tissue_sigma = float(soft_tissue_sigma)
        self.bias_accel = float(bias_accel)
        self.bias_gyro = float(bias_gyro)
        self.drift_accel_per_hour = float(drift_accel_per_hour)
        self.drift_gyro_per_hour = float(drift_gyro_per_hour)

    def apply_errors(self, signal: np.ndarray, t: np.ndarray, **props) -> np.ndarray:
        """signal shape (N, 6) : ax,ay,az,gx,gy,gz — ou (N,) traité comme ax."""
        y = np.asarray(signal, dtype=float)
        single = y.ndim == 1
        if single:
            y = y[:, None]
        n, c = y.shape
        bw = 0.5 * self.fe_hz
        sig_a = ACCEL_ND * np.sqrt(bw)
        sig_g = GYRO_ND * np.sqrt(bw)
        out = np.empty_like(y)
        for i in range(c):
            col = y[:, i]
            is_gyro = i >= 3
            sigma = sig_g if is_gyro else sig_a
            b0 = self.bias_gyro if is_gyro else self.bias_accel
            rate = self.drift_gyro_per_hour if is_gyro else self.drift_accel_per_hour
            col = bias(col, b0)
            # **dérive de biais**
            col = slow_drift(col, t, rate, self.rng, phase=0.0)
            col = white_noise(col, sigma, self.rng)
            if not is_gyro:
                # **artefacts fixation tissu mou**
                col = white_noise(col, self.soft_tissue_sigma, self.rng)
            out[:, i] = col
        return out[:, 0] if single else out
