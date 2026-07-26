"""Vue Rameur §3.1 — force, phase vs nage, haptic_alert, progression (2x)."""

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


def test_events_source_accepts_haptic_alert() -> None:
    client = TestClient(app)
    h = {"X-DataR0w-Role": "product"}
    sid = client.post("/api/sessions", headers=h, json={"boat_class": "2x"}).json()[
        "session_id"
    ]
    ev = client.post(
        f"/api/sessions/{sid}/events",
        headers=h,
        json={"source": "haptic_alert", "tag": "timing", "transcript": "buzz"},
    )
    assert ev.status_code == 200
    body = ev.json()
    assert body["source"] == "haptic_alert"
    for key in (
        "event_id", "t_utc", "source", "audio_ref",
        "transcript", "tag", "session_id",
    ):
        assert key in body


def test_rameur_review_force_history_and_phase_2x() -> None:
    client = TestClient(app)
    h = {"X-DataR0w-Role": "product"}
    r = client.get(
        "/api/rameur/review",
        params={"boat_class": "2x", "seat": 2, "n_prev": 10},
        headers=h,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["source"] == "simulated"
    assert data["boat"]["n_rowers"] == 2
    assert data["seat"] == 2
    assert data["stroke_seat"] == 1
    assert len(data["strokes"]) == 11  # dernier + 10
    last = data["strokes"][-1]
    assert len(last["t_s"]) == len(last["handle_force_N"]) > 10
    assert last["F_peak_N"] > 0
    assert "phase_lag_ms_vs_stroke" in last
    assert data["power_calibration"]["status"] == "indice"
    assert "D3" in data["power_calibration"]["message"]
    # Poste 1 (nage) : décalage vs soi-même ≈ 0
    r1 = client.get(
        "/api/rameur/review",
        params={"boat_class": "2x", "seat": 1, "n_prev": 3},
        headers=h,
    ).json()
    assert abs(r1["last_phase_lag_ms"]) < 1e-6


def test_rameur_haptic_overlay_and_progression_multi_session() -> None:
    client = TestClient(app)
    h = {"X-DataR0w-Role": "product"}

    def _fill(sid: str, n_strokes: int = 8) -> None:
        stream = client.get(
            "/api/replay/stream",
            params={
                "boat_class": "2x",
                "n_strokes": n_strokes,
                "n_discard": 2,
                "realtime": False,
                "session_id": sid,
            },
            headers=h,
        )
        assert stream.status_code == 200
        assert any(f["kind"] == "stroke" for f in _parse_sse(stream.text))

    s1 = client.post("/api/sessions", headers=h, json={"boat_class": "2x"}).json()[
        "session_id"
    ]
    s2 = client.post("/api/sessions", headers=h, json={"boat_class": "2x"}).json()[
        "session_id"
    ]
    _fill(s1)
    _fill(s2)

    # Injecter un écart de puissance sur s2 pour une tendance non plate
    sess2 = STORE.get(s2)
    assert sess2 is not None
    for m in sess2.strokes:
        en = dict(m.energy)
        en["P_rower_mean_W"] = float(en.get("P_rower_mean_W", 200.0)) + 40.0
        m.energy = en

    mid_t = STORE.get(s1).strokes[len(STORE.get(s1).strokes) // 2].t_utc
    ev = client.post(
        f"/api/sessions/{s1}/events",
        headers=h,
        json={"source": "haptic_alert", "tag": "timing", "t_utc": mid_t},
    ).json()
    assert ev["source"] == "haptic_alert"

    rev = client.get(
        "/api/rameur/review",
        params={
            "boat_class": "2x",
            "seat": 1,
            "n_prev": 5,
            "session_id": s1,
        },
        headers=h,
    ).json()
    assert len(rev["haptic_events"]) >= 1
    assert rev["haptic_events"][0]["source"] == "haptic_alert"
    assert rev["haptic_events"][0]["nearest_stroke_index"] is not None

    prog = client.get(
        "/api/rameur/progression",
        params={"boat_class": "2x"},
        headers=h,
    ).json()
    assert prog["metric_badge"] == "indice"
    assert len(prog["points"]) >= 2
    assert prog["trend"] is not None
    assert prog["trend"]["n_sessions"] >= 2
    assert prog["trend"]["delta_W"] > 0
    assert prog["trend"]["direction"] == "up"
