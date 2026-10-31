"""Behavioral regression of decision logic migrated from ObjectScript."""
import json
import pytest
from studio.native.decisions import (DecisionError, validate_candidate, parse_candidate,
                                    validate_stock_request, snapshot, recommend)


@pytest.mark.parametrize('raw', ['not json', '[]', '{"action":true}', '{"action":"DELETE"}',
    '{"action":"ACCEPT","target":"UnsafeOperation"}', '{"action":"ACCEPT","evidenceRefs":[1]}',
    '{"action":"ACCEPT","reason":null}', '{"action":"ACCEPT","evidenceRefs":null}',
    '{"action":NaN}', '{"action":"ACCEPT","reason":' + json.dumps('x' * 2049) + '}',
    json.dumps({'action': 'ACCEPT', 'evidenceRefs': ['x'] * 26})])
def test_invalid_model_output_is_rejected(raw):
    with pytest.raises(DecisionError):
        validate_candidate(raw, {'ACCEPT': 'Target', 'REVIEW': 'Review'}, 'REVIEW')


def test_unicode_evidence_and_optional_defaults():
    result = validate_candidate('{"action":"ACCEPT","reason":"ação ✓"}', {'ACCEPT': 'Target'}, 'REVIEW')
    assert result == dict(status='SUCCESS', action='ACCEPT', reason='ação ✓', evidenceRefs=[])


@pytest.mark.parametrize('raw', ['', 'x' * 16385])
def test_model_output_size_limit(raw):
    with pytest.raises(DecisionError, match='CANDIDATE_SIZE_INVALID'):
        parse_candidate(raw)


@pytest.mark.parametrize('group,units,expected', [('O+', 5, 'B'), ('A+', 5, 'C'), ('O+', 20, 'REVIEW')])
def test_inventory_and_routing(group, units, expected):
    assert validate_stock_request(group, units, 'LIVE', 'correlation') == units
    assert recommend(group, units) == expected
    assert snapshot(group)['synthetic'] is True


@pytest.mark.parametrize('units', [True, 0, -1, 101, 1.5, float('nan'), float('inf'), 'bad'])
def test_quantity_constraints(units):
    with pytest.raises(DecisionError, match='UNITS_INVALID'):
        validate_stock_request('O+', units, 'SIMULATION', 'correlation')
