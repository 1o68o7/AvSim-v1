"""SSE `/api/replay/stream` — même grain que `avsim replay --realtime`."""

from __future__ import annotations

import json

from fastapi.testclient import TestClient

from avsim.api.app import app


def _parse_sse(body: str) -> list[dict]:
    frames = []
    for block in body.strip().split("\n\n"):
        for line in block.splitlines():
            if line.startswith("data: "):
                frames.append(json.loads(line[6:]))
    return frames


def test_replay_stream_2x_not_realtime() -> None:
    client = TestClient(app)
    r = client.get(
        "/api/replay/stream",
        params={
            "boat_class": "2x",
            "n_strokes": 4,
            "n_discard": 2,
            "realtime": False,
        },
        headers={"X-DataR0w-Role": "product"},
    )
    assert r.status_code == 200
    assert "text/event-stream" in r.headers["content-type"]
    frames = _parse_sse(r.text)
    assert frames[0]["kind"] == "session"
    assert frames[0]["source"] == "simulated"
    assert frames[0]["boat_class"] == "2x"
    strokes = [f for f in frames if f["kind"] == "stroke"]
    assert len(strokes) == 2  # n_keep = 4-2
    assert all(s["source"] == "simulated" for s in strokes)
    assert strokes[0]["stroke_index"] == 0
    assert strokes[0]["cadence_spm"] > 0
    assert strokes[0]["v_ms"] > 0
    assert strokes[-1]["distance_m"] >= strokes[0]["distance_m"]
    assert frames[-1]["kind"] == "end"


def test_replay_stream_requires_role() -> None:
    client = TestClient(app)
    assert client.get("/api/replay/stream").status_code == 401
