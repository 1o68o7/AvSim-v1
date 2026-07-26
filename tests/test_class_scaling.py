"""Test 2 — cohérence inter-classes §9.3.

scale_from_8plus(M_tot) seul (pas de lecture des 7 autres YAML) ;
P/rameur simulée ∈ [420, 560] W sur les 8 classes (dépend du régime §9.2).
"""
from __future__ import annotations

import inspect

import pytest

from avsim.core.boat_class import scale_from_8plus, total_mass_kg
from avsim.core.params import load_class
from phase1_metrics import ALL_CLASSES, steady_stroke_metrics


def test_scale_function_does_not_read_other_class_files() -> None:
    src = inspect.getsource(scale_from_8plus)
    forbidden = ("load_class", "load_params", "CLASSES_DIR", "class_path", "classes/")
    for tok in forbidden:
        assert tok not in src, f"scale_from_8plus ne doit pas contenir {tok!r}"


def test_skiff_k_drag_band_via_scale_only() -> None:
    """k_drag 1x via scale_from_8plus(M_tot) ∈ [3,0 ; 3,6] (calculé ≈ 3,15)."""
    kd = scale_from_8plus(total_mass_kg(load_class("1x")))["k_drag"]
    assert 3.0 <= kd <= 3.6


@pytest.mark.parametrize("code", ALL_CLASSES)
def test_P_rower_420_560_all_classes(code: str) -> None:
    """Puissance/rameur simulée — bande §9.3 (légèrement plus large que §9.2)."""
    m = steady_stroke_metrics(code)
    p = m["P_rower_mean_W"]
    assert 420.0 <= p <= 560.0, (
        f"{code} ({m['status']}): P_rower={p:.1f} W hors [420,560] — "
        f"découverte Phase 1, ne pas assouplir le seuil"
    )
