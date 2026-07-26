"""Métriques visuelles coaching — barre / nesting / poisson (2x + 8+)."""
from __future__ import annotations

import numpy as np
from fastapi.testclient import TestClient

from avsim.api.app import app
from avsim.core.params import load_class
from avsim.core.solver import simulate
from avsim.io.coaching_viz import (
    FORCE_WORK_FRAC,
    crew_coaching_payload,
    fish_curve,
    stroke_length_bar,
)
from avsim.io.replay import stroke_frame


def _sim(code: str, n_strokes: int = 5, n_discard: int = 2, **crew_kw):
    P = load_class(code)
    P["numerics"]["n_strokes"] = n_strokes
    P["numerics"]["n_discard"] = n_discard
    if crew_kw:
        P.setdefault("crew", {}).update(crew_kw)
    return simulate(P), P


def test_stroke_bar_parts_sum_to_one_2x():
    res, P = _sim("2x")
    st = res.stroke(-1)
    th_c = np.radians(P["rig"]["theta_catch_deg"])
    th_f = np.radians(P["rig"]["theta_finish_deg"])
    bar = stroke_length_bar(
        st.theta[0], st.handle_force[0], st.immersion[0],
        th_catch=th_c, th_finish=th_f, L_slide_m=P["rig"]["L_slide_m"],
    )
    s = bar["catch_white"] + bar["immersed"] + bar["finish_white"]
    assert abs(s - 1.0) < 1e-6
    assert 0.05 <= bar["length_norm"] <= 1.25
    assert bar["immersed"] > 0.2  # portion travaillante non nulle


def test_crew_payload_n_rowers_8plus():
    res, P = _sim("8+", n_strokes=4, n_discard=2)
    st = res.stroke(-1)
    rows = crew_coaching_payload(st, P)
    assert len(rows) == 8
    for r in rows:
        assert "stroke_bar" in r and "drive" in r and "fish" in r
        assert len(r["drive"]["u"]) == len(r["drive"]["handle_force_N"])
        assert len(r["fish"]["theta_deg"]) == len(st.t)


def test_fish_curve_has_both_signs():
    res, P = _sim("2x")
    st = res.stroke(-1)
    fish = fish_curve(st.theta[0], st.theta_dot[0])
    w = np.asarray(fish["theta_dot_deg_s"])
    assert np.any(w > 0) and np.any(w < 0)


def test_api_simulate_exposes_coaching_fields():
    client = TestClient(app)
    r = client.post(
        "/api/simulate",
        headers={"X-DataR0w-Role": "analyst"},
        json={"boat_class": "2x", "n_strokes": 4, "n_discard": 2},
    )
    assert r.status_code == 200, r.text
    data = r.json()
    assert "A_ms2" in data["series"]
    assert "theta_dot_deg_s" in data["series"]
    assert len(data["crew"]) == 2
    assert "stroke_bar" in data["crew"][0]
    assert data["crew"][0]["drive"]["u"]
    assert data["crew"][0]["fish"]["theta_deg"]


def test_replay_frame_has_stroke_bar():
    res, P = _sim("2x")
    frame = stroke_frame(res.stroke(-1), boat_class="2x", stroke_index=0, params=P)
    assert frame["crew"][0]["stroke_bar"] is not None
    assert "handle_force_N" in frame["series"]
    assert abs(FORCE_WORK_FRAC - 0.10) < 1e-9
