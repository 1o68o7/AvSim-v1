"""CLI `avsim replay --realtime` — flux coup à cadence T."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from avsim.cli import main, save_result
from avsim.core.params import load_params
from avsim.core.solver import simulate


def test_replay_requires_realtime() -> None:
    with pytest.raises(SystemExit, match="realtime"):
        main(["replay", "--class", "1x", "--strokes", "2", "--discard", "1"])


def test_replay_realtime_sleeps_T(tmp_path: Path, monkeypatch, capsys) -> None:
    P = load_params(boat_class="1x")
    P["numerics"]["n_strokes"] = 3
    P["numerics"]["n_discard"] = 1
    res = simulate(P)
    out = tmp_path / "r.npz"
    save_result(out, res)

    sleeps: list[float] = []

    def fake_sleep(dt: float) -> None:
        sleeps.append(dt)

    monkeypatch.setattr("avsim.io.replay.time.sleep", fake_sleep)

    rc = main(["replay", "--realtime", "--result", str(out)])
    assert rc == 0
    lines = [ln for ln in capsys.readouterr().out.strip().splitlines() if ln]
    assert len(lines) == res.n_keep == 2
    frames = [json.loads(ln) for ln in lines]
    assert all(f["source"] == "simulated" for f in frames)
    assert all(f["kind"] == "stroke" for f in frames)
    assert [f["stroke_index"] for f in frames] == [0, 1]
    assert len(sleeps) == res.n_keep
    for f, dt in zip(frames, sleeps):
        assert 0 < dt <= f["T_s"]
        assert "v_mean_ms" in f["energy"]
        assert "V_ms" in f["series"]
        assert "cadence_spm" in f
        assert "distance_m" in f
