"""Test 3 — triangulation §9.4 (Atkinson / Kleshnev / van Holst).

Étape 1 (lecture source, avant tout code de comparaison quantitative) :

Page `https://atkinsopht.com/row/comprslt.htm` (consultée 2026-07-26) :
liste les *types* d'entrées appariées entre ROWING (Atkinson) et van Holst
(masse fixe/mobile, force normale palette ou équivalent poignée linéaire,
outboard, angles catch/release, course de coulisse, période de retour ou
cadence, cant, aire de palette, facteur de résistance coque, C_L/C_D(α),
cinématique de coulisse) — **sans publier les valeurs numériques** utilisées
pour la comparaison.

Page `https://www.atkinsopht.com/row/validate.htm` : annonce un tableau de
comparaison skiff Atkinson/van Holst / Roosendaal, mais le HTML extrait ne
contient pas les chiffres d'entrée (tableau vraisemblablement image / non
transcrit). Les seules grandeurs numériques reprises côté bilan (shelwork.htm)
sont des *sorties* :
  Atkinson 552 W tot / 2208 W métab / η_blade 75 % / diss. corps 25 %
  Kleshnev 544 W / 2386 W / 79 % / 23 %
Règle qualitative : ~3/4 du travail poignée atteint la dame.

Conséquence (brief Phase 1) : **ne pas approximer silencieusement** des
entrées appariées. Comparaison quantitative via `override()` reportée ;
ce fichier documente l'état et garde un contrôle *qualitatif* d'ordre de
grandeur sur notre 8+ par défaut (η_blade vs bande publiée), marqué skip
tant que les entrées appariées ne sont pas sourcées (MANQUES D6 partiel).
"""
from __future__ import annotations

import pytest

# Chiffres publiés shelwork.htm — sorties, pas entrées.
ATKINSON_KLESHNEV = {
    "P_tot_W": (552.0, 544.0),
    "P_met_W": (2208.0, 2386.0),
    "body_dissipation": (0.25, 0.23),
    "eta_blade": (0.75, 0.79),
}


def test_paired_inputs_not_reconstructible_from_comprslt() -> None:
    """Garde-fou : on refuse de fabriquer des entrées appariées inventées."""
    # Les champs listés sur comprslt.htm — aucun n'a de valeur dans la page.
    listed_fields = (
        "fixed_mass_kg",
        "moving_mass_kg",
        "blade_or_handle_force_profile",
        "L_out_m",
        "theta_catch_rad",
        "theta_release_rad",
        "slide_travel_m",
        "recovery_period_or_stroke_rate",
        "blade_cant_rad",
        "A_blade_m2",
        "hull_resistance_factor",
        "CL_CD_vs_alpha",
        "slide_kinematics",
    )
    assert len(listed_fields) >= 10
    # Explicit : pas de table numérique d'entrées disponible → skip quantitatif.
    pytest.skip(
        "Entrées appariées Atkinson/van Holst non reconstituables avec précision "
        "(comprslt.htm = liste de champs sans valeurs ; validate.htm = tableau "
        "non chiffré dans le HTML). Comparaison quantitative reportée — "
        "qualitative seulement (ordre de grandeur η_blade / parts). "
        "Voir docstring du module + docs/MANQUES.md D6."
    )


def test_published_dispersion_eta_blade_band() -> None:
    """Les modèles publiés s'accordent sur η_blade ≈ 0,75–0,79 (± quelques pts)."""
    a, k = ATKINSON_KLESHNEV["eta_blade"]
    assert abs(a - k) / max(a, k) < 0.06  # ~5 % relatif — ordre brief
    assert 0.70 <= min(a, k) and max(a, k) <= 0.85


def test_qualitative_our_decomposition_vs_published_dispersion() -> None:
    """Comparaison qualitative 8+ défaut — pas d'override d'entrées appariées."""
    pytest.skip(
        "Comparaison qualitative uniquement tant que les entrées appariées "
        "manquent : notre η_blade≈0,62 (écart 1DOF connu) tombe hors de la "
        "dispersion Atkinson/Kleshnev 0,75–0,79 ; les parts hydro/blade "
        "(~47 %/~48 %) divergent aussi des postes consensuels. Documenter "
        "la divergence (corps / échange cinétique) est l'objectif projet — "
        "graphique reporté à data triangulation sourcée. Ne pas forcer un "
        "accord quantitatif sur le 8+ défaut vs skiff Atkinson."
    )
