"""Étape 0 / §9.3 — loi d'échelle calee sur le seul 8+, pas de lecture YAML des 7 autres."""

from __future__ import annotations

import inspect

from avsim.core.boat_class import (
    M_TOT_8PLUS_KG,
    scale_from_8plus,
    total_mass_kg,
)
from avsim.core.params import load_class

ALL_CLASSES = ("1x", "2-", "2x", "4-", "4x", "4+", "8+", "8x")


def test_scale_from_8plus_isolated_from_other_class_yaml() -> None:
    """La fonction ne prend que M_tot — aucune lecture des YAML des 7 autres."""
    src = inspect.getsource(scale_from_8plus)
    assert "load_class" not in src
    assert "load_params" not in src
    assert "CLASSES_DIR" not in src
    assert "class_path" not in src
    # Constantes 8+ uniquement
    assert "855" in src or "M_TOT_8PLUS" in inspect.getsource(
        __import__("avsim.core.boat_class", fromlist=["*"])
    )


def test_m_tot_8plus_is_855() -> None:
    assert abs(total_mass_kg(load_class("8+")) - M_TOT_8PLUS_KG) < 1e-9


def test_yaml_drag_matches_scale_within_1pct() -> None:
    """Les k_drag/S_wet/CdA figés = même calcul §2.4, écart < 1 % (pas d'identité YAML↔YAML)."""
    for code in ALL_CLASSES:
        P = load_class(code)
        scaled = scale_from_8plus(total_mass_kg(P))
        for key in ("k_drag", "S_wet_m2", "CdA_m2"):
            yaml_v = float(P["boat"][key])
            ref = scaled[key]
            rel = abs(yaml_v - ref) / ref
            assert rel < 0.01, (
                f"{code} {key}: YAML={yaml_v:.4f} scale={ref:.4f} "
                f"écart={100 * rel:.3f}% > 1% — dérive possible du YAML"
            )


def test_skiff_k_drag_from_scale_in_literature_band() -> None:
    """Contrôle §9.3 : k_drag skiff via scale seul ∈ [3,0 ; 3,6] (calculé ≈ 3,15)."""
    kd = scale_from_8plus(total_mass_kg(load_class("1x")))["k_drag"]
    assert 3.0 <= kd <= 3.6, kd
