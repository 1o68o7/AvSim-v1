"""§4 — pistes V/a empilées + curseur unique (brief-visuels §4)."""
from __future__ import annotations

import numpy as np
from fastapi.testclient import TestClient

from avsim.api.app import app


def _simulate_series(boat_class: str) -> dict:
    client = TestClient(app)
    r = client.post(
        "/api/simulate",
        headers={"X-DataR0w-Role": "analyst"},
        json={"boat_class": boat_class, "n_strokes": 4, "n_discard": 2},
    )
    assert r.status_code == 200, r.text
    return r.json()["series"]


def _assert_sync_series(s: dict) -> None:
    n = len(s["u"])
    assert len(s["theta_dot_deg_s"]) == n
    assert len(s["A_ms2"]) == n
    assert len(s["V_ms"]) == n
    assert len(s["handle_force_N"]) == n
    assert np.std(s["A_ms2"]) > 1e-6
    assert np.max(np.abs(s["theta_dot_deg_s"])) > 1.0


def test_stroke_sync_tracks_api_2x():
    _assert_sync_series(_simulate_series("2x"))


def test_stroke_sync_tracks_api_8plus():
    _assert_sync_series(_simulate_series("8+"))
