"""Authenticated IRIS WSGI entry: module wsgi_iris, callable application.

The IRIS Web Application must enforce password authentication and run in USER.
This file does not accept an identity from HTTP headers or start a web server.
"""
import secrets
import sys
from pathlib import Path

if Path("/durable/studio-python").is_dir():
    sys.path.insert(0, "/durable/studio-python")
sys.path.insert(0, str(Path(__file__).resolve().parent))

from flask import jsonify
from studio import create_app
from studio.services.gateway import GatewayError
from studio.services.iris_embedded import EmbeddedGateway


def create_iris_app(iris_module=None):
    gateway = EmbeddedGateway(iris_module)
    app = create_app({
        "IRIS_GATEWAY": gateway,
        "STUDIO_AUTHENTICATE": lambda request: gateway.current_user(),
        "STUDIO_AUTHORIZE": lambda principal, action: gateway.has_access(principal),
        "STUDIO_CSRF_TOKEN": "",
        "STUDIO_CSRF_VALIDATE": lambda request, principal: (
            gateway.has_access(principal)
            and secrets.compare_digest(request.headers.get("X-CSRF-Token", "").encode("utf-8"),
                                       app.config["STUDIO_CSRF_TOKEN"].encode("ascii"))
        ),
    })

    @app.before_request
    def require_native_access():
        try:
            principal = gateway.current_user()
            if not principal:
                return jsonify(errorCode="AUTHENTICATION_REQUIRED", message="Native authentication required."), 401
            if not gateway.has_access(principal):
                return jsonify(errorCode="ACCESS_DENIED", message="Native administrative permission required."), 403
            # Shared native token survives worker changes; never log or cache it
            # in browser storage. Fetch after native authentication on each request.
            app.config["STUDIO_CSRF_TOKEN"] = gateway.csrf_token()
        except GatewayError as error:
            return jsonify(errorCode=error.code, message=error.message), error.status

    @app.after_request
    def protect_authenticated_pages(response):
        response.headers["Cache-Control"] = "no-store"
        response.headers["X-Content-Type-Options"] = "nosniff"
        return response

    return app


application = create_iris_app()
