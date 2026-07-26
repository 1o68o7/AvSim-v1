"""CLI minimale avsim — mode `run`.

Réutilise load_params / override / simulate. Aucune nouvelle logique de calcul
des grandeurs Phase 2 (§9.2) : elles viennent de Stroke.energy().
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

import numpy as np

from avsim.core.dynamics import Crew
from avsim.core.params import load_params, override
from avsim.core.solver import Result, simulate


# Six grandeurs Phase 2 / §9.2 déjà calculées dans Stroke.energy() — affichage seul.
PHASE2_KEYS = (
    "v_mean_ms",
    "P_rower_mean_W",
    "eta_blade",
    "check_factor",
    "v_min_ms",
    "v_max_ms",
)


def phase2_metrics(stroke) -> dict[str, float]:
    """Extrait les 6 grandeurs Phase 2 — pas de recalcul."""
    en = stroke.energy()
    return {k: float(en[k]) for k in PHASE2_KEYS}


def _parse_value(raw: str) -> Any:
    low = raw.lower()
    if low in ("true", "false"):
        return low == "true"
    try:
        if "." in raw or "e" in low:
            return float(raw)
        return int(raw)
    except ValueError:
        return raw


def _parse_params(items: list[str]) -> dict[str, Any]:
    """'section__nom=valeur' → kwargs pour params.override."""
    out: dict[str, Any] = {}
    for item in items:
        if "=" not in item:
            raise SystemExit(f"--param attend section__nom=valeur, reçu : {item!r}")
        key, _, raw = item.partition("=")
        if "__" not in key:
            raise SystemExit(
                f"--param clé invalide {key!r} (attendu section__nom, cf. override)"
            )
        out[key] = _parse_value(raw)
    return out


def build_params(
    boat_class: str,
    *,
    param_items: list[str] | None = None,
    n_strokes: int | None = None,
    n_discard: int | None = None,
) -> dict:
    P = load_params(boat_class=boat_class)
    kw = _parse_params(param_items or [])
    if kw:
        P = override(P, **kw)
    if n_strokes is not None:
        P["numerics"]["n_strokes"] = int(n_strokes)
    if n_discard is not None:
        P["numerics"]["n_discard"] = int(n_discard)
    return P


def _json_default(obj: Any) -> Any:
    if isinstance(obj, (np.floating, np.integer)):
        return obj.item()
    if isinstance(obj, np.ndarray):
        return obj.tolist()
    raise TypeError(f"non JSON-serialisable : {type(obj)}")


def save_result(path: Path, res: Result) -> None:
    """Persiste un Result pour `avsim replay` (séries + params JSON)."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    meta_path = path.with_suffix(path.suffix + ".meta.json")
    np.savez_compressed(
        path,
        t=np.asarray(res.t, dtype=float),
        y=np.asarray(res.y, dtype=float),
        modes=np.asarray(res._modes_along, dtype=int),
        n_keep=np.asarray(res.n_keep, dtype=int),
    )
    meta_path.write_text(
        json.dumps({"params": res.P}, indent=2, default=_json_default),
        encoding="utf-8",
    )


def load_result(path: Path) -> Result:
    path = Path(path)
    meta_path = path.with_suffix(path.suffix + ".meta.json")
    if not path.is_file() or not meta_path.is_file():
        raise FileNotFoundError(
            f"Result incomplet : besoin de {path} et {meta_path}"
        )
    data = np.load(path)
    P = json.loads(meta_path.read_text(encoding="utf-8"))["params"]
    crew = Crew(P)
    return Result(
        data["t"],
        data["y"],
        P,
        crew,
        int(data["n_keep"]),
        data["modes"],
    )


def format_phase2(metrics: dict[str, float], boat_class: str) -> str:
    lines = [
        f"source=simulated  class={boat_class}  (Phase 2 / §9.2)",
        "-" * 48,
    ]
    labels = {
        "v_mean_ms": "v_mean",
        "P_rower_mean_W": "P_rower",
        "eta_blade": "eta_blade",
        "check_factor": "check_factor",
        "v_min_ms": "v_min",
        "v_max_ms": "v_max",
    }
    units = {
        "v_mean_ms": "m/s",
        "P_rower_mean_W": "W",
        "eta_blade": "",
        "check_factor": "m/s",
        "v_min_ms": "m/s",
        "v_max_ms": "m/s",
    }
    for k in PHASE2_KEYS:
        u = units[k]
        lines.append(f"  {labels[k]:<14} {metrics[k]:10.4f}  {u}".rstrip())
    return "\n".join(lines)


def cmd_run(args: argparse.Namespace) -> int:
    P = build_params(
        args.boat_class,
        param_items=args.param,
        n_strokes=args.strokes,
        n_discard=args.discard,
    )
    res = simulate(P)
    st = res.last_stroke()
    metrics = phase2_metrics(st)
    print(format_phase2(metrics, args.boat_class))
    if args.out:
        save_result(Path(args.out), res)
        print(f"Result sauvegardé → {args.out}", file=sys.stderr)
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="avsim",
        description="CLI DataR0w — simulation (source=simulated).",
    )
    sub = p.add_subparsers(dest="command", required=True)

    run = sub.add_parser("run", help="Simuler et afficher les 6 grandeurs Phase 2")
    run.add_argument("--class", dest="boat_class", required=True, help="Classe bateau (ex. 8+, 2x)")
    run.add_argument(
        "--param",
        action="append",
        default=[],
        metavar="section__nom=valeur",
        help="Surcharge (répété) — même syntaxe que params.override",
    )
    run.add_argument("--strokes", type=int, default=None, help="numerics.n_strokes")
    run.add_argument("--discard", type=int, default=None, help="numerics.n_discard")
    run.add_argument(
        "--out",
        type=str,
        default=None,
        help="Chemin .npz pour sauvegarder le Result (replay)",
    )
    run.set_defaults(func=cmd_run)

    return p


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
