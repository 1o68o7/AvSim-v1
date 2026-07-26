"""Séparation Analyste / Produit au niveau API (brief UI §1)."""
from __future__ import annotations

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


def require_analyst(role: Role = None) -> Role:
    # used as Depends wrapper below
    raise NotImplementedError


def analyst_only(role: Role) -> None:
    if role is not Role.analyst:
        raise HTTPException(
            status_code=403,
            detail="Route réservée à la surface Analyste",
        )
