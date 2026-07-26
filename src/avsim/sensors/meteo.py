"""Météo : anémomètres rive/embarqués + température eau."""
from __future__ import annotations

import numpy as np

from .base import VirtualSensor
from .primitives import bias, white_noise


class AnemoRiveSensor(VirtualSensor):
    """Ecowitt WS80 — **0,06 Hz (période 16 s)** : les rafales sont invisibles."""

    name = "anemo_rive"
    cost_eur = 100.0
    mass_g = 0.0

    def __init__(
        self,
        fe_hz: float = 1.0 / 16.0,  # 0,0625 Hz
        rng_seed: int | None = None,
        *,
        sigma_ms: float = 0.3,
    ):
        super().__init__(fe_hz, rng_seed)
        self.sigma_ms = float(sigma_ms)

    def apply_errors(self, signal: np.ndarray, t: np.ndarray, **props) -> np.ndarray:
        # Après resample à ~16 s, le signal est déjà un sous-échantillon :
        # les rafales entre deux points sont perdues par construction.
        return white_noise(signal, self.sigma_ms, self.rng)


class AnemoEmbarqueSensor(VirtualSensor):
    """Calypso / FT205 — 1–4 Hz ; perturbation d'écoulement autour du bateau."""

    name = "anemo_embarque"
    cost_eur = 450.0
    mass_g = 200.0

    def __init__(
        self,
        fe_hz: float = 2.0,
        rng_seed: int | None = None,
        *,
        sigma_ms: float = 0.5,
        flow_bias_ms: float = 0.2,
    ):
        super().__init__(fe_hz, rng_seed)
        self.sigma_ms = float(sigma_ms)
        self.flow_bias_ms = float(flow_bias_ms)

    def apply_errors(self, signal: np.ndarray, t: np.ndarray, **props) -> np.ndarray:
        y = bias(signal, self.flow_bias_ms)  # perturbation écoulement
        return white_noise(y, self.sigma_ms, self.rng)


class TemperatureEauSensor(VirtualSensor):
    """DS18B20 — 0,2 Hz ; 0,5 °C ; constante de temps ~10 s."""

    name = "temperature_eau"
    cost_eur = 6.0
    mass_g = 15.0

    def __init__(
        self,
        fe_hz: float = 0.2,
        rng_seed: int | None = None,
        *,
        sigma_C: float = 0.5,
        tau_s: float = 10.0,
    ):
        super().__init__(fe_hz, rng_seed)
        self.sigma_C = float(sigma_C)
        self.tau_s = float(tau_s)

    def apply_errors(self, signal: np.ndarray, t: np.ndarray, **props) -> np.ndarray:
        x = np.asarray(signal, dtype=float)
        # constante de temps ~10 s (filtre 1er ordre sur la vérité déjà resamplee)
        y = np.empty_like(x)
        if x.size == 0:
            return x
        y[0] = x[0]
        for i in range(1, x.size):
            dt = float(t[i] - t[i - 1]) if t.size == x.size else 1.0 / self.fe_hz
            a = dt / (self.tau_s + dt)
            y[i] = a * x[i] + (1.0 - a) * y[i - 1]
        return white_noise(y, self.sigma_C, self.rng)
