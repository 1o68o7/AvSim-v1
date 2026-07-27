"""Étape 2 — nesting forces équipage (drive_series) sur 2x + 8+."""
from __future__ import annotations

import numpy as np
from fastapi.testclient import TestClient

from avsim.api.app import app
from avsim.core.params import load_class
from avsim.core.solver import simulate
from avsim.io.coaching_viz import crew_stroke_bars, drive_series
from avsim.io.replay import stroke_frame


def _sim(code: str, n_strokes: int = 5, n_discard: int = 2):
    P = load_class(code)
    P["numerics"]["n_strokes"] = n_strokes
    P["numerics"]["n_discard"] = n_discard
    return simulate(P), P


def test_drive_series_monotone_u_2x():
    res, P = _sim("2x")
    st = res.stroke(-1)
    th_c = np.radians(P["rig"]["theta_catch_deg"])
    th_f = np.radians(P["rig"]["theta_finish_deg"])
    d = drive_series(
        st.theta[0],
        st.handle_force[0],
        st.immersion[0],
        st.theta_dot[0],
        th_catch=th_c,
        th_finish=th_f,
    )
    assert len(d["u"]) > 10
    assert len(d["u"]) == len(d["handle_force_N"])
    u = d["u"]
    assert all(u[i] <= u[i + 1] for i in range(len(u) - 1))
    assert max(d["handle_force_N"]) > 50.0


def test_crew_stroke_bars_drive_8plus():
    res, P = _sim("8+", n_strokes=4, n_discard=2)
    rows = crew_stroke_bars(res.stroke(-1), P)
    assert len(rows) == 8
    for r in rows:
        assert "drive" in r
        assert len(r["drive"]["u"]) > 5
        # barre §1 inchangée
        b = r["stroke_bar"]
        assert abs(b["catch_white"] + b["immersed"] + b["finish_white"] - 1.0) < 1e-6


def test_api_simulate_crew_drive_2x():
    client = TestClient(app)
    r = client.post(
        "/api/simulate",
        headers={"X-DataR0w-Role": "analyst"},
        json={"boat_class": "2x", "n_strokes": 4, "n_discard": 2},
    )
    assert r.status_code == 200, r.text
    crew = r.json()["crew"]
    assert len(crew) == 2
    assert len(crew[0]["drive"]["u"]) > 5
    assert crew[0]["stroke_bar"]["immersed"] > 0


def test_replay_frame_stroke_bars_drive():
    res, P = _sim("2x")
    frame = stroke_frame(res.stroke(-1), boat_class="2x", stroke_index=0, params=P)
    assert len(frame["stroke_bars"]) == 2
    assert len(frame["stroke_bars"][0]["drive"]["u"]) > 5
    assert frame["crew"][0]["drive"] is not None
