"""Adapter contract tests. Fakes do not count as native runtime evidence."""
import json

import pytest

from studio.services.gateway import GatewayError
from studio.services.iris_embedded import EmbeddedGateway
from wsgi_iris import create_iris_app


class Native:
    def __init__(self):
        self.user = "studio"
        self.allowed = True
        self.calls = []
        self.result = {"ok": True, "data": {"namespace": "USER"}}
        self.failure = None

    def cls(self, class_name):
        assert class_name in {"Studio.Admin.RuntimeBridge", "Studio.Admin.ControlPlane", "Studio.Admin.TestHarness"}
        return self

    def CurrentUser(self):
        return self.user

    def HasAccess(self):
        return self.allowed

    def CsrfToken(self):
        return "shared-native-token-012345678901234567890123456789"

    def Dispatch(self, action, data):
        self.calls.append((action, json.loads(data)))
        if self.failure:
            raise self.failure
        return json.dumps(self.result)

    def ExecuteJson(self, data):
        self.calls.append(("ExecuteJson", json.loads(data)))
        return json.dumps(self.result)

    def GetRunJson(self, execution_id):
        self.calls.append(("GetRunJson", execution_id))
        return json.dumps(self.result)


@pytest.fixture
def native():
    return Native()


def test_serialized_arguments_are_data_and_native_identity_is_not_forwarded(native):
    gateway = EmbeddedGateway(native)
    value = 'request." ) Do Dangerous() //'
    gateway.list_workflows(value, principal="studio")
    assert native.calls == [("list_workflows", {"production": value})]


def test_authentication_and_permission_are_required_before_native_dispatch(native):
    gateway = EmbeddedGateway(native)
    with pytest.raises(GatewayError) as error:
        gateway.detect_capabilities(principal="forged-admin")
    assert error.value.status == 401
    native.allowed = False
    with pytest.raises(GatewayError) as error:
        gateway.detect_capabilities(principal="studio")
    assert error.value.status == 403
    assert native.calls == []


@pytest.mark.parametrize("user", ["", "UnknownUser", "$UnknownUser", None])
def test_unknown_native_identity_is_not_authenticated(native, user):
    native.user = user
    assert EmbeddedGateway(native).current_user() is None


def test_conflict_and_compile_errors_preserve_safe_native_status(native):
    native.result = {"ok": False, "errorCode": "BPL_SOURCE_CONFLICT", "message": "Source changed.", "httpStatus": 409}
    with pytest.raises(GatewayError) as error:
        EmbeddedGateway(native).publish_workflow("blood-routing", "hash", 2, "approval", idempotency_key="idem", principal="studio")
    assert error.value.code == "BPL_SOURCE_CONFLICT"
    assert error.value.status == 409
    assert native.calls[0][1] == {"workflowId": "blood-routing", "baseHash": "hash", "revision": 2,
                                  "approvalRef": "approval", "idempotencyKey": "idem"}


def test_native_exception_is_sanitized(native):
    native.failure = RuntimeError("secret-provider-key")
    with pytest.raises(GatewayError) as error:
        EmbeddedGateway(native).detect_capabilities(principal="studio")
    assert "secret" not in str(error.value)
    assert error.value.status == 502


@pytest.mark.parametrize("raw", ["not json", "[]", '{"ok":1,"data":{}}', '{"ok":true}', '{"ok":false}'])
def test_invalid_native_wrapper_cannot_look_successful(raw):
    with pytest.raises(GatewayError) as error:
        EmbeddedGateway._decode(raw)
    assert error.value.status == 502


def test_native_test_harness_is_used_and_execution_id_is_required(native):
    native.result = {"ok": True, "data": {"executionId": "exec-1"}}
    gateway = EmbeddedGateway(native)
    assert gateway.submit_test_message("rel-1", {"BloodGroup": "O+", "Units": 5}, principal="studio") == "exec-1"
    assert native.calls == [("ExecuteJson", {"releaseId": "rel-1", "payload": {"BloodGroup": "O+", "Units": 5}})]
    native.result = {"ok": True, "data": {"status": "SUCCESS"}}
    assert gateway.get_run("exec-1", principal="studio") == {"status": "SUCCESS"}
    assert native.calls[-1] == ("GetRunJson", "exec-1")
    with pytest.raises(GatewayError):
        gateway.submit_test_message("rel-1", {}, principal="studio")


def test_wsgi_guards_pages_and_ignores_forged_identity_headers(native):
    native.user = "UnknownUser"
    app = create_iris_app(native)
    client = app.test_client()
    assert client.get("/", headers={"X-User": "studio"}).status_code == 401
    assert client.get("/api/v1/capabilities", headers={"X-User": "studio"}).status_code == 401
    assert not native.calls


def test_wsgi_authentication_csrf_and_request_dispatch(native):
    app = create_iris_app(native)
    client = app.test_client()
    assert client.get("/").status_code == 200
    assert client.get("/api/v1/capabilities").get_json() == {"namespace": "USER"}
    assert client.post("/api/v1/workflows/blood-routing/validate").status_code == 403
    response = client.post("/api/v1/workflows/blood-routing/validate", headers={"X-CSRF-Token": app.config["STUDIO_CSRF_TOKEN"]})
    assert response.status_code == 200
    assert native.calls[-1] == ("validate_workflow", {"workflowId": "blood-routing"})
    assert response.headers["Cache-Control"] == "no-store"


def test_wsgi_permission_is_rechecked_per_request(native):
    app = create_iris_app(native)
    client = app.test_client()
    assert client.get("/").status_code == 200
    native.allowed = False
    assert client.get("/").status_code == 403
    assert client.get("/api/v1/capabilities").status_code == 403


def test_wsgi_shared_native_csrf_survives_different_worker_apps(native):
    first, second = create_iris_app(native), create_iris_app(native)
    first_client, second_client = first.test_client(), second.test_client()
    assert first_client.get("/").status_code == 200
    token = first.config["STUDIO_CSRF_TOKEN"]
    response = second_client.post("/api/v1/workflows/blood-routing/validate", headers={"X-CSRF-Token": token})
    assert response.status_code == 200
    assert second.config["STUDIO_CSRF_TOKEN"] == token
    response = second_client.post("/api/v1/workflows/blood-routing/validate", headers={"X-CSRF-Token": "é"})
    assert response.status_code == 403
