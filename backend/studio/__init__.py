"""HTTP control plane only. Never executes BPL or `%AI.Agent` on Flask."""
from flask import Flask, render_template
from .api.routes import api


def create_app(config: dict | None = None) -> Flask:
    app = Flask(__name__)
    app.config.update(MAX_CONTENT_LENGTH=1024 * 1024)
    if config:
        app.config.update(config)
    app.register_blueprint(api, url_prefix="/api/v1")

    @app.get("/")
    def explorer():
        return render_template("explorer.html", active="explorer")

    @app.get("/designer")
    def designer():
        return render_template("designer.html", active="designer")

    @app.get("/test-trace")
    def test_trace():
        return render_template("test_trace.html", active="test_trace")

    @app.get("/publisher")
    def publisher():
        return render_template("publisher.html", active="publisher")

    @app.get("/health")
    def health():
        gateway = app.config.get("IRIS_GATEWAY")
        authenticate = app.config.get("STUDIO_AUTHENTICATE")
        if gateway is not None and authenticate:
            from flask import request
            try:
                principal = authenticate(request)
                if not principal:
                    return {"service": "agentic-bpl-studio", "state": "authentication-required"}, 401
                capabilities = gateway.detect_capabilities(principal=principal)
                return {"service": "agentic-bpl-studio", "state": "iris-connected",
                        "irisConnected": True, "version": capabilities.get("version"),
                        "aiValidated": capabilities.get("liveAIValidated", False)}
            except Exception:
                return {"service": "agentic-bpl-studio", "state": "iris-unavailable", "irisConnected": False}, 503
        return {"service": "agentic-bpl-studio", "state": "scaffold-only", "irisConnected": False}

    return app
