"""Filtre de Kalman étendu minimal — grandeurs de tableau de bord.

État : ``[V, x_com]``
  - ``V``     vitesse bateau (m/s)
  - ``x_com`` position CdM équipage relative (m), même convention que
    ``Stroke.com_rel``

Destiné à tourner tel quel sur le calculateur embarqué : NumPy seulement,
pas de dépendance lourde (brief §13).

Mesures supportées (linéaires → EKF = KF ici ; Jacobienne H fournie pour
rester en forme EKF si h non linéaire plus tard) :
  - ``V``     : impeller, GNSS vitesse
  - ``x_com`` : coulisse / pod (proxy CdM, bruit R plus large)
  - ``accel`` : IMU coque — utilisée en **prédiction** (V ← V + a·dt),
    pas comme mesure d'état directe

Pilote Mode C : classe 2x uniquement — voir ``analysis.observability``.
"""
from __future__ import annotations

from dataclasses import dataclass

import numpy as np
from numpy.typing import ArrayLike


@dataclass
class EKFConfig:
    """Bruits de processus / init — ordres de grandeur tableau de bord."""
    q_v: float = 0.05**2          # (m/s)² / s
    q_com: float = 0.02**2        # m² / s
    p0_v: float = 1.0**2
    p0_com: float = 0.5**2
    v0: float = 4.0
    x_com0: float = 0.0


class DashboardEKF:
    """EKF 2-états pour V bateau et CdM équipage."""

    def __init__(self, config: EKFConfig | None = None):
        self.cfg = config or EKFConfig()
        self.x = np.array([self.cfg.v0, self.cfg.x_com0], dtype=float)
        self.P = np.diag([self.cfg.p0_v, self.cfg.p0_com]).astype(float)

    @property
    def V(self) -> float:
        return float(self.x[0])

    @property
    def x_com(self) -> float:
        return float(self.x[1])

    def reset(self, v: float | None = None, x_com: float | None = None) -> None:
        self.x[0] = self.cfg.v0 if v is None else float(v)
        self.x[1] = self.cfg.x_com0 if x_com is None else float(x_com)
        self.P[:, :] = np.diag([self.cfg.p0_v, self.cfg.p0_com])

    def predict(self, dt: float, accel: float | None = None) -> None:
        """Prédiction : V += a·dt (si IMU), x_com en marche aléatoire."""
        dt = float(max(dt, 0.0))
        if dt <= 0.0:
            return
        if accel is not None:
            self.x[0] = self.x[0] + float(accel) * dt
        # F = I (dynamique intégrée dans le contrôle accel)
        q = np.diag([self.cfg.q_v * dt, self.cfg.q_com * dt])
        self.P = self.P + q

    def update(self, z: ArrayLike, H: ArrayLike, R: ArrayLike) -> None:
        """Mise à jour EKF (h linéaire : H = ∂h/∂x)."""
        z = np.atleast_1d(np.asarray(z, dtype=float))
        H = np.atleast_2d(np.asarray(H, dtype=float))
        R = np.asarray(R, dtype=float)
        if R.ndim == 0:
            R = np.array([[float(R)]])
        elif R.ndim == 1:
            R = np.diag(R)
        # innovation
        z_pred = H @ self.x
        y = z - z_pred
        S = H @ self.P @ H.T + R
        # Kalman gain
        try:
            K = self.P @ H.T @ np.linalg.inv(S)
        except np.linalg.LinAlgError:
            K = self.P @ H.T @ np.linalg.pinv(S)
        self.x = self.x + K @ y
        I = np.eye(2)
        self.P = (I - K @ H) @ self.P
        # symétrie numérique
        self.P = 0.5 * (self.P + self.P.T)

    def update_velocity(self, v_meas: float, r: float) -> None:
        self.update(v_meas, H=[[1.0, 0.0]], R=r)

    def update_com(self, x_com_meas: float, r: float) -> None:
        self.update(x_com_meas, H=[[0.0, 1.0]], R=r)

    def run(
        self,
        t: ArrayLike,
        *,
        v_meas: ArrayLike | None = None,
        v_R: float = 0.05**2,
        com_meas: ArrayLike | None = None,
        com_R: float = 0.03**2,
        accel: ArrayLike | None = None,
    ) -> dict[str, np.ndarray]:
        """Boucle predict/update sur une série temporelle.

        Les mesures absentes (`None`) sont ignorées — sous-ensemble Mode C.
        """
        tt = np.asarray(t, dtype=float).ravel()
        n = tt.size
        if n == 0:
            return {
                "t": tt,
                "V": np.array([]),
                "x_com": np.array([]),
            }
        v_m = None if v_meas is None else np.asarray(v_meas, dtype=float).ravel()
        c_m = None if com_meas is None else np.asarray(com_meas, dtype=float).ravel()
        a_m = None if accel is None else np.asarray(accel, dtype=float).ravel()

        V_out = np.empty(n)
        com_out = np.empty(n)
        for i in range(n):
            dt = 0.0 if i == 0 else float(tt[i] - tt[i - 1])
            acc = None if a_m is None else float(a_m[min(i, a_m.size - 1)])
            self.predict(dt, accel=acc)
            if v_m is not None:
                self.update_velocity(float(v_m[min(i, v_m.size - 1)]), v_R)
            if c_m is not None:
                self.update_com(float(c_m[min(i, c_m.size - 1)]), com_R)
            V_out[i] = self.V
            com_out[i] = self.x_com
        return {"t": tt, "V": V_out, "x_com": com_out}
