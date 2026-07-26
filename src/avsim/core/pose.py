"""Pose sagittale pour l'UI (StrokeGeometry) — une seule source de vérité.

Expose la cinématique déjà calculée dans `body.RowerBody.joints_from_handle`
(+ géométrie aviron de `geometry.py`). Aucune formule d'IK côté frontend.

Convention d'affichage (vue latérale, brief UI §4.1b) :
  +x  proue (comme le noyau)
  +z  vertical vers le haut
  origine : projection du pin / portant sur la ligne d'eau (z=0)
"""
from __future__ import annotations

from typing import Any

import numpy as np

from .body import BodyModel
from .geometry import blade_position, handle_position
from .params import load_class


def _scalar(x) -> float:
    return float(np.asarray(x).reshape(-1)[0])


def pose_at_u(
    boat_class: str,
    u: float,
    *,
    drive: bool = True,
    hull_builder: str | None = None,
    hull_mould: str | None = None,
) -> dict[str, Any]:
    """Configuration corporelle + aviron à la fraction d'arc u ∈ [0, 1]."""
    u = float(np.clip(u, 0.0, 1.0))
    P = load_class(boat_class, hull_builder=hull_builder, hull_mould=hull_mould)
    body = BodyModel(P)
    rig = P["rig"]

    th_c = np.radians(float(rig["theta_catch_deg"]))
    th_f = np.radians(float(rig["theta_finish_deg"]))
    # u = 0 attaque → 1 dégagé (même convention que F_h(u) / Vue Coup)
    theta = th_c - u * (th_c - th_f)
    x_h, y_h = handle_position(theta, float(rig["L_in_m"]))
    x_b, y_b = blade_position(theta, float(rig["L_out_m"]))

    j = body.joints_from_handle(float(x_h), u, drive=drive)

    # --- cotes sagittales (z) dérivées du même IK que x_knee ---------------
    x_ankle = float(body.x_ankle)
    z_ankle = 0.0
    x_hip = _scalar(j["x_hip"])
    z_hip = float(body.z_hip)
    dx, dz = x_hip - x_ankle, z_hip - z_ankle
    d = float(np.hypot(dx, dz))
    d = max(d, 1e-9)
    ux, uz = dx / d, dz / d
    reach = body.L_shank + body.L_thigh
    d_lo = abs(body.L_shank - body.L_thigh) + 1e-6
    d_hi = reach - 1e-6
    d_c = float(np.clip(d, d_lo, d_hi))
    a = (d_c * d_c + body.L_shank ** 2 - body.L_thigh ** 2) / (2.0 * d_c)
    hgt = float(np.sqrt(max(body.L_shank ** 2 - a * a, 0.0)))
    # x_knee vient de joints_from_handle (source unique) ; z_knee complète le plan sagittal
    x_knee = _scalar(j["x_knee"])
    z_knee = z_ankle + a * uz + hgt * ux

    phi = _scalar(j["phi"])
    # phi = 0 : tronc vertical ; sin(phi) : épaule selon +x (proue)
    x_shoulder = _scalar(j["x_shoulder"])
    z_shoulder = z_hip + body.L_trunk * float(np.cos(phi))
    x_hand = _scalar(j["x_hand"])
    # hauteur poignée ≈ dame de nage — pas un DDL du modèle plan (cavalement seul)
    z_pin = z_hip + 0.22
    z_hand = z_pin
    x_head = x_hip + 1.05 * body.L_trunk * float(np.sin(phi))
    z_head = z_hip + 1.05 * body.L_trunk * float(np.cos(phi))

    # Palette : x = L_out·sinθ (noyau) ; z = immersion visuelle (hors modèle 2D)
    immerse = 1.0 if drive else 0.0
    z_blade = -0.08 * immerse - 0.02 * max(0.0, 1.0 - abs(float(np.cos(theta))))

    hull_len = float(P["boat"].get("loa_m", 10.0))
    bow = 0.45 * hull_len
    stern = -0.55 * hull_len

    return {
        "source": "simulated",
        "boat_class": boat_class,
        "u": u,
        "drive": drive,
        "envelope_ok": bool(j["envelope_ok"]),
        "theta_deg": float(np.degrees(theta)),
        "phi_deg": float(np.degrees(phi)),
        "joints": {
            "ankle": {"x": x_ankle, "z": z_ankle},
            "knee": {"x": x_knee, "z": float(z_knee)},
            "hip": {"x": x_hip, "z": z_hip},
            "shoulder": {"x": x_shoulder, "z": z_shoulder},
            "hand": {"x": x_hand, "z": z_hand},
            "head": {"x": x_head, "z": z_head},
            "seat": {"x": _scalar(j["x_seat"]), "z": z_hip},
        },
        "oar": {
            "pin": {"x": 0.0, "z": z_pin},
            "handle": {"x": float(x_h), "y": float(y_h), "z": z_hand},
            "blade": {"x": float(x_b), "y": float(y_b), "z": z_blade},
            "L_in_m": float(rig["L_in_m"]),
            "L_out_m": float(rig["L_out_m"]),
        },
        "hull": {
            "bow_x": bow,
            "stern_x": stern,
            "deck_z": 0.08,
            "keel_z": -0.12,
            "loa_m": hull_len,
            "sculling": bool(P["meta"].get("sculling", False)),
            "n_rowers": int(P["meta"]["n_rowers"]),
        },
        "lengths_m": {
            "L_shank": float(body.L_shank),
            "L_thigh": float(body.L_thigh),
            "L_trunk": float(body.L_trunk),
            "L_arm": float(body.L_arm),
            "L_slide": float(body.L_slide),
        },
        # Transparence UI seulement — ne change pas le calcul (ROADMAP point ouvert).
        # Genou en arrière de la cheville (x_knee < x_ankle) à l'attaque : pose
        # non validée contre une mesure réelle. Badge StrokeGeometry si u≈0.
        "flags": {
            "knee_behind_ankle": bool(x_knee < x_ankle),
            "show_catch_unvalidated_badge": bool(u <= 0.02 and x_knee < x_ankle),
        },
    }


def pose_series(
    boat_class: str,
    n: int = 41,
    *,
    drive: bool = True,
    hull_builder: str | None = None,
    hull_mould: str | None = None,
) -> dict[str, Any]:
    """Série de poses u=0..1 pour animer StrokeGeometry sans N requêtes."""
    n = int(np.clip(n, 5, 201))
    us = np.linspace(0.0, 1.0, n)
    frames = [
        pose_at_u(
            boat_class, float(u), drive=drive,
            hull_builder=hull_builder, hull_mould=hull_mould,
        )
        for u in us
    ]
    return {
        "source": "simulated",
        "boat_class": boat_class,
        "n": n,
        "u": [float(u) for u in us],
        "frames": frames,
    }
