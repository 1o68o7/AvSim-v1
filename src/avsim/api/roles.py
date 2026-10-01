"""Séparation Analyste / Produit au niveau API (brief UI §1).

Le rôle est passé via l'en-tête X-DataR0w-Role : convention d'interface pour
usage interne, pas une authentification forte. Avant toute exposition publique
durable, remplacer par une vraie auth (et resserrer CORS côté app.py).

Routes téléphone `/datarow/*` : si `DATAROW_API_KEY` est défini, exiger
`X-DataR0w-Phone-Key` (sinon 401). Sans clé env = mode dev/tests ouvert.
"""
from __future__ import annotations

import os
from enum import Enum

from fastapi import Header, HTTPException


class Role(str, Enum):
    analyst = "analyst"
    product = "product"


ANALYST_ONLY = frozenset({
    "/api/jobs/sweep",
    "/api/params",
})


def require_role(
    x_datarow_role: str | None = Header(default=None, alias="X-DataR0w-Role"),
) -> Role:
    if x_datarow_role is None:
        raise HTTPException(
            status_code=401,
            detail="En-tête X-DataR0w-Role requis (analyst|product)",
        )
    try:
        return Role(x_datarow_role)
    except ValueError as exc:
        raise HTTPException(
            status_code=400,
            detail="Rôle invalide : attendu analyst|product",
        ) from exc


def require_phone_key(
    x_datarow_phone_key: str | None = Header(
        default=None, alias="X-DataR0w-Phone-Key"
    ),
) -> None:
    """Garde `/datarow/*` quand DATAROW_API_KEY est configurée."""
    expected = (os.environ.get("DATAROW_API_KEY") or "").strip()
    if not expected:
        return
    if (x_datarow_phone_key or "").strip() != expected:
        raise HTTPException(
            status_code=401,
            detail="En-tête X-DataR0w-Phone-Key requis ou invalide",
        )


def require_analyst(role: Role = None) -> Role:
    # used as Depends wrapper below
    raise NotImplementedError


def analyst_only(role: Role) -> None:
    if role is not Role.analyst:
        raise HTTPException(
            status_code=403,
            detail="Route réservée à la surface Analyste",
        )
