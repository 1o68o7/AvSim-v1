"""Cinematique corporelle et centre de masse du rameur.

Le terme sum(m_i * d2s_i/dt2) de l'equation de mouvement (brief 4.3) sort d'ici.
C'est le terme sur lequel les modeles publies divergent le plus, et celui que
les coulisses et les pods dorsaux mesurent. Il est calcule explicitement,
jamais approxime par une masse ponctuelle.

CHOIX DE MODELISATION (brief 4.6) :
  Les pieds sont FIXES sur le cale-pieds. Seuls jambe et cuisse tournent.
  Le bassin (11,17 %) suit le siege sans tourner ; seul le tronc superieur pivote.

FERMETURE §4.2 — la poignee est la coordonnee maitresse :
  theta(t) vient de l'integration → x_poignee(t).
  Le sequencage (jambes, tronc) se repartit sur la course de poignee reelle u.
  L'extension de bras e est deduite par fermeture geometrique exacte :
      e = x_siege + L_tronc * sin(phi) - x_poignee
  Plus de renormalisation arbitraire sur un arc impose.
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


def _clip(x, lo, hi):
    """Clip scalaire en Python pur ; np.clip seulement si tableau."""
    if np.ndim(x) == 0:
        return max(float(lo), min(float(hi), float(x)))
    return np.clip(x, lo, hi)


def smootherstep(u):
    """Interpolation C2 : derivees premiere ET seconde nulles aux bornes."""
    u = _clip(u, 0.0, 1.0)
    if np.ndim(u) == 0:
        u = float(u)
        return u * u * u * (u * (6.0 * u - 15.0) + 10.0)
    u = np.asarray(u, dtype=float)
    return u * u * u * (u * (6.0 * u - 15.0) + 10.0)


def _window(tau, start, end):
    """Rampe C2 de 0 a 1 entre start et end, plate en dehors."""
    end = max(end, start + 1e-6)
    return smootherstep((np.asarray(tau, dtype=float) - start) / (end - start))


def _hermite_quintic_pos(s, x0, v0, x1, v1):
    """Position Hermite quintique sur s∈[0,1], a0=a1=0. v = dx/ds."""
    s = np.asarray(s, dtype=float)
    rhs1 = x1 - x0 - v0
    rhs2 = v1 - v0
    c5 = 6.0 * rhs1 - 3.0 * rhs2
    c4 = rhs2 - 3.0 * rhs1 - 2.0 * c5
    c3 = rhs1 - c4 - c5
    return x0 + v0 * s + c3 * s ** 3 + c4 * s ** 4 + c5 * s ** 5


def _cruise_blend_frac(
    start: float,
    end: float,
    frac: float,
    min_abs: float = 0.10,
) -> float:
    """Fraction de blend, plafonnée, avec largeur absolue mini (évite pics τ)."""
    width = max(float(end) - float(start), 1e-6)
    return float(min(0.45, max(float(frac), float(min_abs) / width)))


def _window_cruise(tau, start, end, blend: float = 0.16):
    """Rampe 0→1 a vitesse quasi uniforme au milieu, accel C2 aux bornes.

    Un smootherstep sur toute la fenetre place un pic de courbure au milieu
    de la course en τ — sous Hermite (ω max vers τ≈0,55) cela produit le
    signature « rushing the slide » (~40 m/s²). Ici l'acceleration est
    concentree sur les blends d'entree/sortie ; le plateau central a
    d²y/dτ² = 0 (retour efficace, lit. technique).
    """
    tau_arr = np.atleast_1d(np.asarray(tau, dtype=float))
    start = float(start)
    end = max(float(end), start + 1e-6)
    width = end - start
    bf = max(1e-3, min(0.49, float(blend)))
    b = bf * width
    t1, t2 = start + b, end - b
    # Deplacement symetrique des blends + croisiere : v_c = 1/(width - b)
    v_c = 1.0 / (width - b)
    y1 = 0.5 * v_c * b
    y2 = 1.0 - y1

    out = np.zeros_like(tau_arr, dtype=float)
    flat = (tau_arr > t1) & (tau_arr < t2)
    out = np.where(flat, y1 + v_c * (tau_arr - t1), out)

    left = (tau_arr > start) & (tau_arr <= t1)
    if np.any(left):
        out[left] = _hermite_quintic_pos(
            (tau_arr[left] - start) / b, 0.0, 0.0, y1, v_c * b)

    right = (tau_arr >= t2) & (tau_arr < end)
    if np.any(right):
        out[right] = _hermite_quintic_pos(
            (tau_arr[right] - t2) / b, y2, v_c * b, 1.0, 0.0)

    out = np.where(tau_arr <= start, 0.0, out)
    out = np.where(tau_arr >= end, 1.0, out)
    if np.ndim(tau) == 0:
        return float(out[0])
    return out


def _window_cruise_deriv(
    s: float,
    blend: float = 0.22,
    v0: float = 0.0,
) -> tuple[float, float, float]:
    """y, dy/ds, d²y/ds² pour une croisière sur s∈[0,1].

    `v0` = dy/ds à s=0 (0 = repos ; <0 autorise un léger dépassement
    d'angle au dégagé, comme le Hermite avec w_at_finish < 0).
    """
    s = float(max(0.0, min(1.0, s)))
    bf = max(1e-3, min(0.49, float(blend)))
    b = bf
    t1, t2 = b, 1.0 - b
    v0 = float(v0)
    # Plateau : v0*b/2 + v_c*(1-b) = 1 ⇒ v_c = (1 - v0*b/2)/(1-b).
    # Left hermite (0,v0)→(y1,v_c) ; right (y2,v_c)→(1,0).
    v_c = (1.0 - 0.5 * v0 * b) / (1.0 - b)
    if v_c <= 0.0:
        # v0 trop négatif pour ce blend — repli v0=0
        v0 = 0.0
        v_c = 1.0 / (1.0 - b)
    y1 = 0.5 * (v0 + v_c) * b
    y2 = 1.0 - 0.5 * v_c * b

    if s <= 0.0:
        return 0.0, v0, 0.0
    if s >= 1.0:
        return 1.0, 0.0, 0.0
    if t1 < s < t2:
        return y1 + v_c * (s - t1), v_c, 0.0

    if s <= t1:
        u = s / b
        x0, v0u, x1, v1u = 0.0, v0 * b, y1, v_c * b
    else:
        u = (s - t2) / b
        x0, v0u, x1, v1u = y2, v_c * b, 1.0, 0.0
    rhs1 = x1 - x0 - v0u
    rhs2 = v1u - v0u
    c5 = 6.0 * rhs1 - 3.0 * rhs2
    c4 = rhs2 - 3.0 * rhs1 - 2.0 * c5
    c3 = rhs1 - c4 - c5
    u2, u3, u4, u5 = u * u, u ** 3, u ** 4, u ** 5
    y = x0 + v0u * u + c3 * u3 + c4 * u4 + c5 * u5
    dy_du = v0u + 3.0 * c3 * u2 + 4.0 * c4 * u3 + 5.0 * c5 * u4
    d2y_du2 = 6.0 * c3 * u + 12.0 * c4 * u2 + 20.0 * c5 * u3
    return float(y), float(dy_du / b), float(d2y_du2 / (b * b))


def _recovery_windows(t: dict):
    """Onsets/fins de retour etages : bras → tronc → coulisse.

    Famille brief §12.2 : pas d'empilement d'accel sous le pic de ω.
    L'entrée de coulisse (blend) doit finir avant tau_r≈0,36 — sinon
    |a_siège|~100–180 m/s² à stroke τ∈[0,65 ; 0,75] (diag Kleshnev R,
    BioRow / row2k « Recovery Phase », n=25658).
    """
    skew = max(float(t["rec_slide_skew"]), 1e-3)
    arms_start = float(t["rec_arms_away"])
    trunk_start = float(t["rec_trunk_fwd"])
    slide_start = float(t["rec_slide_start"]) / skew
    slide_blend = 0.22
    # entry_end = slide_start + blend*(1 - slide_start) ≤ 0.36
    target_entry_end = 0.36
    entry_end = slide_start + slide_blend * (1.0 - slide_start)
    if entry_end > target_entry_end:
        slide_start = (target_entry_end - slide_blend) / max(1.0 - slide_blend, 1e-6)
    slide_start = max(slide_start, trunk_start + 1e-3)

    arms_end = max(trunk_start, arms_start + 1e-3)
    # Largeur mini du tronc (peut chevaucher le début de coulisse).
    trunk_end = min(0.55, max(slide_start, trunk_start + 0.18))
    return {
        "arms": (arms_start, arms_end),
        "trunk": (trunk_start, trunk_end),
        "slide": (slide_start, 1.0),
        "slide_blend": slide_blend,
    }


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
        self.drive_frac = t["drive_fraction"]  # reference legacy / tests unitaires

        self.phi_c = np.radians(t["trunk_catch_deg"])
        self.phi_f = np.radians(t["trunk_finish_deg"])
        self.e_ext = self.L_arm
        self.e_flex = t["arm_flex_finish"] * self.L_arm
        self.e_min = 0.10 * self.L_arm
        self.e_max = 1.00 * self.L_arm

        self.x_handle_catch = -self.L_in * np.sin(np.radians(rig["theta_catch_deg"]))
        self.x_handle_finish = -self.L_in * np.sin(np.radians(rig["theta_finish_deg"]))
        self._handle_span = self.x_handle_finish - self.x_handle_catch

        self._check_leg_reach()

    def _check_leg_reach(self):
        """La hanche doit rester atteignable par la jambe sur toute la course."""
        reach = self.L_shank + self.L_thigh
        d_max = np.hypot(abs(self.x_ankle) + self.L_slide, self.z_hip)
        if d_max > 0.985 * reach:
            raise ValueError(
                f"jambe sur-etendue : distance cheville-hanche max = {d_max:.3f} m "
                f"pour une portee de {reach:.3f} m. Reduire |x_ankle_off_m| "
                f"(actuel {self.x_ankle:.3f}) ou L_slide_m (actuel {self.L_slide:.3f}).")

    # ---------------------------------------------------- sequencage sur u
    def seat_phi_from_u(self, u, *, drive: bool):
        """Siege et angle de tronc a partir de la position normalisee u dans le coup.

        u=0 a l'attaque, u=1 au degage (propulsion). Au retour, u decroit de 1 a 0.
        """
        t = self.P["technique"]
        u = np.asarray(u, dtype=float)
        if drive:
            x_seat = self.L_slide * _window(u, 0.0, t["seq_legs_end"])
            phi = self.phi_c + (self.phi_f - self.phi_c) * _window(
                u, t["seq_trunk_onset"], t["seq_trunk_end"])
        else:
            # retour : tau_r = 1-u (0 au degage → 1 a l'attaque)
            tau_r = 1.0 - u
            w = _recovery_windows(t)
            slide_b = _cruise_blend_frac(
                *w["slide"], w.get("slide_blend", 0.22), min_abs=0.10)
            trunk_b = _cruise_blend_frac(*w["trunk"], 0.22, min_abs=0.10)
            x_seat = self.L_slide * (
                1.0 - _window_cruise(tau_r, *w["slide"], blend=slide_b))
            # Tronc en croisiere + blend abs. mini : evite |a|~150–200 m/s²
            # a stroke τ∈[0,65;0,75] (transition tronc→coulisse).
            phi = self.phi_f + (self.phi_c - self.phi_f) * _window_cruise(
                tau_r, *w["trunk"], blend=trunk_b)
        return x_seat, phi

    def joints_from_handle(self, x_handle, u, *, drive: bool):
        """Configuration corporelle pour une poignee donnee (brief §4.2).

        e est deduit par fermeture geometrique. Hors [0.10, 1.00]*L_bras :
        combinaison de sequencage impossible — on clippe et on remonte un drapeau.
        """
        x_handle = np.asarray(x_handle, dtype=float)
        u = np.asarray(u, dtype=float)
        x_seat, phi = self.seat_phi_from_u(u, drive=drive)
        x_hip = x_seat
        x_shoulder = x_hip + self.L_trunk * np.sin(phi)
        e_raw = x_shoulder - x_handle
        e = _clip(e_raw, self.e_min, self.e_max)
        x_hand = x_handle  # la main suit la poignee (maitre)

        dx = x_hip - self.x_ankle
        dz = self.z_hip
        d = np.hypot(dx, dz)
        reach = self.L_shank + self.L_thigh
        d_lo = abs(self.L_shank - self.L_thigh) + 1e-6
        d_hi = reach - 1e-6
        d = _clip(d, d_lo, d_hi)
        a = (d * d + self.L_shank ** 2 - self.L_thigh ** 2) / (2.0 * d)
        h2 = self.L_shank ** 2 - a * a
        if np.ndim(h2) == 0:
            hgt = np.sqrt(max(float(h2), 0.0))
        else:
            hgt = np.sqrt(np.maximum(h2, 0.0))
        ux, uz = dx / d, dz / d
        x_knee = self.x_ankle + a * ux - hgt * uz

        return {
            "x_seat": x_seat, "x_hip": x_hip, "phi": phi, "e": e, "e_raw": e_raw,
            "x_shoulder": x_shoulder, "x_hand": x_hand, "x_knee": x_knee,
            "envelope_ok": bool(np.all((e_raw >= self.e_min) & (e_raw <= self.e_max))),
        }

    def handle_progress(self, x_handle):
        """u in [0,1] le long de la course de poignee attaque → degage."""
        span = self._handle_span if abs(self._handle_span) > 1e-12 else 1.0
        return _clip((np.asarray(x_handle, float) - self.x_handle_catch) / span, 0.0, 1.0)

    def _com_from_joints(self, j):
        x_shank = j["x_knee"] + _ratio("shank") * (self.x_ankle - j["x_knee"])
        x_thigh = j["x_hip"] + _ratio("thigh") * (j["x_knee"] - j["x_hip"])
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

    def com_x_from_handle(self, x_handle, u, *, drive: bool):
        """CdM longitudinal pour une poignee / sequencage donnes (§4.2 + §4.3)."""
        return self._com_from_joints(self.joints_from_handle(x_handle, u, drive=drive))

    # ---------------------------------------------------- API legacy (tests)
    def _split(self, psi):
        psi = np.asarray(psi, dtype=float) % 1.0
        is_drive = psi < self.drive_frac
        tau_d = np.where(is_drive, psi / self.drive_frac, 0.0)
        tau_r = np.where(is_drive, 0.0,
                         (psi - self.drive_frac) / (1.0 - self.drive_frac))
        return tau_d, tau_r, is_drive

    def joints(self, psi):
        """API legacy : sequencage sur la phase de cycle (tests unitaires CdM)."""
        t = self.P["technique"]
        tau_d, tau_r, is_drive = self._split(psi)

        rw = _recovery_windows(t)
        slide_b = _cruise_blend_frac(
            *rw["slide"], rw.get("slide_blend", 0.22), min_abs=0.10)
        trunk_b = _cruise_blend_frac(*rw["trunk"], 0.22, min_abs=0.10)
        arms_b = _cruise_blend_frac(*rw["arms"], 0.22, min_abs=0.10)
        seat_d = self.L_slide * _window(tau_d, 0.0, t["seq_legs_end"])
        seat_r = self.L_slide * (
            1.0 - _window_cruise(tau_r, *rw["slide"], blend=slide_b))
        x_seat = np.where(is_drive, seat_d, seat_r)

        phi_d = self.phi_c + (self.phi_f - self.phi_c) * _window(
            tau_d, t["seq_trunk_onset"], t["seq_trunk_end"])
        phi_r = self.phi_f + (self.phi_c - self.phi_f) * _window_cruise(
            tau_r, *rw["trunk"], blend=trunk_b)
        phi = np.where(is_drive, phi_d, phi_r)

        e_d = self.e_ext + (self.e_flex - self.e_ext) * _window(tau_d, t["seq_arms_onset"], 1.0)
        e_r = self.e_flex + (self.e_ext - self.e_flex) * _window_cruise(
            tau_r, *rw["arms"], blend=arms_b)
        e = np.where(is_drive, e_d, e_r)

        x_hip = x_seat
        x_shoulder = x_hip + self.L_trunk * np.sin(phi)
        x_hand = x_shoulder - e

        dx = x_hip - self.x_ankle
        dz = self.z_hip
        d = np.hypot(dx, dz)
        reach = self.L_shank + self.L_thigh
        d = np.clip(d, abs(self.L_shank - self.L_thigh) + 1e-6, reach - 1e-6)
        a = (d * d + self.L_shank ** 2 - self.L_thigh ** 2) / (2.0 * d)
        hgt = np.sqrt(np.maximum(self.L_shank ** 2 - a * a, 0.0))
        ux, uz = dx / d, dz / d
        x_knee = self.x_ankle + a * ux - hgt * uz

        return {"x_seat": x_seat, "x_hip": x_hip, "phi": phi, "e": e,
                "x_shoulder": x_shoulder, "x_hand": x_hand, "x_knee": x_knee}

    def com_x(self, psi, phase: str | None = None):
        """Position longitudinale du CdM (API tests : phase prescrites)."""
        if phase == "drive":
            psi = np.asarray(psi, dtype=float) * self.drive_frac
        elif phase == "recovery":
            psi = self.drive_frac + np.asarray(psi, dtype=float) * (1 - self.drive_frac)
        return self._com_from_joints(self.joints(psi))

    def handle_x(self, psi):
        """Legacy : poignee issue du corps (non utilisee par le solveur force)."""
        return self.joints(psi)["x_hand"]

    def theta(self, psi):
        """Legacy : angle deduit du corps — remplace par l'etat integre dans Crew."""
        return oar_angle_from_handle(self.handle_x(psi), self.L_in)

    def geometry_mismatch(self) -> float:
        """Conserve pour diagnostic ; sous §4.2 la fermeture exacte vise ~1."""
        raw_c = float(np.asarray(self.joints(0.0)["x_hand"]).reshape(-1)[0])
        raw_f = float(np.asarray(
            self.joints(self.drive_frac - 1e-9)["x_hand"]).reshape(-1)[0])
        span = raw_f - raw_c
        return abs(span / self._handle_span) if abs(self._handle_span) > 1e-12 else np.nan
