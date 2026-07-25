"""Chargement des parametres geles.

Le YAML porte pour chaque parametre sa valeur, ses bornes et sa source.
Le noyau n'a besoin que des valeurs ; les bornes servent aux modes B/C/D.
"""
from __future__ import annotations

import copy
from pathlib import Path
from typing import Any

import yaml

_ROOT = Path(__file__).resolve().parents[3]
DEFAULTS = _ROOT / "params" / "defaults.yaml"


def _flatten(node: Any) -> Any:
    """Remplace {v: x, min: .., max: .., src: ..} par x, recursivement."""
    if isinstance(node, dict):
        if "v" in node and set(node) <= {"v", "min", "max", "src"}:
            return node["v"]
        return {k: _flatten(v) for k, v in node.items()}
    return node


def load_params(path: str | Path | None = None) -> dict:
    raw = yaml.safe_load(Path(path or DEFAULTS).read_text(encoding="utf-8"))
    return _flatten(raw)


def load_bounds(path: str | Path | None = None) -> dict[str, tuple[float, float]]:
    """Bornes plates 'section.param' -> (min, max), pour Sobol et observabilite."""
    raw = yaml.safe_load(Path(path or DEFAULTS).read_text(encoding="utf-8"))
    out: dict[str, tuple[float, float]] = {}
    for section, block in raw.items():
        if not isinstance(block, dict):
            continue
        for name, spec in block.items():
            if isinstance(spec, dict) and "min" in spec and "max" in spec:
                lo, hi = spec["min"], spec["max"]
                if isinstance(lo, (int, float)) and isinstance(hi, (int, float)):
                    out[f"{section}.{name}"] = (float(lo), float(hi))
    return out


def override(params: dict, **kw: Any) -> dict:
    """Copie profonde avec surcharges 'section.param=valeur'."""
    p = copy.deepcopy(params)
    for key, val in kw.items():
        section, _, name = key.partition("__")
        p[section][name] = val
    return p
