"""Classes de bateau (§2.1) et loi d'échelle §2.4 (calibrée sur le 8+).

`BoatClass` enveloppe `load_class` — pas de duplication du chargeur.
`scale_from_8plus` sert aux tests de cohérence (§9.3) ; les YAML restent
la source frozen pour la simulation. Ne lit jamais les 7 autres classes.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from .params import load_class

# Référence §2.4 — M_tot du 8+ (coque 96 + 8×88 + barreur 55).
M_TOT_8PLUS_KG = 855.0
K_DRAG_8PLUS = 13.00
S_WET_8PLUS_M2 = 11.50
CDA_8PLUS_M2 = 2.00


def scale_from_8plus(M_tot: float) -> dict[str, float]:
    """Dérive k_drag, S_wet, CdA de M_tot seul — calé uniquement sur le 8+.

    Ne lit aucun YAML de classe autre que la constante de référence 8+.
    CdA : incertitude forte (brief §2.4 avertissement).
    """
    if M_tot <= 0:
        raise ValueError(f"M_tot doit être > 0, reçu {M_tot}")
    factor = (M_tot / M_TOT_8PLUS_KG) ** (2.0 / 3.0)
    return {
        "k_drag": K_DRAG_8PLUS * factor,
        "S_wet_m2": S_WET_8PLUS_M2 * factor,
        "CdA_m2": CDA_8PLUS_M2 * factor,
    }


def total_mass_kg(params: dict[str, Any]) -> float:
    """M_tot = m_coque + Σ m_rameurs + m_barreur (après load_class / _apply_cox)."""
    boat = params["boat"]
    return (
        float(boat["m_hull_kg"])
        + float(sum(params["crew"]["mass_kg"]))
        + float(boat.get("m_cox_kg") or 0.0)
    )


def _rig_pattern(meta: dict[str, Any], n_rowers: int) -> tuple[int, ...]:
    """Pointe : +1 tribord / -1 bâbord par poste. Couple : tuple vide."""
    raw = meta.get("rig_pattern")
    if raw is not None and raw != ():
        if isinstance(raw, str):
            return ()
        return tuple(int(x) for x in raw)
    if meta.get("sculling"):
        return ()
    # Motif alterné par défaut (brief §2.1) si absent du YAML
    return tuple(1 if i % 2 == 0 else -1 for i in range(n_rowers))


@dataclass(frozen=True)
class BoatClass:
    """Abstraction brief §2.1 — dimensionnement sur n_rowers, jamais un 8 figé."""

    code: str
    n_rowers: int
    sculling: bool
    coxed: bool
    rig_pattern: tuple[int, ...]
    M_tot: float
    k_drag: float
    S_wet_m2: float
    CdA_m2: float

    @property
    def rig_label(self) -> str:
        """Libellé court pour l'UI / messages d'enveloppe."""
        if self.sculling:
            return "couple"
        return "pointe alternee"

    @classmethod
    def from_params(cls, params: dict[str, Any]) -> BoatClass:
        """Construit depuis un dict déjà fusionné par `load_class` / `load_params`."""
        meta = params["meta"]
        code = str(meta.get("boat_class") or meta.get("code"))
        n = int(meta["n_rowers"])
        boat = params["boat"]
        return cls(
            code=code,
            n_rowers=n,
            sculling=bool(meta.get("sculling", False)),
            coxed=bool(meta.get("coxed", False)),
            rig_pattern=_rig_pattern(meta, n),
            M_tot=total_mass_kg(params),
            k_drag=float(boat["k_drag"]),
            S_wet_m2=float(boat["S_wet_m2"]),
            CdA_m2=float(boat["CdA_m2"]),
        )

    @classmethod
    def from_code(cls, code: str, **load_kw: Any) -> BoatClass:
        return cls.from_params(load_class(code, **load_kw))


def boat_class_from_params(params: dict[str, Any]) -> BoatClass:
    """Alias Phase 1 — même objet que `BoatClass.from_params`."""
    return BoatClass.from_params(params)
