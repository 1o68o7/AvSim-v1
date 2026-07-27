"""§3 — courbe poisson ω(θ) (2x + 8+)."""
from __future__ import annotations

import numpy as np
from fastapi.testclient import TestClient

from avsim.api.app import app
from avsim.core.params import load_class
from avsim.core.solver import simulate
from avsim.io.coaching_viz import crew_stroke_bars, fish_curve


def _sim(code: str, n_strokes: int = 5, n_discard: int = 2):
    P = load_class(code)
    P["numerics"]["n_strokes"] = n_strokes
    P["numerics"]["n_discard"] = n_discard
    return simulate(P), P


def test_fish_curve_both_halves_2x():
    res, P = _sim("2x")
    st = res.stroke(-1)
    fish = fish_curve(st.theta[0], st.theta_dot[0])
    w = np.asarray(fish["theta_dot_deg_s"])
    assert len(fish["theta_deg"]) == len(st.t)
    assert np.any(w > 0) and np.any(w < 0)


def test_crew_stroke_bars_fish_8plus():
    res, P = _sim("8+", n_strokes=4, n_discard=2)
    st = res.stroke(-1)
    rows = crew_stroke_bars(st, P)
    assert len(rows) == 8
    for r in rows:
        fish = r["fish"]
        assert len(fish["theta_deg"]) == len(st.t)
        w = np.asarray(fish["theta_dot_deg_s"])
        assert np.any(w > 0) and np.any(w < 0)


def test_api_simulate_crew_fish_2x():
    client = TestClient(app)
    r = client.post(
        "/api/simulate",
        headers={"X-DataR0w-Role": "analyst"},
        json={"boat_class": "2x", "n_strokes": 4, "n_discard": 2},
    )
    assert r.status_code == 200, r.text
    crew = r.json()["crew"]
    assert len(crew[0]["fish"]["theta_deg"]) > 10
    assert crew[0]["drive"]["u"]  # §2 inchangé


def test_api_simulate_crew_fish_8plus():
    client = TestClient(app)
    r = client.post(
        "/api/simulate",
        headers={"X-DataR0w-Role": "analyst"},
        json={"boat_class": "8+", "n_strokes": 4, "n_discard": 2},
    )
    assert r.status_code == 200, r.text
    crew = r.json()["crew"]
    assert len(crew) == 8
    for seat in crew:
        assert len(seat["fish"]["theta_deg"]) > 10
