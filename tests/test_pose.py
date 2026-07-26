"""Pose sagittale — source unique pour StrokeGeometry (8 classes)."""
import math

import pytest
from fastapi.testclient import TestClient

from avsim.api.app import app
from avsim.core.catalog import list_classes
from avsim.core.pose import pose_at_u, pose_series

CODES = [c["code"] for c in list_classes()]


@pytest.mark.parametrize("code", CODES)
def test_pose_at_endpoints_finite(code):
    for u in (0.0, 0.3, 1.0):
        p = pose_at_u(code, u)
        assert p["boat_class"] == code
        assert p["source"] == "simulated"
        for name in ("ankle", "knee", "hip", "shoulder", "hand", "head"):
            pt = p["joints"][name]
            assert math.isfinite(pt["x"]) and math.isfinite(pt["z"])
        assert math.isfinite(p["oar"]["blade"]["x"])
        assert math.isfinite(p["theta_deg"])


def test_pose_handle_matches_oar_geometry_8plus():
    """x_hand == handle_position(θ).x — pas de second calcul divergent."""
    p = pose_at_u("8+", 0.0)
    assert abs(p["joints"]["hand"]["x"] - p["oar"]["handle"]["x"]) < 1e-9
    p1 = pose_at_u("8+", 1.0)
    # arc catch → finish : θ diminue
    assert p1["theta_deg"] < p["theta_deg"]


def test_pose_series_length():
    s = pose_series("1x", n=11)
    assert len(s["frames"]) == 11
    assert s["u"][0] == 0.0 and s["u"][-1] == 1.0


def test_catch_unvalidated_badge_tracks_knee_behind_ankle():
    """Badge catch : présent ssi x_knee < x_ankle à u≈0 — suit la géométrie.

    Ne fige pas le signe du genou : si `x_ankle_off_m` est recalibré un jour
    et le problème disparaît, le flag doit rester absent (pas un assert
    hardcodé sur behind=True).
    """
    catch = pose_at_u("8+", 0.0)
    behind = catch["joints"]["knee"]["x"] < catch["joints"]["ankle"]["x"]
    assert catch["flags"]["knee_behind_ankle"] is behind
    assert catch["flags"]["show_catch_unvalidated_badge"] is behind

    mid = pose_at_u("8+", 0.5)
    assert mid["flags"]["show_catch_unvalidated_badge"] is False


def test_api_pose_all_classes():
    client = TestClient(app)
    H = {"X-DataR0w-Role": "analyst"}
    for code in CODES:
        r = client.get(
            "/api/pose",
            params={"boat_class": code, "u": 0.4},
            headers=H,
        )
        assert r.status_code == 200, (code, r.text)
        assert r.json()["joints"]["hip"]
    series = client.get(
        "/api/pose/series",
        params={"boat_class": "2x", "n": 9},
        headers=H,
    )
    assert series.status_code == 200
    assert len(series.json()["frames"]) == 9
