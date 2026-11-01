"""HTTP contract validation; never evaluate mapping expressions."""
import json
import re
from functools import lru_cache
from pathlib import Path
from jsonschema import Draft202012Validator
from .gateway import GatewayError

SOURCE_PATH = re.compile(r"(?:request|context)\.[A-Za-z][A-Za-z0-9]*(?:\.[A-Za-z][A-Za-z0-9]*)*")
OUTPUT_PATH = re.compile(r"(?:context|response)\.[A-Za-z][A-Za-z0-9]*(?:\.[A-Za-z][A-Za-z0-9]*)*")
FIELD = re.compile(r"[A-Za-z][A-Za-z0-9_]{0,63}")
ACTION = re.compile(r"[A-Z_]{1,40}")
HOST = re.compile(r"[A-Za-z][A-Za-z0-9_. -]{0,127}")


def invalid(message):
    raise GatewayError("INVALID_CONTRACT", message, 422)


def validate_object(value, required=(), allowed=None):
    if not isinstance(value, dict):
        invalid("A JSON object is required.")
    if not set(required).issubset(value):
        invalid("Required fields are missing.")
    if allowed is not None and set(value) - set(allowed):
        invalid("Unknown fields are not allowed.")


def require_text(value, field, maximum=128):
    if not isinstance(value, str) or not value.strip() or len(value) > maximum or any(ord(c) < 32 for c in value):
        invalid(f"{field} must be a nonempty bounded string without control characters.")
    return value


def require_revision(value, minimum=1):
    if type(value) is not int or value < minimum:
        invalid("Revision must be an integer within the permitted range.")
    return value


def require_prompt(value):
    if not isinstance(value, str) or not value.strip() or len(value) > 16384 or "\x00" in value:
        invalid("prompt must be nonempty, at most 16384 characters and contain no NUL.")
    return value


@lru_cache(maxsize=1)
def binding_validator():
    schema = Path(__file__).resolve().parents[3] / "contracts/schemas/decision-binding.schema.json"
    return Draft202012Validator(json.loads(schema.read_text(encoding="utf-8")))


def validate_binding(payload):
    if not binding_validator().is_valid(payload):
        invalid("DecisionBinding does not match its JSON Schema.")
    if payload["fallback"]["action"] not in payload["routes"]:
        invalid("Fallback action must have a route.")
    if payload["routes"][payload["fallback"]["action"]] != payload["fallback"]["target"]:
        invalid("Fallback target must match its declared route.")
    targets = [mapping["target"] for mapping in payload["inputs"]]
    if len(targets) != len(set(targets)):
        invalid("Input targets must be unique.")
    for entry in payload["inputs"]:
        source = entry["source"]
        constant = source.startswith("constant:") and len(source) <= 265 and "\x00" not in source
        field = len(source) <= 256 and SOURCE_PATH.fullmatch(source)
        if not (constant or field) or not FIELD.fullmatch(entry["target"]):
            invalid("Inputs require bounded property paths or string constants and simple target fields.")
    for field, path in payload["outputs"].items():
        if not FIELD.fullmatch(field) or len(path) > 256 or not OUTPUT_PATH.fullmatch(path):
            invalid("Outputs require simple fields and bounded context/response property paths.")
    for action, target in payload["routes"].items():
        if not ACTION.fullmatch(action) or not HOST.fullmatch(target) or target != target.strip():
            invalid("Routes require uppercase action identifiers and nonempty host names.")
