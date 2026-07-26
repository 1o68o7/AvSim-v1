"""Tests de convention — A ECRIRE ET FAIRE ECHOUER AVANT TOUT CODE DE PHYSIQUE.

Une convention de signe fausse se propage silencieusement dans tout le bilan
energetique. Ces tests sont la premiere barriere.
"""
import copy

import numpy as np
import pytest

from avsim.core.body import BodyModel, segment_table
from avsim.core.geometry import (
    oar_angle_from_handle,
    blade_position,
    blade_velocity_water,
    blade_normal_speed,
)
from avsim.core.solver import simulate


# ---------------------------------------------------------------- masses
def test_segment_masses_sum_to_100_percent():
    tbl = segment_table()
    total = sum((2 if r["side"] == "each" else 1) * r["mass_frac"] for r in tbl)
    assert abs(total - 1.0) < 1e-4, f"somme des fractions = {total:.6f}, attendu 1.0"


def test_body_com_within_physical_bounds(P):
    """Le CdM du rameur doit rester dans l'enveloppe corporelle."""
    body = BodyModel(P)
    for tau in np.linspace(0, 1, 21):
        x = body.com_x(tau, phase="drive")
        assert -1.5 < x < 1.5, f"CdM aberrant a tau={tau}: {x} m"


# ---------------------------------------------------------------- geometrie
def test_blade_is_bow_side_at_catch(P):
    """Convention brief 3.1 : theta positif = palette vers la proue.

    A l'attaque, la palette est du cote proue du portant.
    """
    th_catch = np.radians(P["rig"]["theta_catch_deg"])
    x, y = blade_position(th_catch, P["rig"]["L_out_m"])
    assert x > 0, "a l'attaque la palette doit etre du cote proue (x > 0)"


def test_blade_sweeps_sternward_during_drive(P):
    th_c = np.radians(P["rig"]["theta_catch_deg"])
    th_f = np.radians(P["rig"]["theta_finish_deg"])
    x_c, _ = blade_position(th_c, P["rig"]["L_out_m"])
    x_f, _ = blade_position(th_f, P["rig"]["L_out_m"])
    assert x_f < x_c, "la palette doit balayer de la proue vers la poupe pendant la propulsion"


def test_handle_travel_maps_back_to_angles(P):
    """L'inversion poignee -> angle doit etre coherente avec la geometrie."""
    L_in = P["rig"]["L_in_m"]
    th_c = float(P["rig"]["theta_catch_deg"])
    th_f = float(P["rig"]["theta_finish_deg"])
    for th_deg in (th_f, 0.0, th_c):
        th = np.radians(th_deg)
        x_handle = -L_in * np.sin(th)
        th_back = oar_angle_from_handle(x_handle, L_in)
        assert abs(th_back - th) < 1e-9


def test_blade_near_stationary_in_water_at_catch(P):
    """Test central du brief 3.1 / §9.1.

    A l'attaque, le glissement a travers l'eau (composante normale) doit etre
    faible — palette plantee. On ne peut pas utiliser |v_tip| : la cinematique
    impose |v_tip| >= V |sin theta| ≈ 0,85 V a theta_catch=58 deg meme plantee
    (ecoulement de chant). Une convention de signe inverse donne |v_n| de l'ordre
    de V |cos theta| ≈ 0,5 V a plusieurs m/s, pas un voisinage de zero.
    """
    res = simulate(P)
    st = res.last_stroke()
    idx = st.drive_mask()
    L = P["rig"]["L_out_m"]
    v_n = np.abs(blade_normal_speed(
        st.theta[0][idx], st.theta_dot[0][idx], st.V[idx], L))
    # premiers 8 % de la propulsion = juste apres l'attaque
    n_early = max(3, int(0.08 * idx.sum()))
    assert v_n[:n_early].mean() < 1.5, (
        f"|v_n| palette/eau a l'attaque = {v_n[:n_early].mean():.2f} m/s, "
        "attendu < 1.5 — verifier la convention de signe")


def test_blade_slips_sternward_mid_drive(P):
    """Le glissement doit se faire vers la poupe : c'est ce qui propulse.

    Echantillon a 35 % de la duree de propulsion depuis l'attaque — phase de
    forte puissance, independante de la facon dont le masque d'immersion se
    referme en fin de coup.
    """
    res = simulate(P)
    st = res.last_stroke()
    th = st.theta[0]
    theta_finish = np.radians(P["rig"]["theta_finish_deg"])
    # Attaque = debut de la fenetre de coup (poste 0, offsets nuls).
    # Degage = premier franchissement de theta_finish a la baisse.
    crossing = np.where((th[:-1] > theta_finish) & (th[1:] <= theta_finish))[0]
    assert crossing.size > 0, "pas de degage detecte sur le dernier coup"
    i_fin = int(crossing[0] + 1)
    T_drive = float(st.t[i_fin] - st.t[0])
    assert T_drive > 0.05, f"T_drive trop court ({T_drive:.3f} s)"
    k = int(np.argmin(np.abs(st.t - (st.t[0] + 0.35 * T_drive))))
    vx, _ = blade_velocity_water(th[k], st.theta_dot[0][k], st.V[k],
                                P["rig"]["L_out_m"])
    assert vx < 0, (
        f"a 35 % de T_drive la palette doit glisser vers la poupe, vx={vx:.2f}")


# ---------------------------------------------------------------- coherence
def test_zero_wind_zero_current_ground_equals_water(P):
    p = copy.deepcopy(P)
    p["environment"]["wind_axial_ms"] = 0.0
    p["environment"]["current_ms"] = 0.0
    res = simulate(p)
    st = res.last_stroke()
    assert np.allclose(st.V, st.V_ground, atol=1e-9)


def test_identical_offsets_give_identical_seats(P):
    """Sans decalage de phase, les n postes doivent etre strictement identiques."""
    res = simulate(P)
    st = res.last_stroke()
    f = st.handle_force  # (n_seats, n_samples)
    assert f.shape[0] == P["meta"]["n_rowers"]
    for s in range(1, f.shape[0]):
        assert np.allclose(f[0], f[s], rtol=1e-9, atol=1e-9), \
            f"poste {s+1} differe du poste 1 alors que tous les offsets sont nuls"


def test_phase_offset_actually_shifts_seat(P):
    n = int(P["meta"]["n_rowers"])
    if n < 2:
        pytest.skip("decalage inter-postes exige n_rowers >= 2")
    p = copy.deepcopy(P)
    offsets = [0.0] * n
    offsets[1] = 50.0
    p["crew"]["phase_offset_ms"] = offsets
    res = simulate(p)
    st = res.last_stroke()
    f = st.handle_force
    assert not np.allclose(f[0], f[1], atol=1e-6), \
        "un decalage de 50 ms doit produire une trace differente"
