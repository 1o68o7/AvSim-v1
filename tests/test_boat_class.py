"""Étape 0 / §9.3 — BoatClass + loi d'échelle calée sur le seul 8+."""

from __future__ import annotations

import inspect

from avsim.core.boat_class import (
    M_TOT_8PLUS_KG,
    BoatClass,
    boat_class_from_params,
    scale_from_8plus,
    total_mass_kg,
)
from avsim.core.params import load_class

ALL_CLASSES = ("1x", "2-", "2x", "4-", "4x", "4+", "8+", "8x")


def test_scale_from_8plus_isolated_from_other_class_yaml() -> None:
    src = inspect.getsource(scale_from_8plus)
    assert "load_class" not in src
    assert "load_params" not in src
    assert "CLASSES_DIR" not in src


def test_m_tot_8plus_is_855() -> None:
    assert abs(total_mass_kg(load_class("8+")) - M_TOT_8PLUS_KG) < 1e-9


def test_yaml_drag_matches_scale_within_1pct() -> None:
    for code in ALL_CLASSES:
        P = load_class(code)
        scaled = scale_from_8plus(total_mass_kg(P))
        for key in ("k_drag", "S_wet_m2", "CdA_m2"):
            yaml_v = float(P["boat"][key])
            ref = scaled[key]
            rel = abs(yaml_v - ref) / ref
            assert rel < 0.01, (
                f"{code} {key}: YAML={yaml_v:.4f} scale={ref:.4f} "
                f"écart={100 * rel:.3f}% > 1%"
            )


def test_skiff_k_drag_from_scale_in_literature_band() -> None:
    kd = scale_from_8plus(total_mass_kg(load_class("1x")))["k_drag"]
    assert 3.0 <= kd <= 3.6, kd


def test_boat_class_from_code_dimensions_on_n_rowers() -> None:
    for code, n, scull, cox in (
        ("1x", 1, True, False),
        ("2-", 2, False, False),
        ("8+", 8, False, True),
        ("8x", 8, True, True),
    ):
        bc = BoatClass.from_code(code)
        assert bc.code == code
        assert bc.n_rowers == n
        assert bc.sculling is scull
        assert bc.coxed is cox
        assert bc.M_tot > 0
        assert bc.k_drag > 0
        if scull:
            assert bc.rig_pattern == ()
            assert bc.rig_label == "couple"
        else:
            assert len(bc.rig_pattern) == n
            assert set(bc.rig_pattern) <= {1, -1}
            assert bc.rig_label == "pointe alternee"


def test_boat_class_from_params_matches_yaml_drag() -> None:
    P = load_class("4x")
    bc = boat_class_from_params(P)
    assert bc.k_drag == float(P["boat"]["k_drag"])
    assert bc.S_wet_m2 == float(P["boat"]["S_wet_m2"])
    assert bc.CdA_m2 == float(P["boat"]["CdA_m2"])
    assert abs(bc.M_tot - total_mass_kg(P)) < 1e-9
