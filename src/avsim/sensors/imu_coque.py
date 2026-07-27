"""IMU coque — ICM-42688-P (200 Hz) + vibration structurelle."""
from __future__ import annotations

import numpy as np

from .base import VirtualSensor
from .primitives import bias, slow_drift, white_noise
from .pod_dorsal import ACCEL_ND, GYRO_ND


class ImuCoqueSensor(VirtualSensor):
    name = "imu_coque"
    cost_eur = 28.0
    mass_g = 25.0

    def __init__(
        self,
        fe_hz: float = 200.0,
        rng_seed: int | None = None,
        *,
        structural_vibration_ms2: float = 0.8,
        bias_accel: float = 0.0,
        bias_gyro: float = 0.0,
    ):
        super().__init__(fe_hz, rng_seed)
        self.structural_vibration_ms2 = float(structural_vibration_ms2)
        self.bias_accel = float(bias_accel)
        self.bias_gyro = float(bias_gyro)

    def apply_errors(self, signal: np.ndarray, t: np.ndarray, **props) -> np.ndarray:
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
            col = bias(col, b0)
            col = slow_drift(
                col, t,
                rate_per_hour=(np.radians(5.0) if is_gyro else 0.02),
                rng=self.rng, phase=0.0,
            )
            col = white_noise(col, sigma, self.rng)
            if not is_gyro:
                # vibration structurelle (bande large)
                col = white_noise(col, self.structural_vibration_ms2, self.rng)
            out[:, i] = col
        return out[:, 0] if single else out
