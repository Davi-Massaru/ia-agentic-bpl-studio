"""Administrative HTTP boundary. Message execution belongs exclusively to IRIS."""
from uuid import uuid4
from flask import Blueprint, current_app, g, jsonify, request
from werkzeug.exceptions import HTTPException
from ..services.gateway import GatewayError
from ..services.validation import validate_binding, validate_object, require_text, require_revision, require_prompt

api = Blueprint("api", __name__)


def error(code, message, status):
    return jsonify(errorCode=code, message=message,
                   correlationId=getattr(g, "correlation_id", uuid4().hex), details=[]), status


@api.before_request
def security_boundary():
    g.correlation_id = uuid4().hex
    g.gateway = current_app.config.get("IRIS_GATEWAY")
    if g.gateway is None:
        response, status = error("IRIS_GATEWAY_NOT_CONFIGURED", "IRIS gateway is not configured.", 501)
        payload = response.get_json()
        payload["status"] = "NOT_IMPLEMENTED"
        return jsonify(payload), status
    authenticate = current_app.config.get("STUDIO_AUTHENTICATE")
    g.principal = authenticate(request) if authenticate else None
    if not g.principal:
        return error("AUTHENTICATION_REQUIRED", "Authentication required.", 401)
    authorize = current_app.config.get("STUDIO_AUTHORIZE")
    if not authorize or not authorize(g.principal, request.endpoint.removeprefix("api.")):
        return error("ACCESS_DENIED", "Operation is not authorized.", 403)
    if request.method in {"POST", "PUT", "DELETE", "PATCH"}:
        validate_csrf = current_app.config.get("STUDIO_CSRF_VALIDATE")
        if not validate_csrf or not validate_csrf(request, g.principal):
            return error("REQUEST_TOKEN_REQUIRED", "A valid request token is required.", 403)


@api.after_request
def response_headers(response):
    response.headers["X-Correlation-ID"] = getattr(g, "correlation_id", "")
    response.headers["Cache-Control"] = "no-store"
    return response


@api.errorhandler(GatewayError)
def gateway_error(exc):
    return error(exc.code, exc.message, exc.status)


@api.errorhandler(HTTPException)
def http_error(exc):
    return error("INVALID_HTTP_REQUEST", exc.name, exc.code)


@api.errorhandler(Exception)
def unexpected_error(exc):
    current_app.logger.error("Gateway failure correlation=%s type=%s", g.correlation_id, type(exc).__name__)
    return error("GATEWAY_FAILURE", "The administrative operation failed.", 502)


def call(method, *args, **kwargs):
    return getattr(g.gateway, method)(*args, principal=g.principal, **kwargs)


def body(required=(), allowed=None):
    payload = request.get_json()
    validate_object(payload, required, allowed)
    return payload


def version_header():
    value = request.headers.get("If-Match", "")
    if not value or value.startswith("W/") or value == "*" or "," in value:
        raise GatewayError("PRECONDITION_REQUIRED", "A single strong If-Match value is required.", 428)
    return require_text(value.strip('"'), "If-Match", 256)


@api.get("/capabilities")
def capabilities():
    return jsonify(call("detect_capabilities"))


@api.post("/components")
def publish_component():
    data = body(("production", "hostName", "agentId", "agentRevision", "allowedActions", "fallbackAction", "policy"),
                {"production", "hostName", "agentId", "agentRevision", "allowedActions", "fallbackAction", "policy"})
    return jsonify(call("publish_component", data)), 201


@api.get("/productions")
def productions():
    return jsonify(call("list_productions"))


@api.get("/templates")
def templates():
    return jsonify(call("list_templates"))


@api.get("/settings")
def settings():
    return jsonify(call("get_settings"))


@api.put("/settings")
def save_settings():
    data = body(("provider", "model"), {"provider", "model", "apiKey"})
    if data["provider"] not in {"openai", "anthropic"}:
        raise GatewayError("INVALID_PROVIDER", "Select a supported provider.", 422)
    require_text(data["model"], "model", 128)
    if "apiKey" in data and data["apiKey"] != "":
        require_text(data["apiKey"], "credential", 1024)
    return jsonify(call("save_settings", data))


@api.get("/workflows")
def workflows():
    return jsonify(call("list_workflows", require_text(request.args.get("production"), "production", 256)))


@api.post("/workflows")
def create_workflow():
    data = body(("templateId", "production"), {"templateId", "production"})
    return jsonify(call("create_managed_workflow", require_text(data["templateId"], "templateId", 64),
                        require_text(data["production"], "production", 256))), 201


@api.get("/workflows/<workflow_id>")
def workflow(workflow_id):
    result = call("get_workflow", workflow_id)
    response = jsonify(result)
    if result.get("baseHash"):
        response.set_etag(result["baseHash"])
    return response


@api.post("/workflows/<workflow_id>/decision-slot")
def insert_decision(workflow_id):
    data = body(("expectedRevision",), {"expectedRevision"})
    return jsonify(call("insert_decision_slot", workflow_id, require_revision(data["expectedRevision"])))


@api.post("/workflows/<workflow_id>/preview-input")
def preview_input(workflow_id):
    data = body(("binding", "example"), {"binding", "example"})
    validate_binding(data["binding"])
    validate_object(data["example"])
    return jsonify(call("preview_input", workflow_id, data["binding"], data["example"]))


@api.post("/workflows/<workflow_id>/rollback")
def rollback_workflow(workflow_id):
    data = body(("releaseId", "expectedRevision"), {"releaseId", "expectedRevision"})
    return jsonify(call("rollback_workflow", workflow_id, require_text(data["releaseId"], "releaseId"),
                        require_revision(data["expectedRevision"])))


@api.post("/workflows/<workflow_id>/validate")
def validate(workflow_id):
    return jsonify(call("validate_workflow", workflow_id))


@api.post("/workflows/<workflow_id>/preview")
def preview(workflow_id):
    return jsonify(call("preview_publish", workflow_id))


@api.post("/workflows/<workflow_id>/publish")
def publish(workflow_id):
    data = body(("draftRevision", "approvalRef", "confirmed"), {"draftRevision", "approvalRef", "confirmed"})
    if data["confirmed"] is not True:
        raise GatewayError("CONFIRMATION_REQUIRED", "Explicit publication confirmation is required.", 422)
    result = call("publish_workflow", workflow_id, version_header(),
                  require_revision(data["draftRevision"]), require_text(data["approvalRef"], "approvalRef"),
                  idempotency_key=require_text(request.headers.get("Idempotency-Key"), "Idempotency-Key"))
    if result.get("compiled") is not True or result.get("published") is not True or not result.get("releaseId"):
        raise GatewayError("PUBLICATION_NOT_CONFIRMED", "IRIS did not confirm a compiled, published release.", 422)
    return jsonify(result), 201


@api.get("/workflows/<workflow_id>/releases")
def releases(workflow_id):
    return jsonify(call("list_releases", workflow_id))


@api.get("/agents")
def agents():
    return jsonify(call("list_agents"))


@api.put("/agents/<agent_id>")
def save_agent(agent_id):
    data = body(("definition", "baseRevision"), {"definition", "baseRevision"})
    validate_object(data["definition"], ("providerRef", "modelName", "prompt"),
                    {"providerRef", "modelName", "prompt", "toolSetRefs"})
    for name in ("providerRef", "modelName"):
        require_text(data["definition"][name], name, 256)
    require_prompt(data["definition"]["prompt"])
    tools = data["definition"].get("toolSetRefs", [])
    if not isinstance(tools, list) or len(tools) > 40:
        raise GatewayError("INVALID_CONTRACT", "toolSetRefs must be a bounded list.", 422)
    for tool in tools:
        require_text(tool, "toolSetRef", 256)
    return jsonify(call("save_agent_revision", agent_id, data["definition"], require_revision(data["baseRevision"], minimum=0)))


@api.get("/toolsets")
def toolsets():
    return jsonify(call("list_toolsets"))


@api.put("/bindings/<binding_id>")
def save_binding(binding_id):
    data = body()
    validate_binding(data)
    if data["bindingId"] != binding_id:
        raise GatewayError("BINDING_ID_MISMATCH", "Path and binding identifier must match.", 422)
    revision = version_header()
    if not revision.isdecimal():
        raise GatewayError("INVALID_REVISION", "Binding If-Match must contain the expected integer revision.", 422)
    return jsonify(call("save_binding", binding_id, data, int(revision)))


@api.post("/test-runs")
def test_run():
    data = body(("releaseId", "mode", "payload"), {"releaseId", "mode", "payload"})
    if data["mode"] != "live":
        raise GatewayError("MODE_NOT_SUPPORTED", "Only live Production tests are supported by this endpoint.", 422)
    validate_object(data["payload"])
    execution_id = call("submit_test_message", require_text(data["releaseId"], "releaseId"), data["payload"])
    if not isinstance(execution_id, str) or not execution_id:
        raise GatewayError("EXECUTION_NOT_CONFIRMED", "IRIS did not return an execution identifier.", 502)
    return jsonify(executionId=execution_id, mode="live"), 202


@api.get("/runs/<execution_id>")
def run(execution_id):
    return jsonify(call("get_run", execution_id))
