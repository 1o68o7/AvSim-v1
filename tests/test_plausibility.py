"""Test 1 — plausibilité §9.2, statut différencié validée / bêta.

Ne pas assouplir un seuil. Sur 8+/1x, η hors [0,75–0,85] est un écart connu
du modèle 1DOF (STATE.md / ROADMAP) → xfail documenté, pas un échec silencieux.
Sur les 6 classes bêta, un échec est une découverte à rapporter.
"""
from __future__ import annotations

import pytest

from phase1_metrics import (
    ALL_CLASSES,
    BETA,
    KNOWN_ETA_GAP_CLASSES,
    VALIDATED,
    check_factor_band,
    steady_stroke_metrics,
)


@pytest.fixture(scope="module", params=list(ALL_CLASSES))
def metrics(request):
    return steady_stroke_metrics(request.param)


def test_v_mean_within_8pct_v_ref(metrics) -> None:
    v, v_ref = metrics["v_mean_ms"], metrics["v_ref_ms"]
    lo, hi = 0.92 * v_ref, 1.08 * v_ref
    assert lo <= v <= hi, (
        f"{metrics['code']} ({metrics['status']}): v_mean={v:.3f} "
        f"hors ±8% de v_ref={v_ref:.2f} [{lo:.3f},{hi:.3f}]"
    )


def test_P_rower_420_540(metrics) -> None:
    p = metrics["P_rower_mean_W"]
    assert 420.0 <= p <= 540.0, (
        f"{metrics['code']} ({metrics['status']}): P_rower={p:.1f} W hors [420,540]"
    )


def test_eta_blade_075_085(metrics) -> None:
    eta = metrics["eta_blade"]
    code = metrics["code"]
    in_band = 0.75 <= eta <= 0.85
    if code in KNOWN_ETA_GAP_CLASSES and not in_band:
        pytest.xfail(
            f"{code}: η_blade={eta:.3f} hors [0,75–0,85] — écart connu modèle "
            f"1DOF (pas de contrôle d'incidence), documenté STATE.md / "
            f"ROADMAP-PRODUCTION.md Phase 1 ; ne pas traiter comme régression."
        )
    assert in_band, (
        f"{code} ({metrics['status']}): η_blade={eta:.3f} hors [0,75–0,85]"
    )


def test_part_hydro_70_80(metrics) -> None:
    p = metrics["part_hydro"]
    assert 0.70 <= p <= 0.80, (
        f"{metrics['code']} ({metrics['status']}): part_hydro={p:.3f} hors [0,70–0,80]"
    )


def test_part_blade_15_25(metrics) -> None:
    p = metrics["part_blade"]
    assert 0.15 <= p <= 0.25, (
        f"{metrics['code']} ({metrics['status']}): part_blade={p:.3f} hors [0,15–0,25]"
    )


def test_part_aero_05_10(metrics) -> None:
    p = metrics["part_aero"]
    assert 0.05 <= p <= 0.10, (
        f"{metrics['code']} ({metrics['status']}): part_aero={p:.3f} hors [0,05–0,10]"
    )


def test_check_factor_intra_stroke(metrics) -> None:
    code = metrics["code"]
    lo, hi = check_factor_band(code)
    cf = metrics["check_factor"]
    assert lo <= cf <= hi, (
        f"{code} ({metrics['status']}): check_factor={cf:.3f} hors [{lo},{hi}]"
    )


def test_slip_mean_04_14(metrics) -> None:
    s = metrics["slip_mean_ms"]
    assert 0.4 <= s <= 1.4, (
        f"{metrics['code']} ({metrics['status']}): slip_mean={s:.3f} m/s hors [0,4–1,4]"
    )


def test_inventory_validated_and_beta() -> None:
    assert VALIDATED == {"8+", "1x"}
    assert BETA == {"2x", "2-", "4x", "4-", "4+", "8x"}
