"""IRIS Embedded Python adapter for the allowlisted native control plane.

Importing this module outside IRIS is harmless. The actual ``iris`` module is
loaded only when the adapter is used. Native arguments remain JSON data passed
as method parameters; no ObjectScript text is assembled from HTTP input.
"""
from importlib import import_module
import json
import re

from .gateway import GatewayError


class EmbeddedGateway:
    def __init__(self, iris_module=None):
        self._iris = iris_module

    def _module(self):
        if self._iris is None:
            try:
                self._iris = import_module("iris")
            except Exception:
                raise GatewayError("IRIS_RUNTIME_UNAVAILABLE", "IRIS Embedded Python is unavailable.", 503) from None
        return self._iris

    def current_user(self):
        try:
            value = self._module().cls("Studio.Admin.RuntimeBridge").CurrentUser()
        except GatewayError:
            raise
        except Exception:
            raise GatewayError("IRIS_RUNTIME_UNAVAILABLE", "Native authentication context is unavailable.", 503) from None
        if not isinstance(value, str) or value.casefold() in {"", "unknownuser", "$unknownuser"}:
            return None
        return value

    def has_access(self, principal):
        if not principal or principal != self.current_user():
            return False
        try:
            return bool(self._module().cls("Studio.Admin.RuntimeBridge").HasAccess())
        except Exception:
            raise GatewayError("IRIS_RUNTIME_UNAVAILABLE", "Native authorization context is unavailable.", 503) from None

    def csrf_token(self):
        try:
            value = self._module().cls("Studio.Admin.RuntimeBridge").CsrfToken()
        except Exception:
            raise GatewayError("IRIS_RUNTIME_UNAVAILABLE", "Native request protection is unavailable.", 503) from None
        if not isinstance(value, str) or not 32 <= len(value) <= 256 or not value.isascii():
            raise GatewayError("IRIS_RUNTIME_UNAVAILABLE", "Native request protection is unavailable.", 503)
        return value

    def _authorize(self, principal):
        if not principal or principal != self.current_user():
            raise GatewayError("AUTHENTICATION_REQUIRED", "Native identity does not match this request.", 401)
        if not self.has_access(principal):
            raise GatewayError("ACCESS_DENIED", "Native administrative permission is required.", 403)

    @staticmethod
    def _json(value):
        try:
            return json.dumps(value, ensure_ascii=False, allow_nan=False, separators=(",", ":"))
        except (TypeError, ValueError):
            raise GatewayError("INVALID_CONTRACT", "The request must contain JSON-compatible data.", 422) from None

    @staticmethod
    def _decode(raw):
        try:
            result = json.loads(str(raw))
        except (TypeError, ValueError):
            raise GatewayError("INVALID_NATIVE_RESPONSE", "IRIS returned an invalid administrative response.", 502) from None
        if not isinstance(result, dict) or type(result.get("ok")) is not bool:
            raise GatewayError("INVALID_NATIVE_RESPONSE", "IRIS returned an invalid administrative response.", 502)
        if result["ok"]:
            if "data" not in result:
                raise GatewayError("INVALID_NATIVE_RESPONSE", "IRIS returned no administrative result.", 502)
            return result["data"]
        code, message, status = result.get("errorCode"), result.get("message"), result.get("httpStatus")
        if (not isinstance(code, str) or not re.fullmatch(r"[A-Z0-9_]{1,128}", code)
                or not isinstance(message, str) or not message or len(message) > 1024
                or type(status) is not int or not 400 <= status <= 599):
            raise GatewayError("INVALID_NATIVE_RESPONSE", "IRIS returned an invalid administrative error.", 502)
        raise GatewayError(code, message, status)

    def _dispatch(self, action, args, principal):
        self._authorize(principal)
        data = self._json(args)
        try:
            raw = self._module().cls("Studio.Admin.ControlPlane").Dispatch(action, data)
        except Exception:
            raise GatewayError("IRIS_OPERATION_FAILED", "The native administrative operation failed.", 502) from None
        return self._decode(raw)

    def detect_capabilities(self, *, principal):
        return self._dispatch("detect_capabilities", {}, principal)

    def publish_component(self, payload, *, principal):
        self._authorize(principal)
        try:
            raw = self._module().cls("Studio.Admin.Workspace").Dispatch("publish_component", self._json(payload))
        except Exception:
            raise GatewayError("COMPONENT_PUBLISH_FAILED", "Native component publication failed.", 502) from None
        return self._decode(raw)

    def get_settings(self, *, principal):
        self._authorize(principal)
        try:
            raw = self._module().cls("Studio.Admin.Settings").Read()
        except Exception:
            raise GatewayError("SETTINGS_UNAVAILABLE", "Native settings are unavailable.", 503) from None
        return self._decode(raw)

    def save_settings(self, payload, *, principal):
        self._authorize(principal)
        encoded = self._json(payload)
        try:
            raw = self._module().cls("Studio.Admin.Settings").Save(encoded)
        except Exception:
            raise GatewayError("SETTINGS_SAVE_FAILED", "Native settings could not be saved.", 503) from None
        return self._decode(raw)

    def list_productions(self, *, principal):
        return self._dispatch("list_productions", {}, principal)

    def list_templates(self, *, principal):
        return self._dispatch("list_templates", {}, principal)

    def list_workflows(self, production, *, principal):
        return self._dispatch("list_workflows", {"production": production}, principal)

    def get_workflow(self, workflow_id, *, principal):
        return self._dispatch("get_workflow", {"workflowId": workflow_id}, principal)

    def create_managed_workflow(self, template_id, production, *, principal):
        return self._dispatch("create_managed_workflow", {"templateId": template_id, "production": production}, principal)

    def insert_decision_slot(self, workflow_id, expected_revision, *, principal):
        return self._dispatch("insert_decision_slot", {"workflowId": workflow_id,
                                                       "expectedRevision": expected_revision}, principal)

    def preview_input(self, workflow_id, binding, example, *, principal):
        return self._dispatch("preview_input", {"workflowId": workflow_id, "binding": binding,
                                                "example": example}, principal)

    def rollback_workflow(self, workflow_id, release_id, expected_revision, *, principal):
        return self._dispatch("rollback_workflow", {"workflowId": workflow_id, "releaseId": release_id,
                                                    "expectedRevision": expected_revision}, principal)

    def list_agents(self, *, principal):
        return self._dispatch("list_agents", {}, principal)

    def save_agent_revision(self, agent_id, definition, base_revision, *, principal):
        return self._dispatch("save_agent_revision", {"agentId": agent_id, "definition": definition,
                                                      "baseRevision": base_revision}, principal)

    def save_binding(self, binding_id, payload, expected_revision, *, principal):
        return self._dispatch("save_binding", {"bindingId": binding_id, "payload": payload,
                                               "expectedRevision": expected_revision}, principal)

    def list_toolsets(self, *, principal):
        return self._dispatch("list_toolsets", {}, principal)

    def validate_workflow(self, workflow_id, *, principal):
        return self._dispatch("validate_workflow", {"workflowId": workflow_id}, principal)

    def preview_publish(self, workflow_id, *, principal):
        return self._dispatch("preview_publish", {"workflowId": workflow_id}, principal)

    def publish_workflow(self, workflow_id, base_hash, revision, approval_ref, *, idempotency_key, principal):
        return self._dispatch("publish_workflow", {"workflowId": workflow_id, "baseHash": base_hash,
                                                   "revision": revision, "approvalRef": approval_ref,
                                                   "idempotencyKey": idempotency_key}, principal)

    def list_releases(self, workflow_id, *, principal):
        return self._dispatch("list_releases", {"workflowId": workflow_id}, principal)

    def submit_test_message(self, release_id, payload, *, principal):
        self._authorize(principal)
        data = self._json({"releaseId": release_id, "payload": payload})
        try:
            raw = self._module().cls("Studio.Admin.TestHarness").ExecuteJson(data)
        except Exception:
            raise GatewayError("IRIS_TEST_FAILED", "The native test Service could not be invoked.", 502) from None
        result = self._decode(raw)
        execution_id = result.get("executionId") if isinstance(result, dict) else result
        if not isinstance(execution_id, str) or not execution_id or len(execution_id) > 128:
            raise GatewayError("INVALID_NATIVE_RESPONSE", "IRIS returned no execution identifier.", 502)
        return execution_id

    def get_run(self, execution_id, *, principal):
        self._authorize(principal)
        try:
            raw = self._module().cls("Studio.Admin.TestHarness").GetRunJson(execution_id)
        except Exception:
            raise GatewayError("IRIS_TRACE_FAILED", "The native execution evidence could not be read.", 502) from None
        return self._decode(raw)
