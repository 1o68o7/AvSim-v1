"""Sessions / events / compare — Coach live & replay (2x)."""

from __future__ import annotations

import copy
import json
from datetime import datetime, timedelta, timezone

from fastapi.testclient import TestClient

from avsim.api.app import app
from avsim.core.params import load_class
from avsim.core.solver import simulate
from avsim.io.events import STORE, StrokeMark
from avsim.io.replay import stroke_frame


def _parse_sse(body: str) -> list[dict]:
    frames = []
    for block in body.strip().split("\n\n"):
        for line in block.splitlines():
            if line.startswith("data: "):
                frames.append(json.loads(line[6:]))
    return frames


def _marks_from_run(
    rate_spm: float,
    *,
    n_keep: int = 3,
    boat_class: str = "2x",
) -> list[dict]:
    """Derniers coups gardés d'un run 2x à cadence imposée (technique.rate_spm)."""
    P = copy.deepcopy(load_class(boat_class))
    P["numerics"]["n_strokes"] = n_keep + 2
    P["numerics"]["n_discard"] = 2
    P["technique"]["rate_spm"] = float(rate_spm)
    res = simulate(P)
    assert res.n_keep >= n_keep
    out: list[dict] = []
    for i in range(res.n_keep - n_keep, res.n_keep):
        fr = stroke_frame(
            res.stroke(i),
            boat_class=boat_class,
            stroke_index=i,
            params=P,
        )
        out.append(fr)
    return out


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

    for metric in ("arc_deg", "cadence_spm", "phase_lag_ms"):
        cmp_ = client.get(
            f"/api/sessions/{sid}/compare",
            params={"event_id": eid, "n": 2, "metric": metric},
            headers=h,
        )
        assert cmp_.status_code == 200, metric
        data = cmp_.json()
        assert data["metric"] == metric
        assert data["before"]["values"], metric
        assert data["after"]["values"], metric
        assert data["delta"] is not None, metric
        assert data["significance"]["calibrated"] is False
        assert "Mode D" in data["significance"]["message"]
        assert "threshold" not in data
        assert "threshold" not in data["significance"]
    # Marks portent arc + décalage ; timestamps distincts (jointure)
    sess = client.get(f"/api/sessions/{sid}", headers=h).json()
    assert sess["strokes"][0]["arc_deg"] > 0
    assert "phase_lag_ms" in sess["strokes"][0]
    stamps = [m["t_utc"] for m in sess["strokes"]]
    assert len(set(stamps)) == len(stamps)


def test_compare_detects_injected_cadence_delta_two_runs() -> None:
    """Δ cadence non nul et du bon signe — deux runs distincts (rate_spm).

    Avant = run technique.rate_spm=32 ; après = 40. Pas deux moitiés d'une
    même session stationnaire. Prouve que compare mesure une vraie variation.
    """
    client = TestClient(app)
    h = {"X-DataR0w-Role": "product"}
    n = 3
    rate_lo, rate_hi = 32.0, 40.0
    before_fr = _marks_from_run(rate_lo, n_keep=n)
    after_fr = _marks_from_run(rate_hi, n_keep=n)
    assert all(abs(f["cadence_spm"] - rate_lo) < 0.5 for f in before_fr)
    assert all(abs(f["cadence_spm"] - rate_hi) < 0.5 for f in after_fr)

    sid = client.post("/api/sessions", headers=h, json={"boat_class": "2x"}).json()[
        "session_id"
    ]
    t0 = datetime.now(timezone.utc).replace(microsecond=0)
    # Indices : 0..n-1 avant | n pivot (exclu du Δ) | n+1..2n après
    seq: list[tuple[int, dict]] = []
    for i, fr in enumerate(before_fr):
        seq.append((i, fr))
    pivot_fr = dict(before_fr[-1])
    pivot_fr["cadence_spm"] = 0.5 * (rate_lo + rate_hi)
    seq.append((n, pivot_fr))
    for j, fr in enumerate(after_fr):
        seq.append((n + 1 + j, fr))

    for stroke_index, fr in seq:
        STORE.add_stroke_mark(
            sid,
            StrokeMark(
                stroke_index=stroke_index,
                t_utc=(t0 + timedelta(seconds=2 * stroke_index)).isoformat(),
                cadence_spm=float(fr["cadence_spm"]),
                v_ms=float(fr["v_ms"]),
                check_factor=float(fr["check_factor"]),
                arc_deg=float(fr["arc_deg"]),
                phase_lag_ms=float(fr["phase_lag_ms"]),
                energy=dict(fr["energy"]),
            ),
        )

    pivot_t = (t0 + timedelta(seconds=2 * n)).isoformat()
    eid = client.post(
        f"/api/sessions/{sid}/events",
        headers=h,
        json={
            "source": "coach_voice",
            "tag": "cadence",
            "transcript": "monte la cadence",
            "t_utc": pivot_t,
        },
    ).json()["event_id"]

    cmp_ = client.get(
        f"/api/sessions/{sid}/compare",
        params={"event_id": eid, "n": n, "metric": "cadence_spm"},
        headers=h,
    )
    assert cmp_.status_code == 200
    data = cmp_.json()
    assert data["nearest_stroke_index"] == n
    assert data["before"]["stroke_indices"] == list(range(0, n))
    assert data["after"]["stroke_indices"] == list(range(n + 1, 2 * n + 1))
    assert data["before"]["mean"] is not None
    assert data["after"]["mean"] is not None
    assert data["delta"] is not None
    # Variation réelle : après > avant, Δ ≈ +8 spm
    assert data["delta"] > 0, data
    assert data["delta"] > 5.0, data
    assert abs(data["delta"] - (rate_hi - rate_lo)) < 1.0, data
    assert data["significance"]["calibrated"] is False
    assert "Mode D" in data["significance"]["message"]
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
