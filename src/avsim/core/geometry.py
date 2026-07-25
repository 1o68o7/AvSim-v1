"""Geometrie de l'aviron — toutes les conventions de signe sont ici.

CONVENTIONS (brief 3.1), a ne modifier nulle part ailleurs :

    +x  : vers la PROUE (sens de deplacement du bateau)
    +y  : vers babord
    theta : angle du manche depuis la perpendiculaire a l'axe du bateau,
            POSITIF quand la palette est du cote PROUE.

    Attaque  : theta = +58 deg  -> palette vers la proue, poignee vers la poupe
    Degage   : theta = -34 deg  -> palette vers la poupe, poignee vers la proue

Le rameur fait face a la poupe. Pendant la propulsion il pousse le siege vers
la proue, la poignee vient vers la proue, donc la palette balaie vers la poupe.
"""
from __future__ import annotations

import numpy as np


def blade_position(theta, L_out: float):
    """Position du centre de poussee de la palette, relative a l'axe (portant)."""
    return L_out * np.sin(theta), L_out * np.cos(theta)


def handle_position(theta, L_in: float):
    """Position de la poignee, relative a l'axe. Cote oppose a la palette."""
    return -L_in * np.sin(theta), -L_in * np.cos(theta)


def oar_angle_from_handle(x_handle, L_in: float):
    """Inverse de handle_position sur x. Borne pour rester dans le domaine d'arcsin."""
    return np.arcsin(np.clip(-x_handle / L_in, -1.0, 1.0))


def blade_velocity_water(theta, theta_dot, V, L_out: float):
    """Vitesse de la palette PAR RAPPORT A L'EAU.

    V est la vitesse de la coque relative a l'eau, selon +x.
    La palette se deplace en plus a cause de la rotation de l'aviron.

    Retourne (vx, vy). vx < 0 pendant la propulsion : la palette glisse vers la
    poupe, c'est ce glissement qui propulse.
    """
    vx = V + L_out * np.cos(theta) * theta_dot
    vy = -L_out * np.sin(theta) * theta_dot
    return vx, vy


def blade_normal(theta):
    """Normale a la palette (direction de poussee utile), unitaire.

    A theta = 0 la palette est perpendiculaire au bateau et sa normale pointe
    vers la proue.
    """
    return np.cos(theta), -np.sin(theta)


def blade_chord(theta):
    """Direction du plan de la palette (le long du manche), unitaire."""
    return np.sin(theta), np.cos(theta)


def angle_of_attack(theta, vx, vy):
    """Angle d'incidence entre l'ecoulement relatif et la corde de la palette.

    Convention de Caplan & Gardner (2007), sur 0-180 deg :
      alpha < 90 deg : le bord d'attaque est la POINTE de la palette
      alpha = 90 deg : ecoulement normal, trainee pure, C_D maximal
      alpha > 90 deg : le bord d'attaque passe au COLLET, et la portance
                       change de signe (elle tourne de 180 deg)

    CORRECTION IMPORTANTE : la version precedente repliait l'intervalle sur
    0-90 deg via un arcsin de valeur absolue. Elle perdait donc toute la
    seconde moitie du domaine, ou la palette travaille reellement pendant une
    partie du coup, et avec elle le changement de signe de la portance.
    """
    speed = np.hypot(vx, vy)
    cx, cy = blade_chord(theta)
    with np.errstate(invalid="ignore", divide="ignore"):
        cos_a = (vx * cx + vy * cy) / np.where(speed > 1e-9, speed, np.nan)
    cos_a = np.nan_to_num(np.clip(cos_a, -1.0, 1.0))
    return np.arccos(cos_a)


def moment_z(rx, ry, fx, fy):
    """Composante z du moment d'une force appliquee en (rx, ry)."""
    return rx * fy - ry * fx
