"""Chargement des parametres geles.

Le YAML porte pour chaque parametre sa valeur, ses bornes et sa source.
Le noyau n'a besoin que des valeurs ; les bornes servent aux modes B/C/D.

Multi-classes : `load_class(code)` fusionne `defaults.yaml` avec
`params/classes/<code>.yaml`, resout `hull_ref` contre `data/hull_moulds.csv`
quand builder+mould sont renseignes, et dimensionne l'equipage sur `n_rowers`.
"""
from __future__ import annotations

import copy
import csv
from pathlib import Path
from typing import Any

import yaml

_ROOT = Path(__file__).resolve().parents[3]
DEFAULTS = _ROOT / "params" / "defaults.yaml"
CLASSES_DIR = _ROOT / "params" / "classes"
HULL_MOULDS = _ROOT / "data" / "hull_moulds.csv"

# Facteur L_wl / LOA des fichiers de classe (categorie N) — pas 0,97.
L_WL_OVER_LOA = 0.986


def _is_value_spec(node: Any) -> bool:
    return isinstance(node, dict) and "v" in node and set(node) <= {"v", "min", "max", "src"}


def _flatten(node: Any) -> Any:
    """Remplace {v: x, min: .., max: .., src: ..} par x, recursivement."""
    if isinstance(node, dict):
        if _is_value_spec(node):
            return node["v"]
        return {k: _flatten(v) for k, v in node.items()}
    return node


def _deep_merge(base: dict, overlay: dict) -> dict:
    """Fusion profonde : l'overlay gagne. Une feuille {v,...} est remplacee entiere."""
    out = copy.deepcopy(base)
    for key, val in overlay.items():
        if key not in out:
            out[key] = copy.deepcopy(val)
        elif _is_value_spec(out[key]) or _is_value_spec(val):
            out[key] = copy.deepcopy(val)
        elif isinstance(out[key], dict) and isinstance(val, dict):
            out[key] = _deep_merge(out[key], val)
        else:
            out[key] = copy.deepcopy(val)
    return out


def _load_yaml(path: Path) -> dict:
    raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(raw, dict):
        raise ValueError(f"YAML attendu objet a la racine : {path}")
    return raw


def _lookup_hull(builder: str, mould: str) -> dict[str, Any]:
    """Ligne de data/hull_moulds.csv pour (builder, mould), sinon KeyError."""
    with HULL_MOULDS.open(encoding="utf-8", newline="") as f:
        lines = [ln for ln in f if ln.strip() and not ln.lstrip().startswith("#")]
    for row in csv.DictReader(lines):
        if row["builder"] == builder and row["mould"] == mould:
            return {
                "builder": row["builder"],
                "mould": row["mould"],
                "boat_class": row["boat_class"],
                "loa_m": float(row["loa_m"]),
                "beam_wl_m": float(row["beam_wl_m"]),
                "rower_kg_min": float(row["rower_kg_min"]),
                "rower_kg_max": float(row["rower_kg_max"]),
            }
    raise KeyError(
        f"moule introuvable dans {HULL_MOULDS.name} : "
        f"builder={builder!r} mould={mould!r}"
    )


def _resolve_hull_ref(
    params: dict,
    *,
    hull_builder: str | None = None,
    hull_mould: str | None = None,
) -> None:
    """Remplace loa_m / L_wl_m si hull_ref (ou kwargs) pointe un moule nomme."""
    href = params.setdefault("hull_ref", {})
    builder = hull_builder if hull_builder is not None else href.get("builder")
    mould = hull_mould if hull_mould is not None else href.get("mould")
    if not builder or not mould:
        params["geometry_source"] = "composite"
        return

    row = _lookup_hull(str(builder), str(mould))
    boat = params.setdefault("boat", {})
    boat["loa_m"] = row["loa_m"]
    boat["L_wl_m"] = L_WL_OVER_LOA * row["loa_m"]
    boat["beam_wl_m"] = row["beam_wl_m"]
    href["builder"] = row["builder"]
    href["mould"] = row["mould"]
    params["geometry_source"] = "named_hull"


def _resize_crew(params: dict) -> None:
    """phase_offset_ms et mass_kg a la longueur n_rowers (jamais fige a 8)."""
    n = int(params["meta"]["n_rowers"])
    if n < 1:
        raise ValueError(f"n_rowers invalide : {n}")
    mass = float(params["rower"]["m_kg"])
    crew = params.setdefault("crew", {})
    crew["phase_offset_ms"] = [0.0] * n
    crew["mass_kg"] = [mass] * n


def _apply_cox(params: dict) -> None:
    """Sans barreur : m_cox_kg = 0 (sinon le defaut 55 kg du 8+ pollue les autres classes)."""
    if not params["meta"].get("coxed", False):
        params.setdefault("boat", {})["m_cox_kg"] = 0.0


def class_path(code: str) -> Path:
    path = CLASSES_DIR / f"{code}.yaml"
    if not path.is_file():
        available = sorted(p.stem for p in CLASSES_DIR.glob("*.yaml"))
        raise FileNotFoundError(
            f"classe inconnue {code!r} (fichier {path.name} absent). "
            f"Disponibles : {available}"
        )
    return path


def load_class(
    code: str,
    *,
    hull_builder: str | None = None,
    hull_mould: str | None = None,
) -> dict:
    """Fusionne defaults + classes/<code>.yaml, resout hull_ref, adapte l'equipage."""
    merged = _deep_merge(_load_yaml(DEFAULTS), _load_yaml(class_path(code)))
    params = _flatten(merged)
    params.setdefault("meta", {})["boat_class"] = code
    if "code" not in params["meta"]:
        params["meta"]["code"] = code
    _resolve_hull_ref(params, hull_builder=hull_builder, hull_mould=hull_mould)
    _apply_cox(params)
    _resize_crew(params)
    return params


def load_params(
    path: str | Path | None = None,
    boat_class: str | None = None,
    *,
    hull_builder: str | None = None,
    hull_mould: str | None = None,
) -> dict:
    """Charge defaults seuls (chemin historique) ou une classe via `boat_class`."""
    if boat_class is not None:
        if path is not None:
            raise TypeError("load_params: ne pas combiner path= et boat_class=")
        return load_class(
            boat_class, hull_builder=hull_builder, hull_mould=hull_mould
        )
    if hull_builder is not None or hull_mould is not None:
        raise TypeError(
            "load_params: hull_builder/hull_mould exigent boat_class=..."
        )
    raw = _load_yaml(Path(path or DEFAULTS))
    return _flatten(raw)


def load_bounds(path: str | Path | None = None) -> dict[str, tuple[float, float]]:
    """Bornes plates 'section.param' -> (min, max), pour Sobol et observabilite."""
    raw = _load_yaml(Path(path or DEFAULTS))
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
