"""Catalogue UI : classes, moules, params annotés (src L/E/N).

Sert l'API Analyste — ne change pas le moteur physique.
"""
from __future__ import annotations

import csv
from typing import Any

from .params import (
    CLASSES_DIR,
    DEFAULTS,
    HULL_MOULDS,
    _deep_merge,
    _is_value_spec,
    _load_yaml,
    class_path,
    load_class,
)

# Brief UI §0 — statut de validation par classe.
VALIDATED_CLASSES = frozenset({"8+", "1x"})
SMOKE_ONLY_CLASSES = frozenset({"2x", "2-", "4x", "4-", "4+", "8x"})

V_REF_MS = {
    "1x": 5.12,
    "2-": 5.47,
    "2x": 5.56,
    "4-": 5.92,
    "4x": 6.02,
    "4+": 5.57,
    "8+": 6.28,
    "8x": 6.35,
}

# Cibles §9.2 (plausibilité) — bornes utilisées par la Vue Bilan.
TARGETS_9_2 = {
    "v_mean_rel": 0.08,  # ±8 % de v_ref
    "P_rower_W": (420.0, 540.0),
    "eta_blade": (0.75, 0.85),
    "check_factor": (0.50, 0.80),  # 8+ ; élargi pour 1x côté UI
    "slip_ms": (0.4, 1.4),
}


def class_validation_status(code: str) -> dict[str, str]:
    if code in VALIDATED_CLASSES:
        return {
            "code": code,
            "status": "validated",
            "label": "Validée",
            "detail": "Suite pytest complète, fixtures dédiées",
        }
    if code in SMOKE_ONLY_CLASSES:
        return {
            "code": code,
            "status": "beta",
            "label": "Bêta — non calibrée",
            "detail": "Test de fumée seulement ; test_class_scaling.py absent",
        }
    return {
        "code": code,
        "status": "unknown",
        "label": "Inconnue",
        "detail": "Classe non répertoriée",
    }


def list_classes() -> list[dict[str, Any]]:
    codes = sorted(
        (p.stem for p in CLASSES_DIR.glob("*.yaml")),
        key=lambda c: (len(c), c),
    )
    out = []
    for code in codes:
        st = class_validation_status(code)
        raw = _load_yaml(class_path(code))
        meta = raw.get("meta", {})
        # meta may be flat values or specs
        def _v(m, k, default=None):
            node = m.get(k, default)
            if isinstance(node, dict) and "v" in node:
                return node["v"]
            return node

        out.append({
            **st,
            "n_rowers": int(_v(meta, "n_rowers", 0) or 0),
            "sculling": bool(_v(meta, "sculling", False)),
            "coxed": bool(_v(meta, "coxed", False)),
            "v_ref_ms": V_REF_MS.get(code),
        })
    return out


def list_hull_moulds(boat_class: str | None = None) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    with HULL_MOULDS.open(encoding="utf-8", newline="") as f:
        lines = [ln for ln in f if ln.strip() and not ln.lstrip().startswith("#")]
    for row in csv.DictReader(lines):
        if boat_class and row["boat_class"] != boat_class:
            continue
        rows.append({
            "builder": row["builder"],
            "mould": row["mould"],
            "boat_class": row["boat_class"],
            "loa_m": float(row["loa_m"]) if row.get("loa_m") else None,
            "beam_wl_m": float(row["beam_wl_m"]) if row.get("beam_wl_m") else None,
        })
    return rows


def _annotate_tree(node: Any) -> Any:
    """Conserve v/min/max/src pour l'UI ; marque 'non sourcé' si src absent."""
    if isinstance(node, dict):
        if _is_value_spec(node):
            src = node.get("src")
            return {
                "v": node["v"],
                "min": node.get("min"),
                "max": node.get("max"),
                "src": src if src in ("L", "E", "N") else None,
                "sourced": src in ("L", "E", "N"),
            }
        return {k: _annotate_tree(v) for k, v in node.items()}
    return node


def load_class_annotated(
    code: str,
    *,
    hull_builder: str | None = None,
    hull_mould: str | None = None,
) -> dict[str, Any]:
    """Arbre YAML fusionné avec métadonnées src, plus valeurs plates runtime."""
    merged = _deep_merge(_load_yaml(DEFAULTS), _load_yaml(class_path(code)))
    annotated = _annotate_tree(merged)
    flat = load_class(code, hull_builder=hull_builder, hull_mould=hull_mould)
    return {
        "boat_class": code,
        "validation": class_validation_status(code),
        "geometry_source": flat.get("geometry_source", "composite"),
        "values": flat,
        "annotated": annotated,
    }
