"""Test 1 — plausibilité §9.2, statut différencié validée / bêta.

Enchaînement obligatoire (brief §3.3 puis §9.2) :
1. `envelope.is_admissible` / règles `check_outputs` — rejet structurel
2. bornes §9.2 plus strictes là où elles existent

Ce ne sont PAS des bornes en conflit. Exemple η :
- enveloppe §3.3 : [0,68–0,92] (modèle de palette faux → REJECT)
- plausibilité §9.2 : [0,75–0,85] (cible Kleshnev/AIS, sous-ensemble)

Les deux modules se citent (`envelope.check_outputs` ↔ ce fichier).
`steady_stroke_metrics` porte `envelope_admissible` / `envelope_violations`.

Ne pas assouplir un seuil. Sur 8+/1x, η hors bande est un écart connu
du modèle 1DOF (STATE.md / ROADMAP) → xfail documenté. Sur les 6 classes
bêta, un échec est une découverte à rapporter (Phase 1 : échouer pour de
vraies raisons).
"""
from __future__ import annotations

import pytest

from avsim.core.envelope import Severity

from phase1_metrics import (
    ALL_CLASSES,
    BETA,
    KNOWN_ETA_GAP_CLASSES,
    VALIDATED,
    check_factor_band,
    steady_stroke_metrics,
)

# Rejet structurel η — brief §3.3 (doit rester aligné avec envelope.py).
ETA_ENVELOPE_LO, ETA_ENVELOPE_HI = 0.68, 0.92
# Cible crédibilité — brief §9.2 (plus stricte, sous-ensemble).
ETA_PLAUS_LO, ETA_PLAUS_HI = 0.75, 0.85


@pytest.fixture(scope="module", params=list(ALL_CLASSES))
def metrics(request):
    return steady_stroke_metrics(request.param)


def test_envelope_admissible_before_plausibility(metrics) -> None:
    """Gate §3.3 : is_admissible avant d'interpréter les bornes §9.2."""
    code = metrics["code"]
    assert "envelope_admissible" in metrics and "envelope_violations" in metrics
    rejects = [
        v for v in metrics["envelope_violations"] if v.severity is Severity.REJECT
    ]
    assert metrics["envelope_admissible"], (
        f"{code} ({metrics['status']}): envelope.is_admissible=False — "
        f"§9.2 ne s'applique qu'après levée de : "
        + "; ".join(f"{v.rule}={v.value:.3g}" for v in rejects)
    )


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
    """η : d'abord §3.3 [0,68–0,92], puis cible §9.2 [0,75–0,85]."""
    eta = metrics["eta_blade"]
    code = metrics["code"]
    # Invariant de sous-ensemble (les bornes ne sont pas en conflit).
    assert ETA_ENVELOPE_LO < ETA_PLAUS_LO < ETA_PLAUS_HI < ETA_ENVELOPE_HI

    env_ok = ETA_ENVELOPE_LO <= eta <= ETA_ENVELOPE_HI
    plaus_ok = ETA_PLAUS_LO <= eta <= ETA_PLAUS_HI
    env_reject = [
        v
        for v in metrics["envelope_violations"]
        if v.rule == "mech.eta_blade" and v.severity is Severity.REJECT
    ]
    assert env_ok == (not env_reject), (
        f"{code}: envelope.mech.eta_blade désynchronisé de la bande "
        f"[{ETA_ENVELOPE_LO},{ETA_ENVELOPE_HI}] (η={eta:.3f})"
    )

    if not env_ok:
        if code in KNOWN_ETA_GAP_CLASSES:
            pytest.xfail(
                f"{code}: η={eta:.3f} hors enveloppe §3.3 "
                f"[{ETA_ENVELOPE_LO},{ETA_ENVELOPE_HI}] — écart 1DOF connu ; "
                f"cible §9.2 [{ETA_PLAUS_LO},{ETA_PLAUS_HI}] non évaluée."
            )
        assert False, (
            f"{code} ({metrics['status']}): η={eta:.3f} REJECT enveloppe "
            f"§3.3 [{ETA_ENVELOPE_LO},{ETA_ENVELOPE_HI}] avant §9.2"
        )

    if code in KNOWN_ETA_GAP_CLASSES and not plaus_ok:
        pytest.xfail(
            f"{code}: η={eta:.3f} dans enveloppe §3.3 mais hors cible §9.2 "
            f"[{ETA_PLAUS_LO},{ETA_PLAUS_HI}] — écart 1DOF connu."
        )
    assert plaus_ok, (
        f"{code} ({metrics['status']}): η={eta:.3f} hors cible §9.2 "
        f"[{ETA_PLAUS_LO},{ETA_PLAUS_HI}] "
        f"(enveloppe §3.3 [{ETA_ENVELOPE_LO},{ETA_ENVELOPE_HI}] OK)"
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
    """Glissement : même bande §3.3 / §9.2 [0,4–1,4] — enveloppe d'abord."""
    s = metrics["slip_mean_ms"]
    code = metrics["code"]
    env_reject = [
        v
        for v in metrics["envelope_violations"]
        if v.rule == "mech.blade_slip" and v.severity is Severity.REJECT
    ]
    if env_reject:
        assert False, (
            f"{code}: slip REJECT enveloppe §3.3 ({env_reject[0].message}) "
            f"avant §9.2"
        )
    assert 0.4 <= s <= 1.4, (
        f"{code} ({metrics['status']}): slip_mean={s:.3f} m/s hors [0,4–1,4]"
    )


def test_inventory_validated_and_beta() -> None:
    assert VALIDATED == {"8+", "1x"}
    assert BETA == {"2x", "2-", "4x", "4-", "4+", "8x"}
