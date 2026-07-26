#!/usr/bin/env python3
"""Génère data/observability_2x_pilot.json — Mode C pilote 2x (200 vérités)."""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from avsim.analysis.observability import (  # noqa: E402
    DEFAULT_RESULTS_PATH,
    PILOT_LABEL,
    run_mode_c_2x,
    save_results,
)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=200)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument(
        "--out", type=Path, default=ROOT / DEFAULT_RESULTS_PATH,
    )
    args = ap.parse_args()
    print(PILOT_LABEL, flush=True)
    print(f"Mode C 2x : n_truths={args.n} workers={args.workers}", flush=True)
    result = run_mode_c_2x(
        n_truths=args.n, seed=args.seed, max_workers=args.workers,
    )
    path = save_results(result, args.out)
    print(
        f"OK → {path}  elapsed={result['elapsed_s']:.1f}s  "
        f"pareto={len(result['pareto_cost_error'])} pts  "
        f"gains={len(result['sensor_gains'])}",
        flush=True,
    )


if __name__ == "__main__":
    main()
