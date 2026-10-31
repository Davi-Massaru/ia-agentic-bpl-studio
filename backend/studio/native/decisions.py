"""Pure decision contracts shared by Embedded Python and local regression tests."""
import json
import math
import re


class DecisionError(ValueError):
    pass


def parse_candidate(raw):
    if not isinstance(raw, str) or not 1 <= len(raw) <= 16384:
        raise DecisionError('CANDIDATE_SIZE_INVALID')
    try:
        candidate = json.loads(raw, parse_constant=lambda _: (_ for _ in ()).throw(ValueError()))
    except (ValueError, TypeError):
        raise DecisionError('CANDIDATE_JSON_INVALID') from None
    if not isinstance(candidate, dict):
        raise DecisionError('CANDIDATE_OBJECT_REQUIRED')
    return candidate


def valid_action(value):
    return isinstance(value, str) and re.fullmatch(r'[A-Z_]{1,40}', value) is not None


def validate_candidate(raw, routes, fallback):
    if not valid_action(fallback):
        raise DecisionError('FALLBACK_ACTION_INVALID')
    candidate = parse_candidate(raw)
    if set(candidate) - {'action', 'reason', 'evidenceRefs'}:
        raise DecisionError('CANDIDATE_UNKNOWN_FIELD')
    action = candidate.get('action')
    if not isinstance(action, str):
        raise DecisionError('ACTION_STRING_REQUIRED')
    if not valid_action(action):
        raise DecisionError('ACTION_INVALID')
    if not isinstance(routes, dict):
        raise DecisionError('ROUTES_INVALID')
    if not isinstance(routes.get(action), str):
        raise DecisionError('ACTION_NOT_ALLOWED')
    if not routes[action]:
        raise DecisionError('ROUTE_EMPTY')
    reason, evidence = candidate.get('reason', ''), candidate.get('evidenceRefs', [])
    if not isinstance(reason, str):
        raise DecisionError('REASON_STRING_REQUIRED')
    if len(reason) > 2048:
        raise DecisionError('REASON_TOO_LONG')
    if not isinstance(evidence, list):
        raise DecisionError('EVIDENCE_ARRAY_REQUIRED')
    if len(evidence) > 25:
        raise DecisionError('EVIDENCE_TOO_LARGE')
    for item in evidence:
        if not isinstance(item, str):
            raise DecisionError('EVIDENCE_STRING_REQUIRED')
        if len(item) > 128:
            raise DecisionError('EVIDENCE_REF_TOO_LONG')
    return dict(status='SUCCESS', action=action, reason=reason, evidenceRefs=evidence)


def stock(center, group):
    return {'B': {'O+': 12, 'A+': 2}, 'C': {'O+': 3, 'A+': 15}}.get(center, {}).get(group, 0)


def snapshot(group):
    return dict(synthetic=True, group=group,
                B=dict(minutes=30, units=stock('B', group)),
                C=dict(minutes=55, units=stock('C', group)))


def validate_stock_request(group, units, mode, correlation):
    if group not in ('O+', 'A+'):
        raise DecisionError('GROUP_INVALID')
    if isinstance(units, bool):
        raise DecisionError('UNITS_INVALID')
    try:
        number = float(units)
        if not math.isfinite(number) or not number.is_integer() or not 1 <= number <= 100:
            raise ValueError()
    except (ValueError, TypeError, OverflowError):
        raise DecisionError('UNITS_INVALID') from None
    if mode not in ('SIMULATION', 'LIVE'):
        raise DecisionError('MODE_INVALID')
    if not isinstance(correlation, str) or not 1 <= len(correlation) <= 128:
        raise DecisionError('CORRELATION_REQUIRED')
    return int(number)


def recommend(group, units):
    return next((center for center in ('B', 'C') if stock(center, group) >= units), 'REVIEW')
