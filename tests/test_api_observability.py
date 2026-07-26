"""API Mode C — Observabilité pilote 2x uniquement."""
from fastapi.testclient import TestClient

from avsim.api.app import app

PILOT_SNIPPET = "Pilote classe 2x uniquement"


def test_observability_analyst_ok():
    client = TestClient(app)
    r = client.get(
        "/api/analysis/observability",
        headers={"X-DataR0w-Role": "analyst"},
    )
    assert r.status_code == 200, r.text
    data = r.json()
    assert data["boat_class"] == "2x"
    assert data["n_truths"] == 200
    assert PILOT_SNIPPET in data["pilot_label"]
    assert len(data["greedy_path"]) >= 2
    assert len(data["pareto_cost_error"]) >= 2
    assert len(data["sensor_gains"]) >= 1
    # Premier point Pareto = ensemble vide
    assert data["pareto_cost_error"][0]["subset"] == []


def test_observability_product_forbidden():
    client = TestClient(app)
    r = client.get(
        "/api/analysis/observability",
        headers={"X-DataR0w-Role": "product"},
    )
    assert r.status_code == 403


def test_observability_requires_role():
    client = TestClient(app)
    assert client.get("/api/analysis/observability").status_code == 401
