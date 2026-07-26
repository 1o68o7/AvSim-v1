"""Fixtures partagees — toute validation tourne sur des classes reelles.

`load_params()` sans `boat_class` ne lit que `defaults.yaml` (I_oar=1,30).
Les YAML de classe portent les vraies valeurs (8+ : I_oar=6,16 ; 1x : 1,82).
"""
from __future__ import annotations

import pytest

from avsim.core.params import load_params
from avsim.core.solver import simulate

BOAT_CLASSES = ("8+", "1x")


@pytest.fixture(autouse=True)
def _isolated_events_db(tmp_path, monkeypatch):
    """Chaque test a sa propre SQLite — pas de fuite via le STORE global."""
    db = tmp_path / "test_events.sqlite"
    monkeypatch.setenv("AVSIM_EVENTS_DB", str(db))
    from avsim.io.events import STORE

    STORE.reopen(db)
    yield


@pytest.fixture(scope="module", params=BOAT_CLASSES)
def boat_class(request):
    return request.param


@pytest.fixture(scope="module")
def P(boat_class):
    return load_params(boat_class=boat_class)


@pytest.fixture(scope="module")
def res(P):
    return simulate(P)
