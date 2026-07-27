"""§5 — replay séries enrichies pour TeamView 4 quadrants (2x + 8+)."""
from __future__ import annotations

import numpy as np

from avsim.core.params import load_class
from avsim.core.solver import simulate
from avsim.io.replay import stroke_frame


def _sim(code: str, n_strokes: int = 5, n_discard: int = 2):
    P = load_class(code)
    P["numerics"]["n_strokes"] = n_strokes
    P["numerics"]["n_discard"] = n_discard
    return simulate(P), P


def _assert_team_frame(frame: dict, n_rowers: int) -> None:
    assert frame["P_rower_mean_W"] > 0
    s = frame["series"]
    keys = ("handle_force_N", "theta_deg", "theta_dot_deg_s", "A_ms2", "V_ms")
    for k in keys:
        assert k in s
        assert len(s[k]) > 5
    n = len(s["handle_force_N"])
    assert len(s["theta_dot_deg_s"]) == n
    assert len(s["A_ms2"]) == len(s["V_ms"])
    bars = [c for c in frame["crew"] if c.get("stroke_bar")]
    assert len(bars) == n_rowers


def test_replay_frame_team_series_2x():
    res, P = _sim("2x")
    frame = stroke_frame(res.stroke(-1), boat_class="2x", stroke_index=0, params=P)
    _assert_team_frame(frame, 2)


def test_replay_frame_team_series_8plus():
    res, P = _sim("8+", n_strokes=4, n_discard=2)
    frame = stroke_frame(res.stroke(-1), boat_class="8+", stroke_index=0, params=P)
    _assert_team_frame(frame, 8)
    assert np.std(frame["series"]["handle_force_N"]) > 1.0
