"""Lot G — /datarow/* : pas de X-DataR0w-Role ; clé téléphone optionnelle."""
from __future__ import annotations

import json
import os

from fastapi.testclient import TestClient

from avsim.api.app import app
from avsim.api.datarow import reset_store


def test_datarow_session_tick_live_notes_export_no_oauth():
    reset_store()
    os.environ.pop("DATAROW_API_KEY", None)
    c = TestClient(app)
    r = c.post("/datarow/sessions", json={"id": "s1", "code": "K7P2QM"})
    assert r.status_code == 200
    assert r.json() == {"id": "s1", "code": "K7P2QM"}

    sample = {
        "t": 1,
        "lat": 48.86,
        "lon": 2.35,
        "sog": 3.2,
        "dist_m": 12.0,
        "gite_deg": 0.4,
        "cadence_spm": None,
        "net": "wifi",
    }
    t = c.post("/datarow/sessions/s1/tick", content=json.dumps(sample))
    assert t.status_code == 200

    by = c.get("/datarow/sessions/by-code/k7p2qm")
    assert by.status_code == 200
    assert by.json()["id"] == "s1"

    live = c.get("/datarow/sessions/s1/live")
    assert live.status_code == 200
    body = live.json()
    assert body["sample"]["sog"] == 3.2
    assert body["code"] == "K7P2QM"

    n = c.post("/datarow/sessions/s1/notes", json={"t": 2, "text": "depart"})
    assert n.status_code == 200

    exp = c.get("/datarow/sessions/s1/export")
    assert exp.status_code == 200
    ej = exp.json()
    assert "jsonl" in ej
    assert ej["meta"]["notes"][0]["t"] == 2

    # pas de rôle Analyste requis (contrairement à /api/classes)
    assert c.get("/api/classes").status_code == 401
    assert c.get("/datarow/sessions/by-code/NOPE").status_code == 404


def test_datarow_requires_phone_key_when_configured(monkeypatch):
    reset_store()
    monkeypatch.setenv("DATAROW_API_KEY", "secret-phone")
    c = TestClient(app)
    assert c.post("/datarow/sessions", json={"id": "s2", "code": "AB12CD"}).status_code == 401
    ok = c.post(
        "/datarow/sessions",
        json={"id": "s2", "code": "AB12CD"},
        headers={"X-DataR0w-Phone-Key": "secret-phone"},
    )
    assert ok.status_code == 200
    monkeypatch.delenv("DATAROW_API_KEY", raising=False)


def test_datarow_session_expires_12h():
    reset_store()
    os.environ.pop("DATAROW_API_KEY", None)
    from datetime import timedelta

    from avsim.api import datarow as d

    c = TestClient(app)
    assert c.post("/datarow/sessions", json={"id": "old", "code": "OLD123"}).status_code == 200
    d._SESSIONS["old"].created_at -= timedelta(hours=13)
    assert c.get("/datarow/sessions/by-code/OLD123").status_code == 404
