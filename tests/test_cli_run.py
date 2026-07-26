"""CLI `avsim run` — 6 grandeurs Phase 2, pas de recalcul."""

from __future__ import annotations

from pathlib import Path

from avsim.cli import (
    PHASE2_KEYS,
    build_params,
    format_phase2,
    load_result,
    main,
    phase2_metrics,
    save_result,
)
from avsim.core.params import load_params
from avsim.core.solver import simulate


def test_phase2_keys_match_energy() -> None:
    P = load_params(boat_class="1x")
    P["numerics"]["n_strokes"] = 3
    P["numerics"]["n_discard"] = 1
    st = simulate(P).last_stroke()
    en = st.energy()
    for k in PHASE2_KEYS:
        assert k in en
    m = phase2_metrics(st)
    assert list(m) == list(PHASE2_KEYS)
    assert all(isinstance(v, float) for v in m.values())


def test_build_params_override_and_strokes() -> None:
    P = build_params(
        "8+",
        param_items=["technique__F_peak_N=1100"],
        n_strokes=4,
        n_discard=1,
    )
    assert P["technique"]["F_peak_N"] == 1100
    assert P["numerics"]["n_strokes"] == 4
    assert P["numerics"]["n_discard"] == 1


def test_cli_run_prints_phase2(capsys, tmp_path: Path) -> None:
    out = tmp_path / "r.npz"
    rc = main([
        "run",
        "--class", "1x",
        "--strokes", "3",
        "--discard", "1",
        "--out", str(out),
    ])
    assert rc == 0
    text = capsys.readouterr().out
    assert "source=simulated" in text
    assert "v_mean" in text
    assert "eta_blade" in text
    assert out.is_file()
    res = load_result(out)
    assert res.n_keep == 2
    # round-trip metrics stables
    m = phase2_metrics(res.last_stroke())
    assert "v_mean_ms" in m
    assert format_phase2(m, "1x").startswith("source=simulated")
