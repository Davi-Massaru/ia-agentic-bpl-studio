"""HTTP boundary tests use a fake port, not simulated IRIS integration evidence."""
import pytest
from studio import create_app
from studio.services.gateway import GatewayError


class Gateway:
    def __init__(self):
        self.calls = []
        self.result = {"compiled": True, "published": True, "releaseId": "release-1"}

    def detect_capabilities(self, *, principal):
        return {"principal": principal, "irisConnected": False, "testDouble": True}

    def list_workflows(self, production, *, principal):
        self.calls.append((production, principal))
        return []

    def publish_workflow(self, workflow_id, base_hash, revision, approval_ref, **kwargs):
        self.calls.append((workflow_id, base_hash, revision, approval_ref, kwargs))
        if base_hash != "current":
            raise GatewayError("BPL_SOURCE_CONFLICT", "Source changed.", 409)
        return self.result

    def save_binding(self, binding_id, payload, expected_revision, *, principal):
        self.calls.append((binding_id, expected_revision, principal))
        return {"revision": expected_revision + 1}

    def submit_test_message(self, release_id, payload, *, principal):
        self.calls.append((release_id, payload, principal))
        return "execution-1"

    def get_run(self, execution_id, *, principal):
        raise RuntimeError("secret-provider-token")

    def save_agent_revision(self, agent_id, definition, base_revision, *, principal):
        self.calls.append((agent_id, definition, base_revision, principal))
        return {"revision": base_revision + 1}


@pytest.fixture
def setup():
    gateway = Gateway()
    app = create_app({"TESTING": True, "IRIS_GATEWAY": gateway,
                      "STUDIO_AUTHENTICATE": lambda req: "operator",
                      "STUDIO_AUTHORIZE": lambda principal, action: True,
                      "STUDIO_CSRF_VALIDATE": lambda req, principal: req.headers.get("X-CSRF-Token") == "test-token"})
    return app, app.test_client(), gateway


HEADERS = {"X-CSRF-Token": "test-token", "If-Match": '"current"', "Idempotency-Key": "publication-1"}
PUBLISH = {"draftRevision": 1, "approvalRef": "approved-1", "confirmed": True}


@pytest.mark.parametrize('operation,payload,method_name,expected', [
    ('decision-slot', {'expectedRevision': 3}, 'insert_decision_slot', ('w', 3)),
    ('rollback', {'releaseId': 'release-1', 'expectedRevision': 3}, 'rollback_workflow', ('w', 'release-1', 3)),
])
def test_draft_operations_forward_revision_and_principal(setup, operation, payload, method_name, expected):
    _, client, gateway = setup
    def invoke(*args, principal):
        assert args == expected and principal == 'operator'
        return {'revision': 4}
    setattr(gateway, method_name, invoke)
    assert client.post('/api/v1/workflows/w/' + operation, json=payload, headers=HEADERS).get_json() == {'revision': 4}
    assert client.post('/api/v1/workflows/w/' + operation, json={**payload, 'expectedRevision': True}, headers=HEADERS).status_code == 422


def test_creation_delegates_installed_template_identity(setup):
    _, client, gateway = setup
    def create(template, production, *, principal):
        assert (template, production, principal) == ('decision-routing-v1', 'Demo', 'operator')
        return {'workflowId': 'new'}
    gateway.create_managed_workflow = create
    response = client.post('/api/v1/workflows', json={'templateId': 'decision-routing-v1', 'production': 'Demo'}, headers=HEADERS)
    assert response.status_code == 201 and response.get_json()['workflowId'] == 'new'


def test_authentication_is_required_and_header_cannot_impersonate(setup):
    app, client, _ = setup
    app.config["STUDIO_AUTHENTICATE"] = None
    assert client.get("/api/v1/capabilities", headers={"X-User": "admin"}).status_code == 401


def test_authorization_and_csrf_are_fail_closed(setup):
    app, client, gateway = setup
    app.config["STUDIO_AUTHORIZE"] = None
    assert client.get("/api/v1/capabilities").status_code == 403
    app.config["STUDIO_AUTHORIZE"] = lambda p, a: True
    assert client.post("/api/v1/workflows/w/publish", json=PUBLISH).status_code == 403
    assert gateway.calls == []


def test_catalog_requires_production_and_propagates_principal(setup):
    _, client, gateway = setup
    assert client.get("/api/v1/workflows").status_code == 422
    assert client.get("/api/v1/workflows?production=Demo").status_code == 200
    assert gateway.calls == [("Demo", "operator")]


def test_publish_forwards_concurrency_and_idempotency(setup):
    _, client, gateway = setup
    response = client.post("/api/v1/workflows/w/publish", json=PUBLISH, headers=HEADERS)
    assert response.status_code == 201
    assert gateway.calls == [("w", "current", 1, "approved-1", {"principal": "operator", "idempotency_key": "publication-1"})]


@pytest.mark.parametrize("hash_value,status", [("stale", 409), ("*", 428), ('W/"current"', 428), ("", 428)])
def test_publish_preconditions(setup, hash_value, status):
    _, client, _ = setup
    response = client.post("/api/v1/workflows/w/publish", json=PUBLISH, headers={**HEADERS, "If-Match": hash_value})
    assert response.status_code == status


@pytest.mark.parametrize("patch", [{"confirmed": False}, {"confirmed": 1}, {"draftRevision": True}, {"draftRevision": 0}, {"unknown": "value"}])
def test_publish_invalid_contract_never_calls_gateway(setup, patch):
    _, client, gateway = setup
    assert client.post("/api/v1/workflows/w/publish", json={**PUBLISH, **patch}, headers=HEADERS).status_code == 422
    assert not gateway.calls


@pytest.mark.parametrize("result", [{}, {"compiled": False, "published": True, "releaseId": "x"}, {"compiled": True, "published": False, "releaseId": "x"}])
def test_publish_never_claims_success_without_confirmation(setup, result):
    _, client, gateway = setup
    gateway.result = result
    assert client.post("/api/v1/workflows/w/publish", json=PUBLISH, headers=HEADERS).status_code == 422


def binding():
    return {"bindingId": "b", "agentRef": {"id": "a", "revision": 1},
            "inputs": [{"source": "request.EventId", "target": "eventId", "required": True}],
            "outputs": {"action": "context.Action"}, "routes": {"REVIEW": "Review"},
            "fallback": {"action": "REVIEW", "target": "Review"}}


def test_binding_schema_and_revision(setup):
    _, client, gateway = setup
    response = client.put("/api/v1/bindings/b", json=binding(), headers={**HEADERS, "If-Match": '"2"'})
    assert response.status_code == 200
    assert gateway.calls == [("b", 2, "operator")]
    data = binding()
    data["agentRef"]["revision"] = True
    assert client.put("/api/v1/bindings/b", json=data, headers=HEADERS).status_code == 422


def test_binding_fallback_and_identifier_are_validated(setup):
    _, client, gateway = setup
    data = binding()
    data["fallback"]["target"] = "Unapproved"
    assert client.put("/api/v1/bindings/b", json=data, headers=HEADERS).status_code == 422
    assert client.put("/api/v1/bindings/other", json=binding(), headers=HEADERS).status_code == 422
    assert gateway.calls == []


def test_live_submission_and_simulation_rejection(setup):
    _, client, gateway = setup
    payload = {"releaseId": "r", "mode": "simulation", "payload": {}}
    assert client.post("/api/v1/test-runs", json=payload, headers=HEADERS).status_code == 422
    assert gateway.calls == []
    payload["mode"] = "live"
    response = client.post("/api/v1/test-runs", json=payload, headers=HEADERS)
    assert response.status_code == 202
    assert response.json == {"executionId": "execution-1", "mode": "live"}


def test_unexpected_errors_are_redacted_and_correlated(setup):
    _, client, _ = setup
    response = client.get("/api/v1/runs/x")
    assert response.status_code == 502
    assert "secret-provider-token" not in response.get_data(as_text=True)
    assert response.json["correlationId"] == response.headers["X-Correlation-ID"]
    assert response.headers["Cache-Control"] == "no-store"


def test_malformed_json_is_standard_error(setup):
    _, client, _ = setup
    response = client.post("/api/v1/workflows", data="{", content_type="application/json", headers=HEADERS)
    assert response.status_code == 400
    assert response.json["errorCode"] == "INVALID_HTTP_REQUEST"


def test_agent_accepts_multiline_prompt(setup):
    _, client, gateway = setup
    data = {"definition": {"providerRef": "provider", "modelName": "model", "prompt": "Assess event.\nReturn JSON.\n"}, "baseRevision": 0}
    response = client.put("/api/v1/agents/a", json=data, headers=HEADERS)
    assert response.status_code == 200
    assert gateway.calls[0][1]["prompt"] == data["definition"]["prompt"]


@pytest.mark.parametrize("prompt", ["", " \n ", "x" * 32001, "bad\x00prompt"])
def test_agent_rejects_invalid_prompt(setup, prompt):
    _, client, gateway = setup
    data = {"definition": {"providerRef": "provider", "modelName": "model", "prompt": prompt}, "baseRevision": 0}
    assert client.put("/api/v1/agents/a", json=data, headers=HEADERS).status_code == 422
    assert gateway.calls == []


@pytest.mark.parametrize("source,target", [("request.EventId;do Evil", "event"), ("request.EventId", "x[0]"), ("request.__class__", "event"), ("request.EventId", "")])
def test_binding_rejects_executable_or_empty_input_paths(setup, source, target):
    _, client, gateway = setup
    data = binding()
    data["inputs"][0].update(source=source, target=target)
    assert client.put("/api/v1/bindings/b", json=data, headers=HEADERS).status_code == 422
    assert gateway.calls == []


@pytest.mark.parametrize("path", ["", "request.Action", "context.Action=1", "context.Action[0]"])
def test_binding_rejects_invalid_output_path(setup, path):
    _, client, gateway = setup
    data = binding()
    data["outputs"]["action"] = path
    assert client.put("/api/v1/bindings/b", json=data, headers=HEADERS).status_code == 422
    assert gateway.calls == []


@pytest.mark.parametrize("action,target", [("review", "Review"), ("", "Review"), ("REVIEW", ""), ("REVIEW", "Review;do Evil"), ("REVIEW", "Review ")])
def test_binding_rejects_invalid_action_and_host(setup, action, target):
    _, client, gateway = setup
    data = binding()
    data["routes"] = {action: target}
    data["fallback"] = {"action": action, "target": target}
    assert client.put("/api/v1/bindings/b", json=data, headers=HEADERS).status_code == 422
    assert gateway.calls == []
