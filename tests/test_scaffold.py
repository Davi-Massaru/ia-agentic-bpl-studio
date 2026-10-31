"""Run using PYTHONPATH=backend pytest -q; no IRIS instance is required."""
from studio import create_app


def test_ui_pages_and_health():
    c = create_app({"TESTING": True}).test_client()
    for path in ["/", "/designer", "/test-trace", "/publisher"]:
        assert c.get(path).status_code == 200
    data = c.get("/health").get_json()
    assert data["state"] == "scaffold-only"
    assert data["irisConnected"] is False


def test_all_unconnected_mutations_fail_explicitly():
    c = create_app({"TESTING": True}).test_client()
    for path, method in [
        ("/api/v1/workflows/x/publish", "post"),
        ("/api/v1/workflows/x/validate", "post"),
        ("/api/v1/test-runs", "post"),
        ("/api/v1/bindings/b", "put")
    ]:
        response = getattr(c, method)(path, json={})
        assert response.status_code == 501
        assert response.get_json()["status"] == "NOT_IMPLEMENTED"
