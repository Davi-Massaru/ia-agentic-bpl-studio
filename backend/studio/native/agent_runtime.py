"""Embedded Python validation behind native IRIS message and SDK contracts."""
import json
import iris
from studio.native.decisions import (DecisionError, parse_candidate, validate_candidate,
                                    validate_stock_request, recommend)

def dynamic(value):
    return iris.cls('%DynamicObject')._FromJSON(json.dumps(value, ensure_ascii=False, allow_nan=False))

def error(code):
    return iris.cls('Studio.Runtime.Python').Error(code)

def failed(status):
    return bool(iris.cls('%SYSTEM.Status').IsError(status))

def validate(binding, raw, output):
    try:
        if not hasattr(binding, 'FallbackAction'):
            return error('BINDING_REQUIRED')
        output._Set('action', binding.FallbackAction)
        value = validate_candidate(raw, json.loads(str(binding.RoutesJson)), binding.FallbackAction)
        output._Set('value', dynamic(value))
        return 1
    except DecisionError as exc:
        return error(str(exc))
    except Exception:
        return error('CANDIDATE_OR_BINDING_INVALID')

def parse(raw, output):
    try:
        output._Set('value', dynamic(parse_candidate(raw)))
        return 1
    except DecisionError as exc:
        return error(str(exc))

def resolve_route(binding, status, action, output):
    if not hasattr(binding, 'FallbackTarget'):
        return error('BINDING_REQUIRED')
    if not binding.FallbackTarget:
        return error('FALLBACK_REQUIRED')
    output._Set('target', binding.FallbackTarget)
    if status != 'SUCCESS':
        return 1
    try:
        routes = json.loads(str(binding.RoutesJson))
        if not isinstance(routes, dict):
            return error('ROUTES_INVALID')
        if not isinstance(routes.get(action), str):
            return error('ACTION_NOT_ALLOWED')
        if not routes[action]:
            return error('ROUTE_EMPTY')
        output._Set('target', routes[action])
        return 1
    except Exception:
        return error('ROUTES_INVALID')

def stock_candidate(request, raw, output):
    if not hasattr(request, 'BloodGroup'):
        return error('REQUEST_REQUIRED')
    try:
        units = validate_stock_request(request.BloodGroup, request.Units, request.Mode, request.CorrelationId)
        value = validate_candidate(raw, {'B': 'HemocentroB', 'C': 'HemocentroC', 'REVIEW': 'Review'}, 'REVIEW')
        if value['action'] != recommend(request.BloodGroup, units):
            return error('CANDIDATE_VIOLATES_STOCK_POLICY')
        output._Set('value', dynamic(value))
        return 1
    except DecisionError as exc:
        return error(str(exc))

def stock_policy(input_object, raw, mode, execution):
    data = json.loads(str(input_object._ToJSON()))
    if not isinstance(data.get('group'), str) or type(data.get('units')) not in (int, float):
        return error('STOCK_INPUT_INVALID')
    request = iris.cls('Studio.BloodDemo.Request')._New()
    request.BloodGroup, request.Units = data['group'], data['units']
    request.Mode, request.CorrelationId = mode, execution
    status = stock_candidate(request, raw, dynamic({}))
    if failed(status):
        return status
    if mode == 'LIVE':
        audit = iris.gref('^StudioAudit')
        for index in range(1, int(audit[execution, 'toolCount'] or 0) + 1):
            event = json.loads(audit[execution, 'tools', index])
            if event.get('name') == 'ReadStock' and event.get('group') == data['group']:
                return 1
        return error('STOCK_TOOL_REQUIRED')
    return 1
