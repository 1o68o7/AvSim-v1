"""Triangulation Atkinson vs Kleshnev — shelwork.htm (label honnête).

Source : https://atkinsopht.com/row/shelwork.htm (relue 2026-07-26).

Ce n'est **pas** la comparaison Atkinson / van Holst / Roosendaal initialement
visée au brief §9.4 : shelwork.htm confronte Atkinson (ROWING) à Kleshnev
(AIS) sur des *sorties* d'efficacité, sans publier les entrées appariées
(catch/release, aire de palette, Kw, profil de force).

Chiffres extraits (sorties) :
  Ptot     Atkinson 552 W / Kleshnev 544 W
  Pmétab   2208 W / 2386 W
  corps    25 % / 23 %
  η_blade  75 % / 79 %
  règle    ~3/4 du travail poignée → dame

Sans entrées appariées reconstituables : pas d'`override()` quantitatif.
Contrôles = cohérence de la dispersion publiée + skip explicite de toute
simulation « appariée » inventée. Voir docs/diag-eta-cf-triangulation.md.
"""
from __future__ import annotations

import pytest

# Sorties shelwork.htm — Atkinson vs Kleshnev (pas van Holst / Roosendaal).
ATKINSON = {
    "P_tot_W": 552.0,
    "P_met_W": 2208.0,
    "body_dissipation": 0.25,
    "eta_blade": 0.75,
}
KLESHNEV = {
    "P_tot_W": 544.0,
    "P_met_W": 2386.0,
    "body_dissipation": 0.23,
    "eta_blade": 0.79,
}


def test_label_is_atkinson_vs_kleshnev_not_van_holst() -> None:
    """Garde-fou de libellé — éviter de revendiquer van Holst/Roosendaal ici."""
    doc = __doc__ or ""
    assert "Atkinson" in doc and "Kleshnev" in doc
    assert "van Holst" in doc  # mentionné pour dire ce que ce n'est pas
    assert "shelwork.htm" in doc


def test_published_dispersion_eta_blade_atkinson_kleshnev() -> None:
    """Les deux s'accordent sur η_blade ≈ 0,75–0,79 (écart relatif ~5 %)."""
    a, k = ATKINSON["eta_blade"], KLESHNEV["eta_blade"]
    assert abs(a - k) / max(a, k) < 0.06
    assert 0.70 <= min(a, k) <= max(a, k) <= 0.85


def test_published_dispersion_body_and_power() -> None:
    """Corps 23–25 % ; P_tot ~550 W — postes où ils sont proches."""
    assert abs(ATKINSON["body_dissipation"] - KLESHNEV["body_dissipation"]) <= 0.03
    assert abs(ATKINSON["P_tot_W"] - KLESHNEV["P_tot_W"]) / 552.0 < 0.03


def test_no_paired_inputs_on_shelwork_skip_quantitative_sim() -> None:
    """Pas d'entrées catch/release/aire sur shelwork.htm → pas de sim appariée."""
    pytest.skip(
        "shelwork.htm = sorties Atkinson/Kleshnev seulement ; entrées appariées "
        "absentes. Comparaison quantitative via override() reportée (qualitatif "
        "uniquement). Ne pas inventer catch/release/A_blade. "
        "docs/diag-eta-cf-triangulation.md §3."
    )


def test_qualitative_our_eta_vs_published_band() -> None:
    """Notre η≈0,62 (8+) hors 0,75–0,79 — écart 1DOF déjà documenté, pas un match forcé."""
    pytest.skip(
        "Qualitatif : dispersion publiée η∈[0,75;0,79] ; modèle 1DOF ~0,62 "
        "(STATE.md). Zone de désaccord corps/échange cinétique = cible "
        "instrumentation Phase 8 — graphique reporté. Pas d'accord quantitatif "
        "forcé sur le 8+ défaut vs l'exemple shelwork (contexte non apparié)."
    )
