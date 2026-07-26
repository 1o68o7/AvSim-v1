"""Briques d'erreur composables — une seule implémentation pour tous les capteurs.

Brief §7 : bruit blanc, biais, dérive lente, quantification, bande passante,
sensibilité thermique. Les capteurs composent ces primitives, ne les
réimplémentent pas.
"""
from __future__ import annotations

import numpy as np
from numpy.typing import ArrayLike


def as_float_array(signal: ArrayLike) -> np.ndarray:
    return np.asarray(signal, dtype=float)


def white_noise(
    signal: ArrayLike,
    sigma: float,
    rng: np.random.Generator,
) -> np.ndarray:
    """Bruit blanc gaussien additif, σ en unités du signal."""
    x = as_float_array(signal)
    if sigma <= 0:
        return x.copy()
    return x + rng.normal(0.0, sigma, size=x.shape)


def bias(signal: ArrayLike, offset: float) -> np.ndarray:
    """Biais constant (offset) — testé séparément du bruit blanc."""
    return as_float_array(signal) + float(offset)


def slow_drift(
    signal: ArrayLike,
    t: ArrayLike,
    rate_per_hour: float,
    rng: np.random.Generator,
    *,
    phase: float | None = None,
) -> np.ndarray:
    """Dérive lente linéaire en temps (rate_per_hour × heures écoulées).

    `phase` optionnel (unités signal) tire un offset initial aléatoire si None,
    pour que la dérive ne soit pas toujours ancrée à zéro au premier échantillon.
    """
    x = as_float_array(signal)
    tt = as_float_array(t)
    if phase is None:
        phase = float(rng.normal(0.0, abs(rate_per_hour) * 1e-3 + 1e-12))
    hours = (tt - tt[0]) / 3600.0 if tt.size else tt
    return x + float(phase) + float(rate_per_hour) * hours


def quantize(signal: ArrayLike, resolution: float) -> np.ndarray:
    """Quantification uniforme (pas = resolution). resolution≤0 → no-op."""
    x = as_float_array(signal)
    r = float(resolution)
    if r <= 0:
        return x.copy()
    return np.round(x / r) * r


def bandwidth_limit(
    signal: ArrayLike,
    cutoff_hz: float,
    fe_hz: float,
) -> np.ndarray:
    """Filtre passe-bas Butterworth 1er ordre (discret) — bande passante capteur."""
    x = as_float_array(signal)
    fc = float(cutoff_hz)
    fe = float(fe_hz)
    if fc <= 0 or fe <= 0 or fc >= 0.5 * fe:
        return x.copy()
    # y[n] = a * x[n] + (1-a) * y[n-1], a = dt / (RC + dt), RC = 1/(2π fc)
    dt = 1.0 / fe
    rc = 1.0 / (2.0 * np.pi * fc)
    a = dt / (rc + dt)
    y = np.empty_like(x)
    if x.ndim == 1:
        y[0] = x[0]
        for i in range(1, x.size):
            y[i] = a * x[i] + (1.0 - a) * y[i - 1]
        return y
    # multi-canal : filtre chaque colonne / dernière axe
    y[..., 0] = x[..., 0]
    for i in range(1, x.shape[-1]):
        y[..., i] = a * x[..., i] + (1.0 - a) * y[..., i - 1]
    return y


def thermal_sensitivity(
    signal: ArrayLike,
    coeff_per_degC: float,
    temp_profile: ArrayLike,
    *,
    t_ref_C: float = 20.0,
) -> np.ndarray:
    """Erreur additive proportional to (T − T_ref) × coeff.

    Pour une dérive en %PE/°C, passer coeff = (%PE/100) * full_scale / °C
    déjà converti en unités signal côté capteur.
    """
    x = as_float_array(signal)
    T = as_float_array(temp_profile)
    if T.shape != x.shape:
        T = np.broadcast_to(T, x.shape)
    return x + float(coeff_per_degC) * (T - float(t_ref_C))


def hysteresis(
    signal: ArrayLike,
    width: float,
) -> np.ndarray:
    """Hystérésis simple (bande morte directionnelle), width ≥ 0."""
    x = as_float_array(signal)
    w = abs(float(width))
    if w <= 0 or x.size < 2:
        return x.copy()
    y = np.empty_like(x)
    y[0] = x[0]
    for i in range(1, x.size):
        dx = x[i] - x[i - 1]
        if abs(dx) <= w:
            y[i] = y[i - 1]
        else:
            y[i] = x[i] - np.sign(dx) * w
    return y


def nonlinearity_quadratic(
    signal: ArrayLike,
    full_scale: float,
    nl_frac: float,
) -> np.ndarray:
    """Non-linéarité ~ nl_frac × PE sous forme quadratique normalisée."""
    x = as_float_array(signal)
    fs = float(full_scale)
    if fs <= 0 or abs(nl_frac) < 1e-15:
        return x.copy()
    u = x / fs
    return x + float(nl_frac) * fs * (u * u - u)
