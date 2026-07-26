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

def handle_force_profile(
    u,
    F_peak: float,
    u_peak: float = 0.40,
    u_rise_70: float = 0.17,
    high_width: float = 0.35,
):
    """Force de traction F_h(u) >= 0, u = fraction d'arc (0 attaque → 1 degage).

    Deux demi-sinus^2 asymetriques (montee / descente) cales pour :
      - pic a u_peak ;
      - 70 % du pic atteint a u_rise_70 ;
      - F > 70 % du pic sur une largeur ~ high_width.
    Parametres lus depuis technique.* (defaults.yaml), sources Kleshnev /
    Rowing Faster Table 9.2 / Cerne et al. 2013. Nul hors ]0, 1[.

    Note : F(0)=0 dans ce profil ; le demarrage du drive repose sur le
    clamp u_eff=max(u_geom, u_rise_70) dans Crew.oar_accelerations.
    Tentative F(0)=0.13*F_peak (Kleshnev) sans clamp : drive > periode a
    1100 N (25/07) — clamp conserve en attendant une refonte du bootstrap.
    """
    u = np.asarray(u, dtype=float)
    u_peak = float(np.clip(u_peak, 0.05, 0.95))
    u_rise_70 = float(np.clip(u_rise_70, 1e-3, u_peak * 0.95))
    high_width = float(np.clip(high_width, 0.05, 0.90))
    u_fall_70 = float(np.clip(u_rise_70 + high_width, u_peak + 1e-3, 0.99))

    # sin^2(π/2 * x) = 0.7  ⇒  x_70 = (2/π) * arcsin(√0.7)
    x_70 = (2.0 / np.pi) * np.arcsin(np.sqrt(0.70))
    # Remap puissance : (u/u_peak)^p_rise = x_70 en u_rise_70
    ratio_r = max(u_rise_70 / u_peak, 1e-6)
    p_rise = float(np.log(x_70) / np.log(ratio_r))
    ratio_f = max((1.0 - u_fall_70) / (1.0 - u_peak), 1e-6)
    p_fall = float(np.log(x_70) / np.log(ratio_f))

    out = np.zeros_like(u, dtype=float)
    left = (u > 0.0) & (u <= u_peak)
    right = (u > u_peak) & (u < 1.0)
    x_l = np.clip((u[left] / u_peak) ** p_rise, 0.0, 1.0)
    x_r = np.clip(((1.0 - u[right]) / (1.0 - u_peak)) ** p_fall, 0.0, 1.0)
    out[left] = F_peak * np.sin(0.5 * np.pi * x_l) ** 2
    out[right] = F_peak * np.sin(0.5 * np.pi * x_r) ** 2
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
        self.catch_slip = np.radians(float(P["technique"].get("catch_slip_deg", 3.0)))
        self.leave_deg = float(P["technique"].get("leave_deg", 25.0))
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
        self.F_peak = float(tech["F_peak_N"])
        self.F_u_peak = float(tech["F_u_peak"])
        self.F_u_rise_70 = float(tech["F_u_rise_70"])
        self.F_high_width = float(tech["F_high_width"])
        self._arc_span = max(self.theta_catch - self.theta_finish, 1e-6)

        # Etat hybride par poste (mis a jour par le solveur via events)
        self.mode = np.full(self.n, self.MODE_DRIVE, dtype=int)
        self.t_catch = self.offsets.copy()          # debut du coup courant
        self.t_next_catch = self.offsets + self.T   # prochaine attaque planifiee
        self.t_finish = np.full(self.n, np.nan)     # instant de degage
        self.th_at_finish = np.full(self.n, self.theta_finish)
        self.w_at_finish = np.zeros(self.n)
        self.w_catch_target = np.zeros(self.n)      # brief §4.4 : omega=0 a l'attaque

        # Tables s(θ), ds/dθ, d²s/dθ² — une fois, index θ (pas le temps).
        # Remplace 24 appels joints_from_handle / RHS par np.interp.
        self._com_tab_drive = self._build_com_table(drive=True, n_pts=3001)
        self._com_tab_rec = self._build_com_table(drive=False, n_pts=3001)

    def _build_com_table(self, *, drive: bool, n_pts: int = 3001):
        """Grille fine sur [θ_finish, θ_catch] + dérivées (DF centrales, dθ=1e-5)."""
        th = np.linspace(self.theta_finish, self.theta_catch, int(n_pts))
        s = np.empty(th.size)
        ds = np.empty(th.size)
        d2s = np.empty(th.size)
        dth = 1.0e-5

        def _s_at(thi: float) -> float:
            xh = float(handle_position(thi, self.L_in)[0])
            u = float(self.body.handle_progress(xh))
            return float(self.body.com_x_from_handle(xh, u, drive=drive))

        for i, thi in enumerate(th):
            s0 = _s_at(float(thi))
            sp = _s_at(float(thi) + dth)
            sm = _s_at(float(thi) - dth)
            s[i] = s0
            ds[i] = (sp - sm) / (2.0 * dth)
            d2s[i] = (sp - 2.0 * s0 + sm) / (dth * dth)
        return {"th": th, "s": s, "ds": ds, "d2s": d2s}

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
        s = max(0.0, min(1.0, (t - t_f) / dur))
        # Brief §4.4 : arrivee a (theta_catch, omega=0).
        return quintic_hermite(
            s, self.th_at_finish[i], self.w_at_finish[i],
            self.theta_catch, 0.0, dur)

    # --------------------------------------------------------------- body / COM
    def _com_and_deriv(self, th, w, alpha, drive_mask):
        """s, s', s'' via tables θ (drive / retour) — pas de joints à chaque RHS."""
        n = self.n
        s = np.empty(n)
        ds_dth = np.empty(n)
        d2s_dth2 = np.empty(n)
        th_lo, th_hi = self.theta_finish, self.theta_catch
        for i in range(n):
            tab = self._com_tab_drive if drive_mask[i] else self._com_tab_rec
            thi = float(th[i])
            if thi < th_lo:
                thi = th_lo
            elif thi > th_hi:
                thi = th_hi
            s[i] = float(np.interp(thi, tab["th"], tab["s"]))
            ds_dth[i] = float(np.interp(thi, tab["th"], tab["ds"]))
            d2s_dth2[i] = float(np.interp(thi, tab["th"], tab["d2s"]))

        s_dot = ds_dth * w
        s_ddot = d2s_dth2 * w * w + ds_dth * alpha
        # Limiter les pics d'acceleration du CdM (transitions de fenetre /
        # Hermite) : au-dela de ~30 m/s² le corps humain ne suit plus, et le
        # terme inertiel pollue le cavalement.
        for i in range(n):
            s_ddot[i] = max(-25.0, min(25.0, float(s_ddot[i])))
        return s, s_dot, s_ddot

    # --------------------------------------------------------------- oar RHS
    def _immersion(self, i, t, th):
        """Immersion [0,1] pendant la propulsion (brief §3.6).

        Entree : Catch Slip angulaire (Kleshnev) — pleine immersion ≈3°
        apres l'attaque, pas une rampe temporelle arbitraire.
        Sortie : proximite angulaire du degage (fenetre leave, defaut 25°).
        """
        if self.mode[i] != self.MODE_DRIVE:
            return 0.0
        enter = float(smootherstep(
            (self.theta_catch - th) / max(self.catch_slip, 1e-6)))
        if self.leave_deg <= 0.0:
            leave = 1.0
        else:
            leave = float(smootherstep((th - self.theta_finish) / max(
                np.radians(self.leave_deg), 1e-6)))
        return enter * leave

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

        for i in range(n):
            if t < self.offsets[i] - 1e-12:
                thdd[i] = 0.0
                continue

            if self.mode[i] == self.MODE_RECOVERY:
                _th, _w, a = self._recovery_state(i, t)
                thdd[i] = a
                continue

            # --- propulsion : F_h(u), u = fraction d'arc (§4.4) ---
            # u=0 a l'attaque, u=1 au degage. Le profil est nul en u=0 ; avec
            # omega=0 et immersion qui monte en blade_ramp_s, le couple palette
            # peut pousser theta > theta_catch. Clamp u_eff=max(u_geom, u_rise_70)
            # pour garder un couple moteur (sinon piege I_oar). Tentative
            # F(0)=0.13*F_peak sans clamp : drive>periode — clamp conserve.
            u_geom = (self.theta_catch - th[i]) / self._arc_span
            u_arc = max(0.0, min(1.0, float(u_geom)))
            u_eff = max(u_arc, self.F_u_rise_70) if u_geom < self.F_u_rise_70 else u_arc
            F_pull[i] = float(handle_force_profile(
                u_eff, self.F_peak, self.F_u_peak,
                self.F_u_rise_70, self.F_high_width))

            imm[i] = self._immersion(i, t, th[i])
            # F_h(u) entre tel quel dans M_poignee = -L_in * F_h (brief §4.4).
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
        self.w_at_finish[i] = max(-0.6, min(0.2, float(w)))
        # Cible Hermite = (theta_catch, 0) — brief §4.4 ; pas d'accrochage V.
        self.w_catch_target[i] = 0.0
        if t - self.t_catch[i] >= self.T - 1e-6:
            raise RuntimeError(
                f"poste {i+1}: duree de propulsion >= periode "
                f"({t - self.t_catch[i]:.3f} s >= {self.T:.3f} s) — "
                f"combinaison force/cadence infaisable (brief §4.4)")
