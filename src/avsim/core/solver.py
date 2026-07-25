"""Integration temporelle, decoupage en coups, bilan energetique.

Brief 5 (numerique) et 3.3 / 8.1 (bilan).
"""
from __future__ import annotations

from dataclasses import dataclass

import numpy as np
from scipy.integrate import solve_ivp

from .dynamics import Crew
from .forces import aero_drag, hull_drag


@dataclass
class Stroke:
    t: np.ndarray
    V: np.ndarray            # vitesse coque / eau
    V_ground: np.ndarray
    theta: np.ndarray        # (n_seats, n)
    theta_dot: np.ndarray
    F_prop: np.ndarray
    F_blade_x: np.ndarray    # (n_seats, n)
    P_blade_loss: np.ndarray # (n_seats, n)
    handle_force: np.ndarray # (n_seats, n)
    pin_force: np.ndarray
    foot_force: np.ndarray
    com_rel: np.ndarray      # CdM equipage pondere, relatif coque
    immersion: np.ndarray
    D_hull: np.ndarray
    D_aero: np.ndarray
    m_total: float
    handle_power: np.ndarray

    def drive_mask(self) -> np.ndarray:
        return self.immersion[0] > 0.5

    def energy(self) -> dict:
        t = self.t
        E_prop = np.trapezoid(self.F_prop * self.V, t)
        E_hull = np.trapezoid(self.D_hull * self.V, t)
        E_aero = np.trapezoid(self.D_aero * self.V, t)
        E_blade_loss = np.trapezoid(self.P_blade_loss.sum(axis=0), t)
        E_handle = np.trapezoid(self.handle_power.sum(axis=0), t)

        # terme d'echange cinetique : integrale de (somme m_i s_i'') * V
        dEk = E_prop - E_hull - E_aero

        T = t[-1] - t[0]
        eta = E_prop / (E_prop + E_blade_loss) if (E_prop + E_blade_loss) > 0 else np.nan
        return {
            "E_prop_J": float(E_prop),
            "E_hull_drag_J": float(E_hull),
            "E_aero_J": float(E_aero),
            "E_blade_loss_J": float(E_blade_loss),
            "E_rower_J": float(E_handle),
            "dE_kinetic_J": float(dEk),
            "eta_blade": float(eta),
            "P_rower_mean_W": float(E_handle / T / self.handle_force.shape[0]),
            "v_mean_ms": float(self.V.mean()),
            "v_min_ms": float(self.V.min()),
            "v_max_ms": float(self.V.max()),
            "check_factor": float(self.V.max() - self.V.min()),
            "stroke_period_s": float(T),
        }


class Result:
    def __init__(self, t, V, P, crew: Crew, n_keep: int):
        self.P, self.crew = P, crew
        self.t, self.V = t, V
        self.T = crew.T
        self.n_keep = n_keep
        self._cache: dict[int, Stroke] = {}

    def stroke(self, idx: int) -> Stroke:
        if idx in self._cache:
            return self._cache[idx]
        n_str = int(round((self.t[-1] - self.t[0]) / self.T))
        i = n_str + idx if idx < 0 else idx
        t0, t1 = self.t[0] + i * self.T, self.t[0] + (i + 1) * self.T
        m = (self.t >= t0 - 1e-12) & (self.t <= t1 + 1e-12)
        st = self._build(self.t[m], self.V[m])
        self._cache[idx] = st
        return st

    def last_stroke(self) -> Stroke:
        return self.stroke(-1)

    def _build(self, t, V) -> Stroke:
        c = self.crew
        rho_w, nu_w, rho_a = c.fluid()
        e = self.P["environment"]

        th, thd = c.theta(t), c.theta_dot(t)
        fx, _fy, p_loss, _al, _sp = c.blade(t, V, rho_w)
        internals = c.internal_forces(t, V, rho_w)

        D_h = hull_drag(V, self.P, rho_w, nu_w)
        V_g = V + e["current_ms"]
        D_a, _ = aero_drag(V_g, self.P, rho_a, e["wind_axial_ms"])

        # puissance a la poignee, referentiel eau
        L_in = self.P["rig"]["L_in_m"]
        vhx = -L_in * np.cos(th) * thd + V[None, :]
        vhy = L_in * np.sin(th) * thd
        fhx, fhy = internals["handle_xy"]
        p_handle = fhx * vhx + fhy * vhy

        com = c.com(t)
        com_w = (c.masses[:, None] * com).sum(axis=0) / c.M

        return Stroke(
            t=t, V=V, V_ground=V_g, theta=th, theta_dot=thd,
            F_prop=fx.sum(axis=0), F_blade_x=fx, P_blade_loss=p_loss,
            handle_force=internals["handle"], pin_force=internals["pin_normal"],
            foot_force=internals["foot"], com_rel=com_w,
            immersion=c.immersion(t), D_hull=D_h, D_aero=D_a,
            m_total=c.m_boat + c.M, handle_power=p_handle)


def simulate(P: dict) -> Result:
    """Integre n_strokes coups et retourne le resultat reechantillonne."""
    crew = Crew(P)
    n = P["numerics"]
    rho_w, nu_w, rho_a = crew.fluid()

    t_end = n["n_strokes"] * crew.T
    dt = 1.0 / n["output_hz"]
    t_eval = np.arange(0.0, t_end + 0.5 * dt, dt)
    t_eval = t_eval[t_eval <= t_end]

    def f(t, y):
        return np.atleast_1d(crew.rhs(t, y[0], rho_w, nu_w, rho_a)).ravel()[:1]

    sol = solve_ivp(f, (0.0, t_end), [n["v_init_ms"]],
                    t_eval=t_eval, method=n["method"],
                    rtol=n["rtol"], atol=n["atol"], max_step=crew.T / 40.0)
    if not sol.success:
        raise RuntimeError(f"integration echouee : {sol.message}")

    keep_from = n["n_discard"] * crew.T
    m = sol.t >= keep_from - 1e-12
    return Result(sol.t[m], sol.y[0][m], P, crew, n["n_strokes"] - n["n_discard"])
