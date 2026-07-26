"""Domaine de validité §3 — règles isolées + taux de rejet multi-classes."""

from __future__ import annotations

import copy
from typing import Any

import pytest

from avsim.core.boat_class import BoatClass
from avsim.core.envelope import (
    Severity,
    check_inputs,
    check_outputs,
    is_admissible,
)
from avsim.core.params import load_class
from avsim.core.solver import simulate

ALL_CLASSES = ("1x", "2-", "2x", "4-", "4x", "4+", "8+", "8x")


def _P(code: str = "8+") -> dict[str, Any]:
    return load_class(code)


def _cls(P: dict) -> BoatClass:
    return BoatClass.from_params(P)


def _rules(violations) -> set[str]:
    return {v.rule for v in violations}


def _reject_rules(violations) -> set[str]:
    return {v.rule for v in violations if v.severity is Severity.REJECT}


# ---------------------------------------------------------------------------
# Helpers de sévérité
# ---------------------------------------------------------------------------

def test_is_admissible_ignores_warnings() -> None:
    P = _P("8+")
    P["technique"]["rate_spm"] = 48.0  # WARNING only (< 50)
    v = check_inputs(P, _cls(P))
    assert any(x.rule == "physio.stroke_rate" and x.severity is Severity.WARNING for x in v)
    assert is_admissible(v)


def test_is_admissible_false_on_reject() -> None:
    P = _P("8+")
    P["technique"]["rate_spm"] = 55.0
    v = check_inputs(P, _cls(P))
    assert any(x.severity is Severity.REJECT for x in v)
    assert not is_admissible(v)


# ---------------------------------------------------------------------------
# check_inputs — une règle à la fois
# ---------------------------------------------------------------------------

def test_reject_stroke_rate_only() -> None:
    P = _P("8+")
    P["technique"]["rate_spm"] = 55.0
    v = check_inputs(P, _cls(P))
    assert "physio.stroke_rate" in _reject_rules(v)
    # Pas d'autre REJECT physio/géom/env inventé
    assert _reject_rules(v) == {"physio.stroke_rate"}


def test_warn_drive_fraction_only() -> None:
    P = _P("8+")
    P["technique"]["drive_fraction"] = 0.20
    v = check_inputs(P, _cls(P))
    assert "physio.drive_fraction" in _rules(v)
    assert all(x.severity is Severity.WARNING for x in v if x.rule == "physio.drive_fraction")
    assert "physio.drive_fraction" not in _reject_rules(v)


def test_reject_trunk_amplitude_only() -> None:
    P = _P("8+")
    P["technique"]["trunk_catch_deg"] = -50.0
    P["technique"]["trunk_finish_deg"] = 50.0  # amp = 100° > 85
    v = check_inputs(P, _cls(P))
    assert "physio.trunk_amplitude" in _reject_rules(v)
    assert _reject_rules(v) == {"physio.trunk_amplitude"}


def test_reject_leg_reach_only() -> None:
    P = _P("8+")
    # |x| + L_slide ≥ 0,985·reach — sans toucher au reste
    P["rower"]["x_ankle_off_m"] = -0.50
    P["rig"]["L_slide_m"] = 0.80
    v = check_inputs(P, _cls(P))
    assert "geom.leg_reach" in _reject_rules(v)
    assert "geom.arm_extension" not in _reject_rules(v)  # BodyModel non appelé


def test_reject_arm_extension_only() -> None:
    P = _P("8+")
    # Arc extrême + L_in trop grand → e_raw hors [0.1, 1.0]·L_bras
    # tout en gardant la portée de jambe OK
    P["rig"]["L_in_m"] = 1.80
    P["rig"]["theta_catch_deg"] = 70.0
    P["rig"]["theta_finish_deg"] = -50.0
    v = check_inputs(P, _cls(P))
    assert "geom.leg_reach" not in _reject_rules(v)
    assert "geom.arm_extension" in _reject_rules(v)


def test_warn_blade_depth() -> None:
    P = _P("8+")
    P["technique"]["blade_depth_m"] = 0.05
    v = check_inputs(P, _cls(P))
    assert any(
        x.rule == "geom.blade_immersion_depth" and x.severity is Severity.WARNING
        for x in v
    )


def test_reject_wind_training() -> None:
    P = _P("8+")
    P["environment"]["wind_axial_ms"] = 12.0
    v = check_inputs(P, _cls(P))
    assert _reject_rules(v) == {"env.wind"}


def test_reject_current() -> None:
    P = _P("8+")
    P["environment"]["current_ms"] = 2.0
    v = check_inputs(P, _cls(P))
    assert "env.current" in _reject_rules(v)


def test_warn_validable_sur_eau() -> None:
    P = _P("8+")
    P["scenario"] = {"validable_sur_eau": False}
    v = check_inputs(P, _cls(P))
    assert any(
        x.rule == "experimental.validable_sur_eau"
        and x.severity is Severity.WARNING
        for x in v
    )


def test_sweep_f_peak_1100_at_plage_edge_not_reject() -> None:
    """F_peak=1100 : pile à la butée haute de plage pointe — WARNING non, REJECT non."""
    P = _P("8+")
    assert float(P["technique"]["F_peak_N"]) == 1100.0
    assert not _cls(P).sculling
    v = check_inputs(P, _cls(P))
    force = [x for x in v if x.rule == "physio.handle_peak_force_sweep"]
    assert force == []


def test_scull_f_peak_per_hand() -> None:
    P = _P("1x")
    P["technique"]["F_peak_N"] = 1600.0  # 800 N / main > 700 → REJECT
    v = check_inputs(P, _cls(P))
    assert "physio.handle_peak_force_scull" in _reject_rules(v)


# ---------------------------------------------------------------------------
# check_outputs — règles isolées via mock Stroke minimal
# ---------------------------------------------------------------------------

class _FakeStroke:
    """Stroke minimal pour déclencher une règle outputs sans simulate()."""

    def __init__(self, **kw):
        import numpy as np
        n = kw.get("n", 50)
        t = np.linspace(0.0, 1.0, n)
        self.t = t
        self.V = kw.get("V", np.full(n, 5.0))
        th_c = np.radians(kw.get("theta_catch_deg", 55.0))
        th_f = np.radians(kw.get("theta_finish_deg", -30.0))
        self.theta = kw.get("theta", np.linspace(th_c, th_f, n)[None, :])
        self.theta_dot = kw.get("theta_dot", np.full((1, n), -1.0))
        self.immersion = kw.get("immersion", np.ones((1, n)))
        self.handle_power = kw.get("handle_power", np.zeros((1, n)))
        self._en = kw.get("energy", {})

    def energy(self):
        return {
            "P_rower_mean_W": 400.0,
            "v_mean_ms": float(self.V.mean()),
            "check_factor": float(self.V.max() - self.V.min()),
            "eta_blade": 0.80,
            **self._en,
        }


def test_reject_eta_blade_only() -> None:
    P = _P("8+")
    st = _FakeStroke(energy={"eta_blade": 0.50, "v_mean_ms": 5.5, "check_factor": 0.6})
    # Vitesses poignée / glissement : annuler drive pour isoler η
    st.immersion[:] = 0.0
    v = check_outputs(st, P, _cls(P))
    assert "mech.eta_blade" in _reject_rules(v)


def test_reject_froude_only() -> None:
    P = _P("8+")
    # Fr = V/sqrt(g L) ; L_wl≈17 → Fr=0.3 ⇒ V≈3.9
    st = _FakeStroke(
        V=__import__("numpy").full(50, 2.0),
        energy={"eta_blade": 0.80, "v_mean_ms": 2.0, "check_factor": 0.6},
    )
    st.immersion[:] = 0.0
    v = check_outputs(st, P, _cls(P))
    assert "mech.froude" in _reject_rules(v)


def test_reject_power_instantaneous() -> None:
    import numpy as np
    P = _P("8+")
    hp = np.zeros((1, 50))
    hp[0, 10] = 2000.0
    st = _FakeStroke(
        handle_power=hp,
        energy={"eta_blade": 0.80, "v_mean_ms": 5.5, "check_factor": 0.6},
    )
    st.immersion[:] = 0.0
    v = check_outputs(st, P, _cls(P))
    assert "physio.power_instantaneous" in _reject_rules(v)


# ---------------------------------------------------------------------------
# Intégration — taux de rejet sur les 8 classes (params actuels)
# ---------------------------------------------------------------------------

@pytest.fixture(scope="module")
def rejection_report() -> dict[str, Any]:
    """Simule chaque classe, agrège check_inputs + check_outputs."""
    rows = []
    for code in ALL_CLASSES:
        P = load_class(code)
        # Régime établi (comme Phase 1)
        P = copy.deepcopy(P)
        P["numerics"]["n_strokes"] = 20
        P["numerics"]["n_discard"] = 10
        cls = BoatClass.from_params(P)
        vin = check_inputs(P, cls)
        res = simulate(P)
        vout = check_outputs(res, P, cls)
        all_v = vin + vout
        rows.append({
            "code": code,
            "admissible": is_admissible(all_v),
            "n_warn": sum(1 for x in all_v if x.severity is Severity.WARNING),
            "n_reject": sum(1 for x in all_v if x.severity is Severity.REJECT),
            "reject_rules": sorted(_reject_rules(all_v)),
            "warn_rules": sorted(
                x.rule for x in all_v if x.severity is Severity.WARNING
            ),
        })
    n_rej = sum(1 for r in rows if not r["admissible"])
    return {
        "rows": rows,
        "n_classes": len(rows),
        "n_rejected": n_rej,
        "rejection_rate": n_rej / len(rows),
    }


def test_rejection_rate_all_classes(rejection_report, capsys) -> None:
    """Rapport explicite du taux de rejet — chiffre pour décider Phase 5."""
    rep = rejection_report
    lines = [
        "",
        "=" * 60,
        "ENVELOPPE §3 — taux de rejet (params actuels, 8 classes)",
        f"  rejetées : {rep['n_rejected']}/{rep['n_classes']} "
        f"({100 * rep['rejection_rate']:.0f} %)",
        "-" * 60,
    ]
    for r in rep["rows"]:
        status = "REJECT" if not r["admissible"] else "OK    "
        lines.append(
            f"  {r['code']:4s}  {status}  "
            f"warn={r['n_warn']} reject={r['n_reject']}  "
            f"rules={r['reject_rules']}"
        )
    lines.append("=" * 60)
    print("\n".join(lines))
    # Toujours « vert » : le chiffre est le livrable, pas un seuil à forcer.
    assert rep["n_classes"] == 8
    assert 0.0 <= rep["rejection_rate"] <= 1.0
