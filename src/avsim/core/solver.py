"""Integration temporelle, decoupage en coups, bilan energetique.

Brief §4 (fermeture force) + §6 (numerique) + §8.1 (bilan).

Etat integre : y = [V, theta_0..theta_{n-1}, omega_0..omega_{n-1}].
Evenements terminaux : degage (theta <= theta_finish) et attaque (t = catch).
"""
from __future__ import annotations

from dataclasses import dataclass

import numpy as np
from scipy.integrate import solve_ivp

from .dynamics import Crew
from .forces import aero_drag, hull_drag
from .geometry import handle_position


@dataclass
class Stroke:
    t: np.ndarray
    V: np.ndarray
    V_ground: np.ndarray
    theta: np.ndarray
    theta_dot: np.ndarray
    F_prop: np.ndarray
    F_blade_x: np.ndarray
    P_blade_loss: np.ndarray
    handle_force: np.ndarray
    pin_force: np.ndarray
    foot_force: np.ndarray
    com_rel: np.ndarray
    immersion: np.ndarray
    D_hull: np.ndarray
    D_aero: np.ndarray
    m_total: float
    handle_power: np.ndarray
    oar_power_identity: np.ndarray  # diagnostic seul — pas un substitut de E_rower

    def drive_mask(self) -> np.ndarray:
        return self.immersion[0] > 0.5

    def energy(self) -> dict:
        t = self.t
        E_prop = np.trapezoid(self.F_prop * self.V, t)
        E_hull = np.trapezoid(self.D_hull * self.V, t)
        E_aero = np.trapezoid(self.D_aero * self.V, t)
        E_blade_loss = np.trapezoid(self.P_blade_loss.sum(axis=0), t)
        E_handle = np.trapezoid(self.handle_power.sum(axis=0), t)
        E_id = np.trapezoid(self.oar_power_identity, t)
        dEk = E_prop - E_hull - E_aero
        T = t[-1] - t[0]
        eta = E_prop / (E_prop + E_blade_loss) if (E_prop + E_blade_loss) > 0 else np.nan
        return {
            "E_prop_J": float(E_prop),
            "E_hull_drag_J": float(E_hull),
            "E_aero_J": float(E_aero),
            "E_blade_loss_J": float(E_blade_loss),
            "E_rower_J": float(E_handle),
            "E_oar_identity_J": float(E_id),  # diagnostic, jamais substitut
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
    def __init__(self, t, y, P, crew: Crew, n_keep: int, modes_along: np.ndarray):
        self.P, self.crew = P, crew
        self.t = t
        self.y = y
        self.V = y[0]
        self.T = crew.T
        self.n_keep = n_keep
        self._modes_along = modes_along
        self._cache: dict[int, Stroke] = {}

    def stroke(self, idx: int) -> Stroke:
        if idx in self._cache:
            return self._cache[idx]
        n_str = int(round((self.t[-1] - self.t[0]) / self.T))
        i = n_str + idx if idx < 0 else idx
        t0 = self.t[0] + i * self.T
        t1 = self.t[0] + (i + 1) * self.T
        m = (self.t >= t0 - 1e-12) & (self.t <= t1 + 1e-12)
        st = self._build(self.t[m], self.y[:, m], self._modes_along[:, m])
        self._cache[idx] = st
        return st

    def last_stroke(self) -> Stroke:
        return self.stroke(-1)

    def _build(self, t, y, modes) -> Stroke:
        c = self.crew
        n = c.n
        rho_w, nu_w, rho_a = c.fluid()
        e = self.P["environment"]

        V = y[0]
        th = y[1:1 + n]
        w = y[1 + n:1 + 2 * n]
        nt = t.size

        fx = np.zeros((n, nt))
        p_loss = np.zeros((n, nt))
        imm = np.zeros((n, nt))
        F_handle = np.zeros((n, nt))
        pin_n = np.zeros((n, nt))
        foot = np.zeros((n, nt))
        com = np.zeros((n, nt))

        saved = (c.mode.copy(), c.t_finish.copy(), c.t_catch.copy(),
                 c.t_next_catch.copy(), c.th_at_finish.copy(), c.w_at_finish.copy())
        try:
            # Reconstitue les instants d'attaque / degage le long du morceau
            for i in range(n):
                c.t_catch[i] = t[0] if modes[i, 0] == c.MODE_DRIVE else t[0] - 0.5 * c.T
                c.t_next_catch[i] = c.t_catch[i] + c.T
                c.t_finish[i] = np.nan

            for k in range(nt):
                for i in range(n):
                    prev = int(modes[i, k - 1]) if k > 0 else int(modes[i, 0])
                    cur = int(modes[i, k])
                    c.mode[i] = cur
                    if cur == c.MODE_DRIVE and (k == 0 or prev == c.MODE_RECOVERY):
                        c.t_catch[i] = float(t[k])
                        c.t_next_catch[i] = c.t_catch[i] + c.T
                        c.t_finish[i] = np.nan
                    elif cur == c.MODE_RECOVERY and (k == 0 or prev == c.MODE_DRIVE):
                        c.t_finish[i] = float(t[k])
                        c.th_at_finish[i] = float(th[i, k])
                        c.w_at_finish[i] = float(w[i, k])

                info = c.internal_forces(
                    float(t[k]), float(V[k]), th[:, k], w[:, k], rho_w)
                fx[:, k] = info["fx"]
                p_loss[:, k] = info["p_loss"]
                imm[:, k] = info["immersion"]
                F_handle[:, k] = info["handle"]
                pin_n[:, k] = info["pin_normal"]
                foot[:, k] = info["foot"]
                x_h = handle_position(th[:, k], c.L_in)[0]
                u = c.body.handle_progress(x_h)
                for i in range(n):
                    com[i, k] = float(c.body.com_x_from_handle(
                        x_h[i], float(u[i]),
                        drive=(int(modes[i, k]) == c.MODE_DRIVE)))
        finally:
            (c.mode[:], c.t_finish[:], c.t_catch[:],
             c.t_next_catch[:], c.th_at_finish[:], c.w_at_finish[:]) = saved

        D_h = hull_drag(V, self.P, rho_w, nu_w)
        V_g = V + e["current_ms"]
        D_a, _ = aero_drag(V_g, self.P, rho_a, e["wind_axial_ms"])

        # Puissance rameur independante — travail a la poignee sur l'aviron.
        # Avec Q_poignee = -L_in * F_pull (dynamics), P_i = Q_i * omega_i
        #   = -L_in * F_handle_i * omega_i.
        # Equivalent a F·v_poignee relatif au pin (referentiel coque).
        # Note : le F·v referentiel-eau de session 1 (vhx = V - L cos ω, …)
        # avec F_handle traction-positive ajoute un terme -F·V et inverse le
        # signe du travail rotatif ; ce n'est plus coherent avec Q = -L_in F.
        # Ne jamais substituer par l'identite Iθ''ω+F_prop V+P_blade (circulaire).
        p_handle = -c.L_in * F_handle * w

        # Diagnostic seul : identite de l'aviron (ne remplace pas E_rower)
        thdd = np.gradient(w, t, axis=1)
        p_identity = (
            (c.I_oar * thdd * w).sum(axis=0)
            + fx.sum(axis=0) * V
            + p_loss.sum(axis=0)
        )
        com_w = (c.masses[:, None] * com).sum(axis=0) / c.M

        return Stroke(
            t=t, V=V, V_ground=V_g, theta=th, theta_dot=w,
            F_prop=fx.sum(axis=0), F_blade_x=fx, P_blade_loss=p_loss,
            handle_force=F_handle, pin_force=pin_n, foot_force=foot,
            com_rel=com_w, immersion=imm, D_hull=D_h, D_aero=D_a,
            m_total=c.m_boat + c.M, handle_power=p_handle,
            oar_power_identity=p_identity)


def _snap_recovery(crew: Crew, t: float, y: np.ndarray) -> np.ndarray:
    y = y.copy()
    n = crew.n
    for i in range(n):
        if crew.mode[i] == crew.MODE_RECOVERY and t >= crew.offsets[i] - 1e-15:
            th_i, w_i, _ = crew._recovery_state(i, t)
            y[1 + i] = th_i
            y[1 + n + i] = w_i
    return y


def simulate(P: dict) -> Result:
    """Integre n_strokes coups (force → theta) et reechantillonne a output_hz."""
    crew = Crew(P)
    ncfg = P["numerics"]
    rho_w, nu_w, rho_a = crew.fluid()
    n = crew.n
    T = crew.T

    t_end = ncfg["n_strokes"] * T
    dt = 1.0 / ncfg["output_hz"]
    t_grid = np.arange(0.0, t_end + 0.5 * dt, dt)
    t_grid = t_grid[t_grid <= t_end]

    y = np.zeros(1 + 2 * n)
    y[0] = ncfg["v_init_ms"]
    y[1:1 + n] = crew.theta_catch
    # Brief §4.4 : a l'attaque omega = 0 (Hermite arrive a (theta_catch, 0)).
    y[1 + n:] = 0.0
    crew.w_catch_target[:] = 0.0

    for i in range(n):
        if crew.offsets[i] <= 1e-15:
            crew.begin_drive(i, 0.0)
        else:
            crew.mode[i] = crew.MODE_RECOVERY
            crew.t_catch[i] = crew.offsets[i] - T
            crew.t_next_catch[i] = crew.offsets[i]
            crew.t_finish[i] = crew.offsets[i] - 0.55 * T
            crew.th_at_finish[i] = crew.theta_finish
            crew.w_at_finish[i] = 0.0
            crew.w_catch_target[i] = 0.0
            y = _snap_recovery(crew, 0.0, y)

    def rhs(t, z):
        return crew.rhs_state(t, z, rho_w, nu_w, rho_a)

    # --- events terminaux (un par type et par poste) --------------------
    def finish_event(i):
        def ev(t, z):
            if crew.mode[i] != crew.MODE_DRIVE or t < crew.offsets[i] - 1e-12:
                return 1.0
            return float(z[1 + i] - crew.theta_finish)
        ev.terminal = True
        ev.direction = -1
        return ev

    def catch_event(i):
        def ev(t, z):
            if crew.mode[i] != crew.MODE_RECOVERY:
                return 1.0
            return float(crew.t_next_catch[i] - t)
        ev.terminal = True
        ev.direction = -1
        return ev

    events = [finish_event(i) for i in range(n)] + [catch_event(i) for i in range(n)]

    t_cur = 0.0
    t_samples = [0.0]
    y_samples = [y.copy()]
    mode_samples = [crew.mode.copy()]

    max_step = T / 50.0
    n_guard = 0
    max_segments = ncfg["n_strokes"] * n * 4 + 50

    while t_cur < t_end - 1e-12:
        n_guard += 1
        if n_guard > max_segments:
            raise RuntimeError("trop de segments d'integration — events instables")

        sol = solve_ivp(
            rhs, (t_cur, t_end), y,
            method=ncfg["method"], rtol=ncfg["rtol"], atol=ncfg["atol"],
            max_step=max_step, events=events, dense_output=True)
        if not sol.success and sol.sol is None:
            raise RuntimeError(f"integration echouee a t={t_cur:.4f} : {sol.message}")

        # Premier evenement terminal
        t_hit = float(sol.t[-1])
        kind, who = None, None
        for ei, tev in enumerate(sol.t_events):
            if tev.size:
                te = float(tev[0])
                if te <= t_hit + 1e-14:
                    t_hit = te
                    if ei < n:
                        kind, who = "finish", ei
                    else:
                        kind, who = "catch", ei - n

        # Points de dense output entre t_cur et t_hit
        if sol.sol is not None:
            ts = t_grid[(t_grid > t_cur + 1e-13) & (t_grid < t_hit - 1e-13)]
            for tj in ts:
                yj = _snap_recovery(crew, float(tj), sol.sol(tj))
                t_samples.append(float(tj))
                y_samples.append(yj)
                mode_samples.append(crew.mode.copy())

            y = _snap_recovery(crew, t_hit, sol.sol(t_hit))
        else:
            y = _snap_recovery(crew, t_hit, sol.y[:, -1])

        t_samples.append(t_hit)
        y_samples.append(y.copy())
        mode_samples.append(crew.mode.copy())

        if kind == "finish":
            crew.begin_recovery(who, t_hit, y[1 + who], y[1 + n + who], V=y[0])
            y[1 + who] = min(float(y[1 + who]), crew.theta_finish)
            for j in range(n):
                if j != who and crew.mode[j] == crew.MODE_DRIVE and y[1 + j] <= crew.theta_finish + 1e-5:
                    crew.begin_recovery(j, t_hit, y[1 + j], y[1 + n + j], V=y[0])
                    y[1 + j] = min(float(y[1 + j]), crew.theta_finish)
        elif kind == "catch":
            crew.begin_drive(who, t_hit)
            y[1 + who] = crew.theta_catch
            y[1 + n + who] = 0.0  # brief §4.4 : (theta_catch, omega=0)
            crew.w_catch_target[who] = 0.0
            for j in range(n):
                if (j != who and crew.mode[j] == crew.MODE_RECOVERY
                        and abs(t_hit - crew.t_next_catch[j]) < 1e-9):
                    crew.begin_drive(j, t_hit)
                    y[1 + j] = crew.theta_catch
                    y[1 + n + j] = 0.0
                    crew.w_catch_target[j] = 0.0

        if t_hit <= t_cur + 1e-14:
            # event colle : avancer d'un epsilon pour eviter la boucle
            t_cur = t_cur + 1e-9
            y = _snap_recovery(crew, t_cur, y)
        else:
            t_cur = t_hit

        if kind is None:
            break

    t_arr = np.asarray(t_samples, float)
    y_arr = np.column_stack(y_samples)
    m_arr = np.column_stack(mode_samples)

    # Grille régulière
    y_grid = np.empty((1 + 2 * n, t_grid.size))
    modes_grid = np.empty((n, t_grid.size), dtype=int)
    for r in range(1 + 2 * n):
        y_grid[r] = np.interp(t_grid, t_arr, y_arr[r])
    for i in range(n):
        # nearest-neighbour sur les modes
        idx = np.searchsorted(t_arr, t_grid, side="right") - 1
        idx = np.clip(idx, 0, m_arr.shape[1] - 1)
        modes_grid[i] = m_arr[i, idx]

    keep_from = ncfg["n_discard"] * T
    m = t_grid >= keep_from - 1e-12
    return Result(
        t_grid[m], y_grid[:, m], P, crew,
        ncfg["n_strokes"] - ncfg["n_discard"], modes_grid[:, m])
