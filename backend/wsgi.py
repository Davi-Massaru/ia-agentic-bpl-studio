"""WSGI callable for InterSystems IRIS web application, when build 154 supports it.

Set Application Name to module 'wsgi' and Callable Name to 'application' (verify
actual IRIS Web Application settings). This module does not start a webserver.
"""
from studio import create_app

application = create_app()
