"""Assemblage du membre de droite de l'equation de mouvement (brief 3.3).

    (m_b + M) dV/dt = F_prop - D_hull - D_aero - sum(m_i * d2s_i/dt2)

Les efforts a la poignee et aux pieds sont INTERNES : ils n'apparaissent pas
ici. Ils sont derives separement (brief 3.8) parce que ce sont eux que les
capteurs mesurent.
"""
from __future__ import annotations

import numpy as np

from .body import BodyModel, smootherstep
from .forces import aero_drag, blade_force, hull_drag, rho_air, rho_water, nu_water
from .geometry import blade_position, moment_z

_H = 1.0e-4  # pas des differences finies temporelles, s


_NGRID = 4096  # points de la grille de phase


def _bandlimit(sig: np.ndarray, n_harmonics: int) -> np.ndarray:
    """Tronque la serie de Fourier d'un signal periodique.

    JUSTIFICATION PHYSIQUE, pas cosmetique : les trajectoires construites par
    fenetres independantes (jambes, tronc, bras) presentent des pics
    d'acceleration que le corps humain ne peut pas produire — le systeme
    neuro-musculaire a une bande passante finie. Au-dela d'une dizaine
    d'harmoniques de la frequence de coup, la cinematique corporelle reelle
    n'a plus d'energie mesurable.

    Effet secondaire utile : le signal devient exactement derivable par voie
    spectrale, ce qui elimine a la fois le bruit des differences finies et la
    sonnerie de Gibbs sur la derivee seconde.

    `kin_harmonics` est un parametre expose : l'analyse de sensibilite dira
    s'il compte, et son influence sur le terme inertiel doit etre verifiee
    avant toute exploitation du bilan energetique.
    """
    spec = np.fft.rfft(sig)
    spec[n_harmonics + 1:] = 0.0
    return np.fft.irfft(spec, n=sig.size)


class Crew:
    """Les 8 postes, chacun avec sa masse et son decalage de phase.

    PERFORMANCE (brief 5) : la cinematique corporelle ne depend que de la phase
    de cycle, jamais de la vitesse du bateau. Elle est donc tabulee UNE FOIS sur
    une grille de phase a la construction, puis interpolee pendant l'integration.
    Deriver par differences finies a l'interieur du membre de droite couterait
    trois evaluations completes de la chaine corporelle par appel du solveur.
    """

    def __init__(self, P: dict):
        self.P = P
        self.body = BodyModel(P)
        self.T = 60.0 / P["technique"]["rate_spm"]
        self.T_drive = P["technique"]["drive_fraction"] * self.T
        self.ramp = P["technique"]["blade_ramp_s"]
        self.offsets = np.asarray(P["crew"]["phase_offset_ms"], float) / 1000.0
        self.masses = np.asarray(P["crew"]["mass_kg"], float)
        self.n = len(self.masses)
        self.M = float(self.masses.sum())
        self.m_boat = P["boat"]["m_hull_kg"] + P["boat"]["m_cox_kg"]
        self._build_tables()

    # --------------------------------------------------------------- tables
    def _build_tables(self):
        g = np.linspace(0.0, 1.0, _NGRID, endpoint=False)
        self._g = g
        dt = self.T / _NGRID

        n_h = int(self.P["technique"]["kin_harmonics"])
        th = _bandlimit(self.body.theta(g), n_h)
        com = _bandlimit(self.body.com_x(g), n_h)

        # Les signaux sont maintenant a bande limitee, donc la differentiation
        # spectrale est exacte a la precision machine : pas de bruit de
        # differences finies, pas de sonnerie de Gibbs.
        k = 2j * np.pi * np.fft.fftfreq(_NGRID, d=dt)
        self._th = th
        self._thd = np.real(np.fft.ifft(np.fft.fft(th) * k))
        self._thdd = np.real(np.fft.ifft(np.fft.fft(th) * k ** 2))
        self._com = com
        self._comd = np.real(np.fft.ifft(np.fft.fft(com) * k))
        self._comdd = np.real(np.fft.ifft(np.fft.fft(com) * k ** 2))

        t_in = g * self.T
        r = max(self.ramp, 1e-6)
        f = smootherstep(t_in / r) * smootherstep((self.T_drive - t_in) / r)
        self._imm = np.where(t_in < self.T_drive, np.clip(f, 0.0, 1.0), 0.0)

    def _lookup(self, table, t):
        return np.interp(self.psi(t), self._g, table, period=1.0)

    # --------------------------------------------------------------- phases
    def psi(self, t):
        """Phase de cycle de chaque poste : (n_seats, n_t)."""
        t = np.atleast_1d(np.asarray(t, float))
        return ((t[None, :] - self.offsets[:, None]) / self.T) % 1.0

    def theta(self, t):
        return self._lookup(self._th, t)

    def theta_dot(self, t):
        return self._lookup(self._thd, t)

    def theta_ddot(self, t):
        return self._lookup(self._thdd, t)

    def com(self, t):
        return self._lookup(self._com, t)

    def com_dot(self, t):
        return self._lookup(self._comd, t)

    def com_ddot(self, t):
        return self._lookup(self._comdd, t)

    def immersion(self, t):
        return self._lookup(self._imm, t)

    # --------------------------------------------------------------- efforts
    def fluid(self):
        e = self.P["environment"]
        return (rho_water(e["water_temp_C"]),
                nu_water(e["water_temp_C"]),
                rho_air(e["air_temp_C"], e["pressure_hPa"], e["humidity_pct"]))

    def blade(self, t, V, rho_w):
        """Efforts de palette des 8 avirons. Retourne des tableaux (n_seats, n_t)."""
        th, thd = self.theta(t), self.theta_dot(t)
        imm = self.immersion(t)
        V_b = np.broadcast_to(np.atleast_1d(V), th.shape)
        return blade_force(th, thd, V_b, self.P, rho_w, immersion=imm)

    def rhs(self, t, V, rho_w, nu_w, rho_a):
        """Acceleration de la coque a l'instant t."""
        e = self.P["environment"]
        fx, _fy, _pl, _al, _sp = self.blade(t, V, rho_w)
        F_prop = fx.sum(axis=0)

        D_h = hull_drag(V, self.P, rho_w, nu_w)
        V_ground = V + e["current_ms"]
        D_a, _ = aero_drag(V_ground, self.P, rho_a, e["wind_axial_ms"])

        inertial = (self.masses[:, None] * self.com_ddot(t)).sum(axis=0)
        return (F_prop - D_h - D_a - inertial) / (self.m_boat + self.M)

    # --------------------------------------------------------------- internes
    def internal_forces(self, t, V, rho_w):
        """Efforts a la poignee, a la dame et aux pieds (brief 3.8).

        Ce sont les grandeurs que mesurent les capteurs, pas celles qui
        pilotent le mouvement.
        """
        L_in, L_out = self.P["rig"]["L_in_m"], self.P["rig"]["L_out_m"]
        I_oar = self.P["rig"]["I_oar_kgm2"]

        th = self.theta(t)
        thdd = self.theta_ddot(t)
        fx, fy, _p, _a, _s = self.blade(t, V, rho_w)

        rbx, rby = blade_position(th, L_out)
        M_bl = moment_z(rbx, rby, fx, fy)

        # equilibre en rotation de l'aviron : I*thdd = M_poignee + M_palette
        F_handle = (I_oar * thdd - M_bl) / L_in           # scalaire, selon la normale
        nx, ny = np.cos(th), -np.sin(th)
        fhx, fhy = F_handle * nx, F_handle * ny

        # effort a la dame = reaction de l'axe = somme des efforts sur l'aviron
        F_pin_x, F_pin_y = fx + fhx, fy + fhy
        F_pin_norm = F_pin_x * nx + F_pin_y * ny

        # effort aux pieds : bilan sur le rameur seul
        V_b = np.broadcast_to(np.atleast_1d(V), th.shape)
        a_abs = self.rhs_scalar_broadcast(t, V_b) + self.com_ddot(t)
        F_foot = self.masses[:, None] * a_abs - fhx

        return {"handle": F_handle, "handle_xy": (fhx, fhy),
                "pin_normal": F_pin_norm, "pin_xy": (F_pin_x, F_pin_y),
                "foot": F_foot}

    def rhs_scalar_broadcast(self, t, V_b):
        rho_w, nu_w, rho_a = self.fluid()
        a = self.rhs(t, V_b[0], rho_w, nu_w, rho_a)
        return np.broadcast_to(a, V_b.shape)
