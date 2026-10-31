"""Bounded mapping previews over JSON snapshots, without eval or IRIS calls.

Metadata must come from an authorized Dictionary query. These checks supplement,
but never replace, validation by the IRIS publisher and runtime.
"""
from copy import deepcopy
import re

PATH = re.compile(r"^(request|context)\.[A-Za-z][A-Za-z0-9]*(?:\.[A-Za-z][A-Za-z0-9]*)*$")
TARGET = re.compile(r"^[A-Za-z][A-Za-z0-9_]{0,63}$")
TYPES = {"string": str, "integer": int, "number": (int, float), "boolean": bool,
         "object": dict, "array": list}


class MappingError(ValueError):
    """Contains a safe error code, never the offending field value."""


def preview_inputs(mappings, snapshot, metadata):
    """Select explicitly declared fields. Missing optional fields are omitted.

metadata maps approved request/context paths to {type, sensitive}. No implicit
type coercion, attribute access, indexing expressions, or executable constants.
"""
    if not isinstance(mappings, list) or not 1 <= len(mappings) <= 40:
        raise MappingError("INVALID_MAPPING_COUNT")
    if not isinstance(snapshot, dict) or not isinstance(metadata, dict):
        raise MappingError("INVALID_SNAPSHOT")
    result, used = {}, set()
    for entry in mappings:
        if not isinstance(entry, dict) or set(entry) != {"source", "target", "required"}:
            raise MappingError("INVALID_MAPPING")
        source, target = entry["source"], entry["target"]
        if (not isinstance(source, str) or not PATH.fullmatch(source)
                or source not in metadata):
            raise MappingError("UNKNOWN_SOURCE")
        if not isinstance(target, str) or not TARGET.fullmatch(target) or target in used:
            raise MappingError("INVALID_TARGET")
        used.add(target)
        if type(entry["required"]) is not bool:
            raise MappingError("INVALID_REQUIRED_FLAG")
        spec = metadata[source]
        if not isinstance(spec, dict) or spec.get("type") not in TYPES:
            raise MappingError("UNSUPPORTED_FIELD_TYPE")
        value = snapshot
        for part in source.split("."):
            if not isinstance(value, dict) or part not in value:
                if entry["required"]:
                    raise MappingError("REQUIRED_INPUT_MISSING")
                break
            value = value[part]
        else:
            expected = spec["type"]
            if not isinstance(value, TYPES[expected]) or (
                    expected in {"integer", "number"} and isinstance(value, bool)):
                raise MappingError("INPUT_TYPE_MISMATCH")
            # Containers may contain sensitive descendants. Preview only scalars
            # explicitly classified as non-sensitive by trusted metadata.
            result[target] = (deepcopy(value) if spec.get("sensitive") is False
                              and expected not in {"object", "array"} else "[REDACTED]")
    return result
