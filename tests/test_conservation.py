"""Tests de conservation — brief section 8.1.

Le bilan energetique est le produit du projet. S'il ne boucle pas, rien
d'autre n'a de valeur.
"""
import copy

from avsim.core.solver import simulate


def test_energy_balance_closes(res):
    """Travail propulsif = trainee hydro + trainee aero + variation d'energie cinetique.

    C'est un test independant de l'integration ODE : si le solveur derive,
    ce residu explose.
    """
    e = res.last_stroke().energy()
    lhs = e["E_prop_J"]
    rhs = e["E_hull_drag_J"] + e["E_aero_J"] + e["dE_kinetic_J"]
    residual = abs(lhs - rhs) / max(abs(lhs), 1.0)
    assert residual < 5e-3, (
        f"residu du bilan = {residual*100:.3f} %, attendu < 0.5 %\n"
        f"  E_prop={lhs:.1f} J  hydro={e['E_hull_drag_J']:.1f}  "
        f"aero={e['E_aero_J']:.1f}  dEc={e['dE_kinetic_J']:.1f}")


def test_rower_work_equals_losses(res):
    """Sur un cycle etabli : travail des rameurs = pertes palette + hydro + aero."""
    e = res.last_stroke().energy()
    lhs = e["E_rower_J"]
    rhs = e["E_blade_loss_J"] + e["E_hull_drag_J"] + e["E_aero_J"] + e["dE_kinetic_J"]
    residual = abs(lhs - rhs) / max(abs(lhs), 1.0)
    assert residual < 1e-2, f"residu = {residual*100:.3f} %"


def test_steady_state_reached(res):
    """La derive de vitesse moyenne entre les deux derniers coups doit etre faible."""
    v_a = res.stroke(-2).V.mean()
    v_b = res.stroke(-1).V.mean()
    drift = abs(v_b - v_a) / v_a
    assert drift < 5e-3, f"derive de {drift*100:.3f} % entre les deux derniers coups"


def test_all_energy_terms_have_correct_sign(res):
    e = res.last_stroke().energy()
    assert e["E_prop_J"] > 0, "le travail propulsif doit etre positif"
    assert e["E_hull_drag_J"] > 0, "la trainee de coque doit dissiper"
    assert e["E_blade_loss_J"] > 0, "les pertes de palette doivent etre positives"
    assert 0.0 < e["eta_blade"] <= 1.0, f"rendement de palette hors bornes : {e['eta_blade']}"


def test_numerical_convergence(P):
    """Tolerance resserree d'un ordre : la vitesse moyenne ne doit pas bouger de > 0.1 %."""
    p = copy.deepcopy(P)
    v_loose = simulate(p).last_stroke().V.mean()
    p2 = copy.deepcopy(P)
    p2["numerics"]["rtol"] = 1e-9
    p2["numerics"]["atol"] = 1e-11
    v_tight = simulate(p2).last_stroke().V.mean()
    rel = abs(v_tight - v_loose) / v_loose
    assert rel < 1e-3, f"non convergent : {rel*100:.4f} % d'ecart"


def test_periodicity_of_body_motion(res):
    """Le CdM equipage doit revenir a sa position de depart apres un cycle complet."""
    st = res.last_stroke()
    assert abs(st.com_rel[0] - st.com_rel[-1]) < 2e-3, \
        "le mouvement corporel n'est pas periodique"
