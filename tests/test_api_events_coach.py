"""Sessions / events / compare — Coach live & replay (2x)."""

from __future__ import annotations

import json

from fastapi.testclient import TestClient

from avsim.api.app import app
from avsim.io.events import STORE


def _parse_sse(body: str) -> list[dict]:
    frames = []
    for block in body.strip().split("\n\n"):
        for line in block.splitlines():
            if line.startswith("data: "):
                frames.append(json.loads(line[6:]))
    return frames


def test_events_schema_and_compare_no_mode_d_threshold() -> None:
    # store process-local — ok for TestClient
    client = TestClient(app)
    h = {"X-DataR0w-Role": "product"}

    r = client.post("/api/sessions", headers=h, json={"boat_class": "2x"})
    assert r.status_code == 200
    sid = r.json()["session_id"]

    # Replay with session → stroke marks
    stream = client.get(
        "/api/replay/stream",
        params={
            "boat_class": "2x",
            "n_strokes": 8,
            "n_discard": 2,
            "realtime": False,
            "session_id": sid,
        },
        headers=h,
    )
    assert stream.status_code == 200
    frames = _parse_sse(stream.text)
    strokes = [f for f in frames if f["kind"] == "stroke"]
    assert len(strokes) == 6
    assert "crew" in strokes[0] and len(strokes[0]["crew"]) == 2
    assert "sync_alert" in strokes[0]
    assert "Mode D" in strokes[0]["sync_alert"]["note"]

    # Joindre au milieu de la séance (précision seconde) pour avoir avant+après
    mid_t = STORE.get(sid).strokes[len(STORE.get(sid).strokes) // 2].t_utc
    ev = client.post(
        f"/api/sessions/{sid}/events",
        headers=h,
        json={
            "source": "coach_voice",
            "tag": "longueur",
            "transcript": "allonge",
            "audio_ref": None,
            "t_utc": mid_t,
        },
    )
    assert ev.status_code == 200
    body = ev.json()
    for key in (
        "event_id", "t_utc", "source", "audio_ref",
        "transcript", "tag", "session_id",
    ):
        assert key in body
    assert body["source"] == "coach_voice"
    assert body["session_id"] == sid
    eid = body["event_id"]

    cmp_ = client.get(
        f"/api/sessions/{sid}/compare",
        params={"event_id": eid, "n": 2, "metric": "v_ms"},
        headers=h,
    )
    assert cmp_.status_code == 200
    data = cmp_.json()
    assert data["significance"]["calibrated"] is False
    assert "Mode D" in data["significance"]["message"]
    assert "threshold" not in data
    assert "threshold" not in data["significance"]


def test_pose_series_2x() -> None:
    client = TestClient(app)
    r = client.get(
        "/api/pose/series",
        params={"boat_class": "2x", "n": 5},
        headers={"X-DataR0w-Role": "product"},
    )
    assert r.status_code == 200
    frames = r.json()["frames"]
    assert len(frames) == 5
    assert "joints" in frames[0]
