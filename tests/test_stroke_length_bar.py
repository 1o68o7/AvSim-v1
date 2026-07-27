"""Étape 1 — barre de longueur de coup (2x + 8+)."""
from __future__ import annotations

import numpy as np
from fastapi.testclient import TestClient

from avsim.api.app import app
from avsim.core.params import load_class
from avsim.core.solver import simulate
from avsim.io.coaching_viz import (
    IMMERSION_EFFECTIVE,
    crew_stroke_bars,
    stroke_length_bar,
)
from avsim.io.replay import stroke_frame


def _sim(code: str, n_strokes: int = 5, n_discard: int = 2):
    P = load_class(code)
    P["numerics"]["n_strokes"] = n_strokes
    P["numerics"]["n_discard"] = n_discard
    return simulate(P), P


def test_stroke_bar_parts_sum_2x():
    res, P = _sim("2x")
    st = res.stroke(-1)
    th_c = np.radians(P["rig"]["theta_catch_deg"])
    th_f = np.radians(P["rig"]["theta_finish_deg"])
    bar = stroke_length_bar(
        st.theta[0], st.immersion[0],
        th_catch=th_c, th_finish=th_f, L_slide_m=P["rig"]["L_slide_m"],
    )
    s = bar["catch_white"] + bar["immersed"] + bar["finish_white"]
    assert abs(s - 1.0) < 1e-6
    assert bar["immersed"] > 0.2
    assert bar["immersion_threshold"] == IMMERSION_EFFECTIVE


def test_stroke_bar_8plus_n_rowers():
    res, P = _sim("8+", n_strokes=4, n_discard=2)
    rows = crew_stroke_bars(res.stroke(-1), P)
    assert len(rows) == 8
    for r in rows:
        b = r["stroke_bar"]
        assert 0.05 <= b["length_norm"] <= 1.25
        assert abs(
            b["catch_white"] + b["immersed"] + b["finish_white"] - 1.0
        ) < 1e-6


def test_api_simulate_stroke_bar_2x():
    client = TestClient(app)
    r = client.post(
        "/api/simulate",
        headers={"X-DataR0w-Role": "analyst"},
        json={"boat_class": "2x", "n_strokes": 4, "n_discard": 2},
    )
    assert r.status_code == 200, r.text
    crew = r.json()["crew"]
    assert len(crew) == 2
    assert "stroke_bar" in crew[0]
    assert crew[0]["stroke_bar"]["immersed"] > 0


def test_replay_frame_stroke_bars():
    res, P = _sim("2x")
    frame = stroke_frame(res.stroke(-1), boat_class="2x", stroke_index=0, params=P)
    assert len(frame["stroke_bars"]) == 2
    assert frame["crew"][0]["stroke_bar"] is not None
