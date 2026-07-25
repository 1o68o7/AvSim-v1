"""Assemblage du membre de droite — fermeture pilotee par la force (brief §4).

Etats : V (cavalement), et pour chaque rameur (theta, theta_point).

    (m_b + M) dV/dt = F_prop - D_hull - D_aero - sum(m_i * d2s_i/dt2)

    I_oar * theta'' = Q_poignee + Q_palette
    Q_poignee = -L_in * F_h(t)     (F_h > 0 = traction ; signe via F·v)
    Q_palette = - (r_palette x F_palette)_z

La cinematique corporelle reste prescrite sur la course de poignee reelle
(§4.2) et n'alimente que le terme inertiel (§4.3) — elle ne pilote plus theta.
"""
from __future__ import annotations

import numpy as np

from .body import BodyModel, smootherstep
from .forces import aero_drag, blade_force, hull_drag, rho_air, rho_water, nu_water
from .geometry import blade_position, handle_position, moment_z

# Profil de force parametrique (brief §4.4) — valeurs d'ingenierie, pas dans
# defaults.yaml (gel). Surchargeables via technique.F_peak_N / F_u_peak si presents.
_F_PEAK_DEFAULT = 1100.0  # N, pic de traction a la poignee (pointe)
_F_U_PEAK_DEFAULT = 0.38  # position du pic sur tau in [0,1]


def handle_force_profile(u, F_peak: float, u_peak: float = _F_U_PEAK_DEFAULT):
    """Force de traction F_h(u) >= 0, u = fraction de course de poignee.

    Deux demi-sinus^2 se rejoignant en u_peak (profil type Concept2 / ORM).
    Nul hors ]0, 1[.
    """
    u = np.asarray(u, dtype=float)
    u_peak = float(np.clip(u_peak, 0.05, 0.95))
    out = np.zeros_like(u, dtype=float)
    left = (u > 0.0) & (u <= u_peak)
    right = (u > u_peak) & (u < 1.0)
    out[left] = F_peak * np.sin(0.5 * np.pi * u[left] / u_peak) ** 2
    out[right] = F_peak * np.sin(0.5 * np.pi * (1.0 - u[right]) / (1.0 - u_peak)) ** 2
    return out


def quintic_hermite(s, x0, v0, x1, v1, duration):
    """Hermite quintique C2 : (x0,v0,a0=0) → (x1,v1,a1=0) sur s∈[0,1].

    Retourne (x, dx/dt, d2x/dt2). `duration` convertit les derivees de s vers t.
    """
    s = np.asarray(s, dtype=float)
    dur = max(float(duration), 1e-9)
    v0u = float(v0) * dur
    v1u = float(v1) * dur
    x0 = float(x0)
    x1 = float(x1)

    # c0=x0, c1=v0u, c2=0 ; resoudre c3,c4,c5 avec a0=a1=0
    rhs1 = x1 - x0 - v0u
    rhs2 = v1u - v0u
    c5 = 6.0 * rhs1 - 3.0 * rhs2
    c4 = rhs2 - 3.0 * rhs1 - 2.0 * c5
    c3 = rhs1 - c4 - c5

    s2, s3, s4, s5 = s * s, s ** 3, s ** 4, s ** 5
    x = x0 + v0u * s + c3 * s3 + c4 * s4 + c5 * s5
    dx_ds = v0u + 3.0 * c3 * s2 + 4.0 * c4 * s3 + 5.0 * c5 * s4
    d2x_ds2 = 6.0 * c3 * s + 12.0 * c4 * s2 + 20.0 * c5 * s3
    dx_dt = dx_ds / dur
    d2x_dt2 = d2x_ds2 / (dur * dur)
    return x, dx_dt, d2x_dt2


class Crew:
    """Equipage a n postes — etats theta/omega par poste + cavalement V."""

    MODE_DRIVE = 0
    MODE_RECOVERY = 1

    def __init__(self, P: dict):
        self.P = P
        self.body = BodyModel(P)
        self.T = 60.0 / P["technique"]["rate_spm"]
        self.ramp = float(P["technique"]["blade_ramp_s"])
        self.offsets = np.asarray(P["crew"]["phase_offset_ms"], float) / 1000.0
        self.masses = np.asarray(P["crew"]["mass_kg"], float)
        self.n = len(self.masses)
        self.M = float(self.masses.sum())
        self.m_boat = P["boat"]["m_hull_kg"] + P["boat"]["m_cox_kg"]

        self.theta_catch = np.radians(P["rig"]["theta_catch_deg"])
        self.theta_finish = np.radians(P["rig"]["theta_finish_deg"])
        self.L_in = P["rig"]["L_in_m"]
        self.L_out = P["rig"]["L_out_m"]
        self.I_oar = P["rig"]["I_oar_kgm2"]
        self.n_oars = int(P["rig"].get("n_oars_per_rower", 1))

        tech = P["technique"]
        self.F_peak = float(tech.get("F_peak_N", _F_PEAK_DEFAULT))
        self.F_u_peak = float(tech.get("F_u_peak", _F_U_PEAK_DEFAULT))

        # Etat hybride par poste (mis a jour par le solveur via events)
        self.mode = np.full(self.n, self.MODE_DRIVE, dtype=int)
        self.t_catch = self.offsets.copy()          # debut du coup courant
        self.t_next_catch = self.offsets + self.T   # prochaine attaque planifiee
        self.t_finish = np.full(self.n, np.nan)     # instant de degage
        self.th_at_finish = np.full(self.n, self.theta_finish)
        self.w_at_finish = np.zeros(self.n)
        self.w_catch_target = np.zeros(self.n)      # brief §4.4 : omega=0 a l'attaque

    # --------------------------------------------------------------- fluides
    def fluid(self):
        e = self.P["environment"]
        return (rho_water(e["water_temp_C"]),
                nu_water(e["water_temp_C"]),
                rho_air(e["air_temp_C"], e["pressure_hPa"], e["humidity_pct"]))

    # --------------------------------------------------------------- phase
    def local_tau(self, t):
        """Temps local dans la periode [0, T) par poste."""
        t = np.atleast_1d(np.asarray(t, float))
        return (t[None, :] - self.offsets[:, None]) % self.T

    def next_catch_time(self, i, t):
        """Prochaine attaque planifiee du poste i (etat hybride)."""
        return float(self.t_next_catch[i])

    # --------------------------------------------------------------- recovery
    def _recovery_state(self, i, t):
        """theta, omega, alpha prescrits pendant le retour (Hermite §4.4)."""
        t_f = self.t_finish[i]
        t_c = self.t_next_catch[i]
        if not np.isfinite(t_f):
            return self.theta_finish, 0.0, 0.0
        dur = max(t_c - t_f, 1e-4)
        s = np.clip((t - t_f) / dur, 0.0, 1.0)
        # Brief §4.4 : arrivee a (theta_catch, omega=0).
        return quintic_hermite(
            s, self.th_at_finish[i], self.w_at_finish[i],
            self.theta_catch, 0.0, dur)

    # --------------------------------------------------------------- body / COM
    def _com_and_deriv(self, th, w, alpha, drive_mask):
        """s, s', s'' pour chaque poste a partir de theta (poignee maitresse)."""
        x_h = handle_position(th, self.L_in)[0]
        u = self.body.handle_progress(x_h)
        n = self.n
        s = np.empty(n)
        for i in range(n):
            s[i] = float(self.body.com_x_from_handle(
                x_h[i], u[i], drive=bool(drive_mask[i])))

        # ds/dth, d2s/dth2 par differences centrales (configuration = f(theta))
        dth = 1.0e-5
        s_p = np.empty(n)
        s_m = np.empty(n)
        for i in range(n):
            xp = handle_position(th[i] + dth, self.L_in)[0]
            xm = handle_position(th[i] - dth, self.L_in)[0]
            up = float(self.body.handle_progress(xp))
            um = float(self.body.handle_progress(xm))
            drv = bool(drive_mask[i])
            s_p[i] = float(self.body.com_x_from_handle(xp, up, drive=drv))
            s_m[i] = float(self.body.com_x_from_handle(xm, um, drive=drv))
        ds_dth = (s_p - s_m) / (2.0 * dth)
        d2s_dth2 = (s_p - 2.0 * s + s_m) / (dth * dth)

        s_dot = ds_dth * w
        s_ddot = d2s_dth2 * w * w + ds_dth * alpha
        # Limiter les pics d'acceleration du CdM (transitions de fenetre /
        # Hermite) : au-dela de ~30 m/s² le corps humain ne suit plus, et le
        # terme inertiel pollue le cavalement.
        s_ddot = np.clip(s_ddot, -25.0, 25.0)
        return s, s_dot, s_ddot

    # --------------------------------------------------------------- oar RHS
    def _immersion(self, i, t, th):
        """Immersion [0,1] pendant la propulsion (brief §3.6).

        Entree : rampe temporelle sur blade_ramp_s depuis l'attaque.
        Sortie : rampe temporelle symetrique approchee via la proximite
        angulaire du degage (theta_finish) — pas de dependance a une
        fraction d'arc d'entree.
        """
        if self.mode[i] != self.MODE_DRIVE:
            return 0.0
        r = max(self.ramp, 1e-6)
        t_since = max(t - self.t_catch[i], 0.0)
        enter_t = float(smootherstep(t_since / r))
        # Sortie progressive vers theta_finish (fenetre ~25 deg, lissage).
        leave = float(smootherstep((th - self.theta_finish) / max(
            np.radians(25.0), 1e-6)))
        return enter_t * leave

    def oar_accelerations(self, t, V, th, w, rho_w):
        """theta'' et efforts associes pour tous les postes."""
        n = self.n
        thdd = np.zeros(n)
        F_pull = np.zeros(n)
        imm = np.zeros(n)
        fx = np.zeros(n)
        fy = np.zeros(n)
        p_loss = np.zeros(n)
        M_bl = np.zeros(n)

        drive = self.mode == self.MODE_DRIVE
        T_shape = max(0.40 * self.T, 0.30)

        for i in range(n):
            if t < self.offsets[i] - 1e-12:
                thdd[i] = 0.0
                continue

            if self.mode[i] == self.MODE_RECOVERY:
                _th, _w, a = self._recovery_state(i, t)
                thdd[i] = a
                continue

            # --- propulsion : F_h(tau), tau = temps depuis l'attaque (§4.4) ---
            t_since = max(t - self.t_catch[i], 0.0)
            u_t = t_since / T_shape
            if u_t <= 1.0:
                F_pull[i] = float(handle_force_profile(
                    max(u_t, 1e-3), self.F_peak, self.F_u_peak))
            elif u_t < 1.20:
                tail = float(handle_force_profile(1.0 - 1e-6, self.F_peak, self.F_u_peak))
                F_pull[i] = tail * (1.0 - (u_t - 1.0) / 0.20)
            else:
                F_pull[i] = 0.0

            imm[i] = self._immersion(i, t, th[i])
            # F_h(t) entre tel quel dans M_poignee = -L_in * F_h (brief §4.4).
            # L'immersion ne lisse que la force hydrodynamique de palette.

            fx_i, fy_i, pl, _a, _s = blade_force(
                th[i], w[i], V, self.P, rho_w, immersion=imm[i])
            fx_i = fx_i * self.n_oars
            fy_i = fy_i * self.n_oars
            pl = pl * self.n_oars
            fx[i], fy[i], p_loss[i] = float(fx_i), float(fy_i), float(pl)

            rbx, rby = blade_position(th[i], self.L_out)
            M_bl[i] = float(moment_z(rbx, rby, fx[i], fy[i]))
            thdd[i] = (-self.L_in * F_pull[i] - M_bl[i]) / self.I_oar

        return thdd, F_pull, imm, fx, fy, p_loss, M_bl, drive

    def rhs_state(self, t, y, rho_w, nu_w, rho_a):
        """dy/dt pour y = [V, th_0..th_{n-1}, w_0..w_{n-1}]."""
        n = self.n
        V = float(y[0])
        th = np.array(y[1:1 + n], dtype=float, copy=True)
        w = np.array(y[1 + n:1 + 2 * n], dtype=float, copy=True)

        # Pendant le retour, ecraser (th, w) par la trajectoire d'Hermite pour
        # eviter la derive numerique — les derivees suivent quand meme l'Hermite.
        for i in range(n):
            if self.mode[i] == self.MODE_RECOVERY and t >= self.offsets[i]:
                th[i], w[i], _ = self._recovery_state(i, t)

        thdd, F_pull, imm, fx, fy, p_loss, M_bl, drive = self.oar_accelerations(
            t, V, th, w, rho_w)

        _s, _sd, sdd = self._com_and_deriv(th, w, thdd, drive)

        e = self.P["environment"]
        F_prop = float(fx.sum())
        D_h = float(hull_drag(V, self.P, rho_w, nu_w))
        V_ground = V + e["current_ms"]
        D_a, _ = aero_drag(V_ground, self.P, rho_a, e["wind_axial_ms"])
        D_a = float(np.asarray(D_a).reshape(-1)[0])
        inertial = float((self.masses * sdd).sum())
        a_V = (F_prop - D_h - D_a - inertial) / (self.m_boat + self.M)

        dy = np.empty(1 + 2 * n)
        dy[0] = a_V
        dy[1:1 + n] = w
        dy[1 + n:] = thdd
        return dy

    # --------------------------------------------------------------- diagnostics
    def blade_at(self, t, V, th, w, rho_w):
        """Efforts palette a un instant (pour post-traitement)."""
        thdd, F_pull, imm, fx, fy, p_loss, M_bl, drive = self.oar_accelerations(
            t, V, th, w, rho_w)
        return {
            "thdd": thdd, "F_pull": F_pull, "immersion": imm,
            "fx": fx, "fy": fy, "p_loss": p_loss, "M_blade": M_bl, "drive": drive,
        }

    def internal_forces(self, t, V, th, w, rho_w):
        """Efforts capteurs a la poignee / dame / pieds."""
        info = self.blade_at(t, V, th, w, rho_w)
        F_pull = info["F_pull"]
        fx, fy = info["fx"], info["fy"]
        # Convention capteur : traction positive (= F_pull)
        F_handle = F_pull.copy()
        nx, ny = np.cos(th), -np.sin(th)
        # Force du rameur SUR l'aviron : opposee a la normale "push blade" si pull
        # M_h = -L_in*F_pull ⇒ dans l'ancienne convention F_handle_old = -F_pull
        # Pour la puissance : P = M_h * w = -L_in*F_pull*w (>0 si w<0 en propulsion)
        fhx = -F_pull * nx
        fhy = -F_pull * ny
        F_pin_x, F_pin_y = fx + fhx, fy + fhy
        F_pin_norm = F_pin_x * nx + F_pin_y * ny

        thdd = info["thdd"]
        _s, _sd, sdd = self._com_and_deriv(th, w, thdd, info["drive"])
        # a_abs ≈ a_coque + s'' ; a_coque estimee sans re-entrer tout le RHS
        e = self.P["environment"]
        D_h = float(hull_drag(V, self.P, rho_w, nu_water(e["water_temp_C"])))
        D_a, _ = aero_drag(V + e["current_ms"], self.P,
                           rho_air(e["air_temp_C"], e["pressure_hPa"], e["humidity_pct"]),
                           e["wind_axial_ms"])
        D_a = float(np.asarray(D_a).reshape(-1)[0])
        a_V = (fx.sum() - D_h - D_a - float((self.masses * sdd).sum())) / (
            self.m_boat + self.M)
        F_foot = self.masses * (a_V + sdd) - fhx

        return {
            "handle": F_handle,
            "handle_xy": (fhx, fhy),
            "pin_normal": F_pin_norm,
            "pin_xy": (F_pin_x, F_pin_y),
            "foot": F_foot,
            "immersion": info["immersion"],
            "fx": fx, "fy": fy, "p_loss": info["p_loss"],
        }

    # --------------------------------------------------------------- events API
    def begin_drive(self, i, t):
        self.mode[i] = self.MODE_DRIVE
        self.t_catch[i] = t
        self.t_next_catch[i] = t + self.T
        self.t_finish[i] = np.nan

    def begin_recovery(self, i, t, th, w, V=None):
        self.mode[i] = self.MODE_RECOVERY
        self.t_finish[i] = t
        self.th_at_finish[i] = float(min(th, self.theta_finish))
        self.w_at_finish[i] = float(np.clip(w, -0.6, 0.2))
        # Cible Hermite = (theta_catch, 0) — brief §4.4 ; pas d'accrochage V.
        self.w_catch_target[i] = 0.0
        if t - self.t_catch[i] >= self.T - 1e-6:
            raise RuntimeError(
                f"poste {i+1}: duree de propulsion >= periode "
                f"({t - self.t_catch[i]:.3f} s >= {self.T:.3f} s) — "
                f"combinaison force/cadence infaisable (brief §4.4)")
