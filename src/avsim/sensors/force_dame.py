"""Force à la dame — jauges + ADS131M04 (200 Hz).

Erreurs : 20–21 bits effectifs ; non-linéarité 0,05 % PE ; hystérésis ;
dérive 0,002 %PE/°C ; **sensibilité parasite à l'effort axial**.
"""
from __future__ import annotations

import numpy as np

from .base import VirtualSensor
from .primitives import (
    bias,
    hysteresis,
    nonlinearity_quadratic,
    quantize,
    slow_drift,
    thermal_sensitivity,
    white_noise,
)

# Pleine échelle typique jauge dame (N) — pour %PE et quantification.
FULL_SCALE_N = 2000.0
# 20,5 bits effectifs sur ±FS → LSB ≈ 2*FS / 2^20.5
_BITS_EFF = 20.5
LSB_N = (2.0 * FULL_SCALE_N) / (2.0 ** _BITS_EFF)


class ForceDameSensor(VirtualSensor):
    name = "force_dame"
    cost_eur = 95.0
    mass_g = 60.0

    def __init__(
        self,
        fe_hz: float = 200.0,
        rng_seed: int | None = None,
        *,
        sigma_N: float | None = None,
        bias_N: float = 0.0,
        nl_frac: float = 0.0005,  # 0,05 % PE
        hyst_N: float = 1.0,
        drift_pctPE_per_C: float = 0.002,
        axial_crosstalk: float = 0.02,  # fraction de F_axial → erreur
    ):
        super().__init__(fe_hz, rng_seed)
        # Bruit ~ ½ LSB en σ (ordre de grandeur ADS131)
        self.sigma_N = float(LSB_N * 0.5 if sigma_N is None else sigma_N)
        self.bias_N = float(bias_N)
        self.nl_frac = float(nl_frac)
        self.hyst_N = float(hyst_N)
        self.drift_pctPE_per_C = float(drift_pctPE_per_C)
        self.axial_crosstalk = float(axial_crosstalk)

    def apply_errors(
        self,
        signal: np.ndarray,
        t: np.ndarray,
        *,
        temp_C: float | np.ndarray = 20.0,
        F_axial: float | np.ndarray | None = None,
        **kwargs,
    ) -> np.ndarray:
        y = signal.astype(float, copy=True)
        # **Sensibilité parasite à l'effort axial** (erreur la plus facile à oublier)
        if F_axial is not None:
            Fax = np.asarray(F_axial, dtype=float)
            if Fax.shape != y.shape:
                # ré-échantillonner / broadcaster
                if Fax.size == 1:
                    Fax = np.full_like(y, float(Fax))
                else:
                    Fax = np.interp(
                        np.linspace(0, 1, y.size),
                        np.linspace(0, 1, Fax.size),
                        Fax.ravel(),
                    )
            y = y + self.axial_crosstalk * Fax
        y = nonlinearity_quadratic(y, FULL_SCALE_N, self.nl_frac)
        y = hysteresis(y, self.hyst_N)
        y = bias(y, self.bias_N)
        # dérive thermique en N/°C = (0,002 %PE/°C) * FS
        coeff = (self.drift_pctPE_per_C / 100.0) * FULL_SCALE_N
        if np.isscalar(temp_C):
            temp_profile = np.full_like(y, float(temp_C))
        else:
            temp_profile = np.asarray(temp_C, dtype=float)
            if temp_profile.shape != y.shape:
                temp_profile = np.full_like(y, float(temp_profile.ravel()[0]))
        y = thermal_sensitivity(y, coeff, temp_profile)
        # dérive lente temporelle (très faible, séparée)
        y = slow_drift(y, t, rate_per_hour=0.05, rng=self.rng, phase=0.0)
        y = white_noise(y, self.sigma_N, self.rng)
        y = quantize(y, LSB_N)
        return y
