"""Cinematique corporelle et centre de masse du rameur.

Le terme sum(m_i * d2s_i/dt2) de l'equation de mouvement (brief 3.3) sort d'ici.
C'est le terme sur lequel les modeles publies divergent le plus, et celui que
les coulisses et les pods dorsaux mesurent. Il est calcule explicitement,
jamais approxime par une masse ponctuelle.

CHOIX DE MODELISATION A CONNAITRE (brief 3.7b) :
  Les pieds sont FIXES sur le cale-pieds. Seuls jambe et cuisse tournent.
  C'est l'erreur classique a ne pas commettre.

APPROXIMATION ASSUMEE — fermeture geometrique de la poignee :
  Le deplacement longitudinal des mains issu de la chaine corporelle ne
  coincide pas exactement avec l'arc geometrique impose par les angles
  d'attaque et de degage (modele sagittal, alors que la pointe fait tourner
  les epaules). On conserve la FORME du mouvement issue du corps et on
  renormalise son AMPLITUDE sur l'arc geometrique. Le rapport brut est
  expose par `geometry_mismatch()` et doit rester dans [0.75, 1.35].
"""
from __future__ import annotations

import csv
from functools import lru_cache
from pathlib import Path

import numpy as np

from .geometry import oar_angle_from_handle

_DATA = Path(__file__).resolve().parents[3] / "data"


@lru_cache(maxsize=1)
def segment_table() -> tuple[dict, ...]:
    rows = []
    with open(_DATA / "segment_masses.csv", encoding="utf-8") as fh:
        for row in csv.DictReader(l for l in fh if not l.startswith("#")):
            rows.append({
                "segment": row["segment"],
                "side": row["side"],
                "mass_frac": float(row["mass_frac"]),
                "com_ratio": float(row["com_ratio"]),
            })
    return tuple(rows)


def _frac(name: str) -> float:
    for r in segment_table():
        if r["segment"] == name:
            return r["mass_frac"] * (2 if r["side"] == "each" else 1)
    raise KeyError(name)


def _ratio(name: str) -> float:
    for r in segment_table():
        if r["segment"] == name:
            return r["com_ratio"]
    raise KeyError(name)


def smootherstep(u):
    """Interpolation C2 : derivees premiere ET seconde nulles aux bornes.

    Indispensable ici : on derive deux fois pour le terme inertiel, une
    transition seulement C1 injecterait des sauts d'acceleration parasites.
    """
    u = np.clip(u, 0.0, 1.0)
    return u * u * u * (u * (6.0 * u - 15.0) + 10.0)


def _window(tau, start, end):
    """Rampe C2 de 0 a 1 entre start et end, plate en dehors."""
    end = max(end, start + 1e-6)
    return smootherstep((np.asarray(tau, dtype=float) - start) / (end - start))


class BodyModel:
    """Chaine sagittale : pied fixe -> jambe -> cuisse -> siege -> tronc -> bras."""

    def __init__(self, P: dict):
        self.P = P
        r, t, rig = P["rower"], P["technique"], P["rig"]
        h = r["height_m"]
        self.L_trunk = r["f_trunk_len"] * h
        self.L_thigh = r["f_thigh_len"] * h
        self.L_shank = r["f_shank_len"] * h
        self.L_arm = r["f_arm_len"] * h
        self.z_hip = r["seat_height_m"]
        self.x_ankle = r["x_ankle_off_m"]
        self.L_slide = rig["L_slide_m"]
        self.L_in = rig["L_in_m"]
        self.drive_frac = t["drive_fraction"]

        self.phi_c = np.radians(t["trunk_catch_deg"])
        self.phi_f = np.radians(t["trunk_finish_deg"])
        self.e_ext = self.L_arm
        self.e_flex = t["arm_flex_finish"] * self.L_arm

        # bornes geometriques imposees par les angles d'aviron
        self.x_handle_catch = -self.L_in * np.sin(np.radians(rig["theta_catch_deg"]))
        self.x_handle_finish = -self.L_in * np.sin(np.radians(rig["theta_finish_deg"]))

        self._check_leg_reach()

        # calibration de la renormalisation (cf. docstring du module)
        raw_c = self._hand_raw(0.0)
        raw_f = self._hand_raw(self.drive_frac - 1e-9)
        self._raw_c, self._raw_span = raw_c, (raw_f - raw_c)

    def _check_leg_reach(self):
        """La hanche doit rester atteignable par la jambe sur toute la course.

        Sans ce controle, la cinematique inverse sature silencieusement en fin
        de propulsion et injecte un pic d'acceleration purement numerique dans
        le terme inertiel — donc dans tout le bilan energetique.
        """
        reach = self.L_shank + self.L_thigh
        d_max = np.hypot(abs(self.x_ankle) + self.L_slide, self.z_hip)
        if d_max > 0.985 * reach:
            raise ValueError(
                f"jambe sur-etendue : distance cheville-hanche max = {d_max:.3f} m "
                f"pour une portee de {reach:.3f} m. Reduire |x_ankle_off_m| "
                f"(actuel {self.x_ankle:.3f}) ou L_slide_m (actuel {self.L_slide:.3f}).")

    # ------------------------------------------------------------ phases
    def _split(self, psi):
        """psi in [0,1) -> (tau_drive, tau_recovery, is_drive)."""
        psi = np.asarray(psi, dtype=float) % 1.0
        is_drive = psi < self.drive_frac
        tau_d = np.where(is_drive, psi / self.drive_frac, 0.0)
        tau_r = np.where(is_drive, 0.0,
                         (psi - self.drive_frac) / (1.0 - self.drive_frac))
        return tau_d, tau_r, is_drive

    # ------------------------------------------------------------ segments
    def joints(self, psi):
        """Positions longitudinales des articulations, relatives a la coque."""
        t = self.P["technique"]
        tau_d, tau_r, is_drive = self._split(psi)

        # --- siege
        seat_d = self.L_slide * _window(tau_d, 0.0, t["seq_legs_end"])
        skew = max(t["rec_slide_skew"], 1e-3)
        seat_r = self.L_slide * (1.0 - _window(tau_r, t["rec_slide_start"] / skew, 1.0))
        x_seat = np.where(is_drive, seat_d, seat_r)

        # --- tronc
        phi_d = self.phi_c + (self.phi_f - self.phi_c) * _window(
            tau_d, t["seq_trunk_onset"], t["seq_trunk_end"])
        phi_r = self.phi_f + (self.phi_c - self.phi_f) * _window(
            tau_r, t["rec_trunk_fwd"], min(t["rec_trunk_fwd"] + 0.50, 0.98))
        phi = np.where(is_drive, phi_d, phi_r)

        # --- bras
        e_d = self.e_ext + (self.e_flex - self.e_ext) * _window(tau_d, t["seq_arms_onset"], 1.0)
        e_r = self.e_flex + (self.e_ext - self.e_flex) * _window(
            tau_r, t["rec_arms_away"], min(t["rec_arms_away"] + 0.45, 0.95))
        e = np.where(is_drive, e_d, e_r)

        x_hip = x_seat
        x_shoulder = x_hip + self.L_trunk * np.sin(phi)
        x_hand = x_shoulder - e

        # --- genou par cinematique inverse a deux barres (cheville fixe)
        dx = x_hip - self.x_ankle
        dz = self.z_hip
        d = np.hypot(dx, dz)
        reach = self.L_shank + self.L_thigh
        d = np.clip(d, abs(self.L_shank - self.L_thigh) + 1e-6, reach - 1e-6)
        a = (d * d + self.L_shank ** 2 - self.L_thigh ** 2) / (2.0 * d)
        hgt = np.sqrt(np.maximum(self.L_shank ** 2 - a * a, 0.0))
        ux, uz = dx / d, dz / d
        # le genou est du cote haut : perpendiculaire (-uz, ux) orientee +z
        x_knee = self.x_ankle + a * ux - hgt * uz

        return {"x_seat": x_seat, "x_hip": x_hip, "phi": phi, "e": e,
                "x_shoulder": x_shoulder, "x_hand": x_hand, "x_knee": x_knee}

    def _hand_raw(self, psi):
        return float(np.asarray(self.joints(psi)["x_hand"]).reshape(-1)[0])

    # ------------------------------------------------------------ CdM
    def com_x(self, psi, phase: str | None = None):
        """Position longitudinale du CdM du rameur, relative a la coque."""
        if phase == "drive":
            psi = np.asarray(psi, dtype=float) * self.drive_frac
        elif phase == "recovery":
            psi = self.drive_frac + np.asarray(psi, dtype=float) * (1 - self.drive_frac)
        j = self.joints(psi)

        x_shank = j["x_knee"] + _ratio("shank") * (self.x_ankle - j["x_knee"])
        x_thigh = j["x_hip"] + _ratio("thigh") * (j["x_knee"] - j["x_hip"])
        # le bassin suit le siege sans tourner ; seul le tronc superieur pivote
        x_pelvis = j["x_hip"]
        x_upper = j["x_hip"] + _ratio("upper_trunk") * self.L_trunk * np.sin(j["phi"])
        x_head = j["x_hip"] + 1.05 * self.L_trunk * np.sin(j["phi"])
        x_arm = j["x_shoulder"] + 0.498 * (j["x_hand"] - j["x_shoulder"])
        x_foot = np.full_like(np.asarray(j["x_hip"], dtype=float), self.x_ankle)

        num = (_frac("foot") * x_foot + _frac("shank") * x_shank
               + _frac("thigh") * x_thigh + _frac("pelvis") * x_pelvis
               + _frac("upper_trunk") * x_upper
               + _frac("head_neck") * x_head + _frac("upper_arm") * x_arm
               + _frac("forearm") * x_arm + _frac("hand") * x_arm)
        den = (_frac("foot") + _frac("shank") + _frac("thigh") + _frac("pelvis")
               + _frac("upper_trunk") + _frac("head_neck")
               + _frac("upper_arm") + _frac("forearm") + _frac("hand"))
        return num / den

    # ------------------------------------------------------------ aviron
    def handle_x(self, psi):
        """Position longitudinale de la poignee, renormalisee sur l'arc geometrique."""
        raw = self.joints(psi)["x_hand"]
        u = (raw - self._raw_c) / self._raw_span
        return self.x_handle_catch + u * (self.x_handle_finish - self.x_handle_catch)

    def theta(self, psi):
        return oar_angle_from_handle(self.handle_x(psi), self.L_in)

    def geometry_mismatch(self) -> float:
        """Rapport course corporelle / course geometrique. Doit rester proche de 1."""
        return abs(self._raw_span / (self.x_handle_finish - self.x_handle_catch))
