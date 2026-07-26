"""Domaine de validité — brief §3 (contrôles a priori / a posteriori).

Sans ce module, Sobol et l'Observabilité exploreraient des rameurs
inexistants. Les modes d'analyse n'agrègent que des points `is_admissible`.
"""
from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import Any

import numpy as np

from .boat_class import BoatClass
from .body import BodyModel
from .dynamics import handle_force_profile
from .geometry import blade_normal_speed


class Severity(Enum):
    OK = 0
    WARNING = 1  # hors plage normale, simulation autorisée
    REJECT = 2  # impossible, simulation refusée


@dataclass
class Violation:
    rule: str  # identifiant stable, ex. "physio.handle_peak_force"
    severity: Severity
    value: float
    bound: float
    message: str  # rédigé pour l'utilisateur, pas pour le journal


def is_admissible(violations: list[Violation]) -> bool:
    return not any(v.severity is Severity.REJECT for v in violations)


def _warn_or_ok(
    rule: str,
    value: float,
    lo: float | None,
    hi: float | None,
    message: str,
) -> Violation | None:
    if lo is not None and value < lo:
        return Violation(rule, Severity.WARNING, value, lo, message)
    if hi is not None and value > hi:
        return Violation(rule, Severity.WARNING, value, hi, message)
    return None


def _reject_if_above(
    rule: str, value: float, hard: float, message: str
) -> Violation | None:
    if value > hard:
        return Violation(rule, Severity.REJECT, value, hard, message)
    return None


def _reject_if_outside(
    rule: str, value: float, lo: float, hi: float, message: str
) -> Violation | None:
    if value < lo:
        return Violation(rule, Severity.REJECT, value, lo, message)
    if value > hi:
        return Violation(rule, Severity.REJECT, value, hi, message)
    return None


def _append(out: list[Violation], v: Violation | None) -> None:
    if v is not None:
        out.append(v)


# ---------------------------------------------------------------------------
# check_inputs
# ---------------------------------------------------------------------------

def check_inputs(P: dict, cls: BoatClass) -> list[Violation]:
    """Contrôles a priori, avant intégration. Rapides."""
    out: list[Violation] = []
    out.extend(_physio_inputs(P, cls))
    out.extend(_geom_inputs(P, cls))
    out.extend(_env_inputs(P, cls))
    out.extend(_experimental_inputs(P, cls))
    return out


def _physio_inputs(P: dict, cls: BoatClass) -> list[Violation]:
    out: list[Violation] = []
    tech = P["technique"]
    F_peak = float(tech["F_peak_N"])
    n_oars = int(P["rig"].get("n_oars_per_rower", 1))

    if cls.sculling:
        # Force pic **par main** (brief §3.2)
        F_hand = F_peak / max(n_oars, 1)
        _append(out, _warn_or_ok(
            "physio.handle_peak_force_scull",
            F_hand, 300.0, 550.0,
            f"Force pic par main {F_hand:.0f} N hors plage couple 300–550 N",
        ))
        _append(out, _reject_if_above(
            "physio.handle_peak_force_scull",
            F_hand, 700.0,
            f"Force pic par main {F_hand:.0f} N au-delà de la butée 700 N",
        ))
    else:
        _append(out, _warn_or_ok(
            "physio.handle_peak_force_sweep",
            F_peak, 600.0, 1100.0,
            f"Force pic poignée {F_peak:.0f} N hors plage pointe 600–1100 N",
        ))
        _append(out, _reject_if_above(
            "physio.handle_peak_force_sweep",
            F_peak, 1400.0,
            f"Force pic poignée {F_peak:.0f} N au-delà de la butée 1400 N",
        ))

    # Profil F_h(u) : moyenne / pic sur la propulsion (a priori)
    u = np.linspace(0.0, 1.0, 501)
    F = handle_force_profile(
        u, F_peak,
        float(tech["F_u_peak"]),
        float(tech["F_u_rise_70"]),
        float(tech["F_high_width"]),
    )
    ratio = float(np.mean(F) / max(F_peak, 1e-9))
    _append(out, _warn_or_ok(
        "physio.drive_mean_force_ratio",
        ratio, 0.45, 0.65,
        f"Force moyenne / pic = {ratio:.2f} hors 45–65 %",
    ))

    rate = float(tech["rate_spm"])
    _append(out, _warn_or_ok(
        "physio.stroke_rate",
        rate, 12.0, 46.0,
        f"Cadence {rate:.1f} c/min hors plage 12–46",
    ))
    _append(out, _reject_if_above(
        "physio.stroke_rate",
        rate, 50.0,
        f"Cadence {rate:.1f} c/min au-delà de la butée 50",
    ))

    drive_frac = float(tech["drive_fraction"])
    _append(out, _warn_or_ok(
        "physio.drive_fraction",
        drive_frac, 0.33, 0.52,
        f"Fraction de propulsion {drive_frac:.2f} hors 0,33–0,52",
    ))

    phi_c = float(tech["trunk_catch_deg"])
    phi_f = float(tech["trunk_finish_deg"])
    amp = abs(phi_f - phi_c)
    _append(out, _warn_or_ok(
        "physio.trunk_amplitude",
        amp, 40.0, 70.0,
        f"Amplitude tronc {amp:.0f}° hors plage 40–70°",
    ))
    _append(out, _reject_if_above(
        "physio.trunk_amplitude",
        amp, 85.0,
        f"Amplitude tronc {amp:.0f}° au-delà de la butée 85°",
    ))

    return out


def _geom_inputs(P: dict, cls: BoatClass) -> list[Violation]:
    out: list[Violation] = []
    rower = P["rower"]
    h = float(rower["height_m"])
    L_thigh = h * float(rower["f_thigh_len"])
    L_shank = h * float(rower["f_shank_len"])
    L_arm = h * float(rower["f_arm_len"])
    x_ankle = float(rower["x_ankle_off_m"])
    L_slide = float(P["rig"]["L_slide_m"])

    # Portée de jambe — a attrapé un vrai bug en session 1 (brief §3.3)
    lhs = abs(x_ankle) + L_slide
    rhs = 0.985 * (L_shank + L_thigh)
    leg_ok = lhs < rhs
    if not leg_ok:
        out.append(Violation(
            "geom.leg_reach",
            Severity.REJECT,
            lhs,
            rhs,
            f"Portée de jambe impossible : |x_cheville|+L_coulisse={lhs:.3f} m "
            f"≥ 0,985·(L_jambe+L_cuisse)={rhs:.3f} m",
        ))

    # Extension de bras aux extrémités d'arc (fermeture §4.2) — e_raw non clipé
    if leg_ok:
        try:
            body = BodyModel(P)
        except ValueError as exc:
            # BodyModel utilise aussi hypot(·, z_hip) — plus strict que §3.3
            out.append(Violation(
                "geom.leg_reach",
                Severity.REJECT,
                lhs,
                rhs,
                f"Portée de jambe refusée par le modèle corporel : {exc}",
            ))
        else:
            lo, hi = 0.10 * L_arm, 1.00 * L_arm
            for u, x_h, label in (
                (0.0, body.x_handle_catch, "attaque"),
                (1.0, body.x_handle_finish, "dégagé"),
            ):
                j = body.joints_from_handle(x_h, u, drive=True)
                e = float(np.asarray(j["e_raw"]).reshape(-1)[0])
                if e < lo or e > hi:
                    out.append(Violation(
                        "geom.arm_extension",
                        Severity.REJECT,
                        e,
                        lo if e < lo else hi,
                        f"Extension de bras à l'{label} = {e:.3f} m hors "
                        f"[{lo:.3f} ; {hi:.3f}] (= 0,10–1,00·L_bras)",
                    ))

    # Immersion profondeur (m) si le paramètre est présent
    depth = P.get("technique", {}).get("blade_depth_m")
    if depth is None:
        depth = P.get("rig", {}).get("blade_depth_m")
    if depth is not None:
        d = float(depth)
        if d < 0.10 or d > 0.30:
            sev = Severity.WARNING if 0.05 <= d <= 0.40 else Severity.REJECT
            out.append(Violation(
                "geom.blade_immersion_depth",
                sev,
                d,
                0.10 if d < 0.10 else 0.30,
                f"Profondeur de palette {d:.2f} m hors 0,10–0,30 m",
            ))

    return out


def _env_inputs(P: dict, cls: BoatClass) -> list[Violation]:
    out: list[Violation] = []
    env = P.get("environment", {})
    mode = str(env.get("session_mode", "training")).lower()
    competition = mode in ("competition", "race", "regate", "compétition")

    wind = float(env.get("wind_axial_ms", 0.0))
    wind_lat = float(env.get("wind_lateral_ms", 0.0))
    wind_mag = float(np.hypot(wind, wind_lat))
    if competition:
        if wind_mag > 8.0:
            out.append(Violation(
                "env.wind",
                Severity.REJECT,
                wind_mag,
                8.0,
                f"Vent {wind_mag:.1f} m/s : annulation courante en compétition (>8 m/s)",
            ))
        elif wind_mag > 6.0:
            out.append(Violation(
                "env.wind",
                Severity.WARNING,
                wind_mag,
                6.0,
                f"Vent {wind_mag:.1f} m/s en zone d'annulation compétition (6–8 m/s)",
            ))
    else:
        if wind_mag > 10.0:
            out.append(Violation(
                "env.wind",
                Severity.REJECT,
                wind_mag,
                10.0,
                f"Vent {wind_mag:.1f} m/s au-delà de 10 m/s (entraînement)",
            ))

    wave = env.get("wave_height_m")
    if wave is not None:
        w = float(wave)
        lim = 0.15 if competition else 0.25
        if w > lim:
            out.append(Violation(
                "env.wave",
                Severity.REJECT if w > lim * 1.5 else Severity.WARNING,
                w,
                lim,
                f"Clapot {w:.2f} m au-delà de {lim:.2f} m ({mode})",
            ))

    Tw = float(env.get("water_temp_C", 15.0))
    if Tw < 2.0 or Tw > 30.0:
        out.append(Violation(
            "env.water_temp",
            Severity.WARNING,
            Tw,
            2.0 if Tw < 2.0 else 30.0,
            f"Température d'eau {Tw:.1f} °C hors 2–30 °C",
        ))

    current = abs(float(env.get("current_ms", 0.0)))
    if current > 1.5:
        out.append(Violation(
            "env.current",
            Severity.REJECT,
            current,
            1.5,
            f"Courant {current:.2f} m/s au-delà de 1,5 m/s",
        ))
    elif competition and current > 0.05:
        out.append(Violation(
            "env.current",
            Severity.WARNING,
            current,
            0.05,
            f"Courant {current:.2f} m/s : bassin de compétition en principe sans courant",
        ))

    return out


def _experimental_inputs(P: dict, cls: BoatClass) -> list[Violation]:
    """Enveloppe expérimentale — paramètre configurable, pas une constante."""
    scen = P.get("scenario", {})
    if "validable_sur_eau" not in scen and "validable_sur_eau" not in P:
        return []
    flag = scen.get("validable_sur_eau", P.get("validable_sur_eau", True))
    if flag:
        return []
    return [Violation(
        "experimental.validable_sur_eau",
        Severity.WARNING,
        0.0,
        1.0,
        "Scénario marqué non validable sur l'eau — un capteur utile "
        "seulement ici ne doit pas être acheté sur cette base",
    )]


# ---------------------------------------------------------------------------
# check_outputs
# ---------------------------------------------------------------------------

def check_outputs(result, P: dict, cls: BoatClass) -> list[Violation]:
    """Contrôles a posteriori : rendement, glissement, fluctuation, Froude."""
    out: list[Violation] = []
    st = result.last_stroke() if hasattr(result, "last_stroke") else result
    en = st.energy() if hasattr(st, "energy") else {}

    P_mean = float(en.get("P_rower_mean_W", float("nan")))
    if np.isfinite(P_mean):
        _append(out, _warn_or_ok(
            "physio.power_mean_2000m",
            P_mean, 250.0, 520.0,
            f"Puissance moyenne {P_mean:.0f} W hors plage 250–520 W",
        ))
        _append(out, _reject_if_above(
            "physio.power_mean_2000m",
            P_mean, 600.0,
            f"Puissance moyenne {P_mean:.0f} W au-delà de la butée 600 W",
        ))

    # Puissance instantanée max **par rameur** (butée 1500 W)
    if hasattr(st, "handle_power"):
        P_inst = float(np.max(np.abs(st.handle_power)))
        _append(out, _reject_if_above(
            "physio.power_instantaneous",
            P_inst, 1500.0,
            f"Puissance instantanée {P_inst:.0f} W au-delà de 1500 W",
        ))

    out.extend(_kinematic_speeds(st, P))

    # Butée d'aviron ±5°
    th = np.degrees(st.theta[0])
    th_c = float(P["rig"]["theta_catch_deg"])
    th_f = float(P["rig"]["theta_finish_deg"])
    if float(th.max()) > th_c + 5.0:
        out.append(Violation(
            "geom.oar_stop_catch",
            Severity.REJECT,
            float(th.max()),
            th_c + 5.0,
            f"Angle aviron {float(th.max()):.1f}° dépasse l'attaque {th_c:.0f}°+5°",
        ))
    if float(th.min()) < th_f - 5.0:
        out.append(Violation(
            "geom.oar_stop_finish",
            Severity.REJECT,
            float(th.min()),
            th_f - 5.0,
            f"Angle aviron {float(th.min()):.1f}° sous le dégagé {th_f:.0f}°−5°",
        ))

    V = float(en.get("v_mean_ms", float(st.V.mean())))
    L = float(P["boat"]["L_wl_m"])
    Fr = V / np.sqrt(9.81 * L)
    _append(out, _reject_if_outside(
        "mech.froude",
        Fr, 0.40, 0.62,
        f"Nombre de Froude {Fr:.3f} hors 0,40–0,62 (traînée de vague)",
    ))

    # Fluctuation ± = demi-amplitude ; check_factor = peak-to-peak
    cf = float(en.get("check_factor", float(st.V.max() - st.V.min())))
    half = 0.5 * cf
    lo_h, hi_h = _fluctuation_band(cls.code)
    _append(out, _warn_or_ok(
        "mech.speed_fluctuation",
        half, lo_h, hi_h,
        f"Fluctuation ±{half:.2f} m/s hors ±{lo_h:.2f}–±{hi_h:.2f} m/s ({cls.code})",
    ))

    # η palette — rejet structurel §3.3 [0,68–0,92] (modèle de palette faux).
    # La cible de crédibilité §9.2 est plus stricte [0,75–0,85] ; elle n'est
    # PAS un conflit — test_plausibility appelle is_admissible ici d'abord,
    # puis applique la bande §9.2 (voir tests/test_plausibility.py).
    eta = float(en.get("eta_blade", float("nan")))
    if np.isfinite(eta):
        _append(out, _reject_if_outside(
            "mech.eta_blade",
            eta, 0.68, 0.92,
            f"Rendement de palette η={eta:.3f} hors 0,68–0,92 — modèle de palette suspect",
        ))

    L_out = float(P["rig"]["L_out_m"])
    vn = blade_normal_speed(st.theta[0], st.theta_dot[0], st.V, L_out)
    drive = st.immersion[0] > 0.01
    if np.any(drive):
        slip = float(np.abs(vn[drive]).mean())
        _append(out, _reject_if_outside(
            "mech.blade_slip",
            slip, 0.4, 1.4,
            f"Glissement moyen |v_n|={slip:.2f} m/s hors 0,4–1,4 m/s",
        ))

    return out


def _fluctuation_band(code: str) -> tuple[float, float]:
    """Demi-amplitude ± selon la classe (brief §3.3)."""
    if code == "8+":
        return (0.25, 0.40)
    if code == "1x":
        return (0.15, 0.50)
    return (0.15, 0.50)


def _kinematic_speeds(st, P: dict) -> list[Violation]:
    out: list[Violation] = []
    L_in = float(P["rig"]["L_in_m"])
    v_h = L_in * np.abs(st.theta_dot[0])
    drive = st.immersion[0] > 0.01
    if np.any(drive):
        v_mean = float(v_h[drive].mean())
        v_peak = float(v_h[drive].max())
        for rule, val, lo, hi, hard, label in (
            ("physio.handle_speed_mean", v_mean, 2.2, 3.2, 4.0,
             "Vitesse moyenne poignée"),
            ("physio.handle_speed_peak", v_peak, 2.8, 4.2, 5.0,
             "Vitesse pic poignée"),
        ):
            _append(out, _warn_or_ok(
                rule, val, lo, hi, f"{label} {val:.2f} m/s hors {lo}–{hi}",
            ))
            _append(out, _reject_if_above(
                rule, val, hard, f"{label} {val:.2f} m/s > butée {hard}",
            ))

    # Coulisse : vitesse du siège via fermeture §4.2
    try:
        body = BodyModel(P)
    except ValueError:
        return out
    if st.t.size > 2:
        x_h = -L_in * np.sin(st.theta[0])
        u = body.handle_progress(x_h)
        is_drive = st.immersion[0] > 0.01
        x_d, _ = body.seat_phi_from_u(u, drive=True)
        x_r, _ = body.seat_phi_from_u(u, drive=False)
        x_seat = np.where(is_drive, x_d, x_r)
        v_slide = np.abs(np.gradient(np.asarray(x_seat, dtype=float), st.t))
        v_s_peak = float(v_slide.max())
        _append(out, _warn_or_ok(
            "physio.slide_speed_peak",
            v_s_peak, 1.2, 2.0,
            f"Vitesse pic coulisse {v_s_peak:.2f} m/s hors 1,2–2,0",
        ))
        _append(out, _reject_if_above(
            "physio.slide_speed_peak",
            v_s_peak, 2.5,
            f"Vitesse pic coulisse {v_s_peak:.2f} m/s > butée 2,5",
        ))
    return out
