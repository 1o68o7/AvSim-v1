"""Smoke API / catalogue — Phase 7 (pas de physique lourde)."""
from avsim.core.catalog import list_classes, class_validation_status


def test_eight_classes_listed():
    codes = {c["code"] for c in list_classes()}
    assert codes == {"1x", "2x", "2-", "4x", "4-", "4+", "8x", "8+"}


def test_validation_badges():
    assert class_validation_status("8+")["status"] == "validated"
    assert class_validation_status("1x")["status"] == "validated"
    assert class_validation_status("4+")["status"] == "beta"


def test_api_roles_and_classes():
    from fastapi.testclient import TestClient
    from avsim.api.app import app

    client = TestClient(app)
    assert client.get("/api/classes").status_code == 401
    r = client.get("/api/classes", headers={"X-DataR0w-Role": "analyst"})
    assert r.status_code == 200
    assert len(r.json()["classes"]) == 8
    # Produit ne lit pas /params
    denied = client.get(
        "/api/params/8+", headers={"X-DataR0w-Role": "product"}
    )
    assert denied.status_code == 403
