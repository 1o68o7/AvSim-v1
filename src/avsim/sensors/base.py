"""Interface commune des capteurs virtuels — brief §7."""
from __future__ import annotations

from abc import ABC, abstractmethod

import numpy as np
from numpy.typing import ArrayLike


class VirtualSensor(ABC):
    """Capteur virtuel : vérité terrain → échantillons à sa propre cadence.

    Le ré-échantillonnage à `fe_hz` est centralisé ici — un impeller ~1 Hz
    ne reçoit pas 200 évaluations/s de la vérité terrain en sortie.
    """

    name: str = "virtual"
    cost_eur: float = 0.0
    mass_g: float = 0.0

    def __init__(self, fe_hz: float, rng_seed: int | None = None):
        if fe_hz <= 0:
            raise ValueError(f"fe_hz doit être > 0, reçu {fe_hz}")
        self.fe_hz = float(fe_hz)
        self.rng = np.random.default_rng(rng_seed)

    def resample(
        self,
        ground_truth_signal: ArrayLike,
        t: ArrayLike,
    ) -> tuple[np.ndarray, np.ndarray]:
        """Sous-échantillonne (t, signal) à fe_hz par plus proche voisin temporel."""
        tt = np.asarray(t, dtype=float).ravel()
        x = np.asarray(ground_truth_signal, dtype=float)
        if tt.size == 0:
            return tt.copy(), x.copy()
        t0, t1 = float(tt[0]), float(tt[-1])
        if t1 <= t0:
            return np.array([t0]), np.array([x.ravel()[0]])
        n = max(1, int(np.floor((t1 - t0) * self.fe_hz)) + 1)
        t_out = t0 + np.arange(n) / self.fe_hz
        t_out = t_out[t_out <= t1 + 0.5 / self.fe_hz]
        idx = np.searchsorted(tt, t_out, side="left")
        idx = np.clip(idx, 0, tt.size - 1)
        # plus proche
        left = np.clip(idx - 1, 0, tt.size - 1)
        choose_left = np.abs(tt[left] - t_out) <= np.abs(tt[idx] - t_out)
        idx = np.where(choose_left, left, idx)
        if x.ndim == 1:
            return t_out, x[idx]
        return t_out, x[idx, ...]

    def sample(
        self,
        ground_truth_signal: ArrayLike,
        t: ArrayLike,
        **kwargs,
    ) -> dict[str, np.ndarray]:
        """Retourne dict avec au minimum `t` et `y` à la cadence du capteur."""
        t_s, x_s = self.resample(ground_truth_signal, t)
        y = self.apply_errors(x_s, t_s, **kwargs)
        return {"t": t_s, "y": y}

    @abstractmethod
    def apply_errors(
        self,
        signal: np.ndarray,
        t: np.ndarray,
        **kwargs,
    ) -> np.ndarray:
        """Chaîne d'erreurs propre au capteur, déjà à fe_hz."""
