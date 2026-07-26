"""Payload Vue Bilan / Équipage — 8+ validée et 2x bêta (Phase 7 Analyste)."""

from __future__ import annotations

from fastapi.testclient import TestClient

from avsim.api.app import app
from avsim.core.catalog import class_validation_status


client = TestClient(app)
H = {"X-DataR0w-Role": "analyst"}


def _sim(boat_class: str) -> dict:
    r = client.post(
        "/api/simulate",
        json={"boat_class": boat_class, "n_strokes": 4, "n_discard": 1},
        headers=H,
    )
    assert r.status_code == 200, r.text
    return r.json()


def test_balance_and_crew_payload_8plus_validated() -> None:
    assert class_validation_status("8+")["status"] == "validated"
    body = _sim("8+")
    assert body["validation"]["code"] == "8+"
    assert body["validation"]["status"] == "validated"
    e = body["energy"]
    for k in (
        "v_mean_ms",
        "v_min_ms",
        "v_max_ms",
        "check_factor",
        "eta_blade",
        "P_rower_mean_W",
        "E_prop_J",
        "E_blade_loss_J",
        "E_hull_drag_J",
        "E_aero_J",
        "T_drive_s",
    ):
        assert k in e
        assert isinstance(e[k], (int, float))
    assert "eta_blade" in body["targets_9_2"]
    crew = body["crew"]
    assert len(crew) == body["boat"]["n_rowers"] == 8
    for seat in crew:
        assert "seat" in seat
        assert "phase_offset_ms" in seat
        assert "E_handle_J" in seat
        assert "P_mean_W" in seat


def test_balance_and_crew_payload_2x_beta() -> None:
    assert class_validation_status("2x")["status"] == "beta"
    body = _sim("2x")
    assert body["validation"]["code"] == "2x"
    assert body["validation"]["status"] == "beta"
    assert "eta_blade" in body["energy"]
    assert len(body["crew"]) == body["boat"]["n_rowers"] == 2
