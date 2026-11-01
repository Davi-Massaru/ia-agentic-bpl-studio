"""Contract, generation and parser regressions; no native execution claims."""
import copy
import importlib.util
import json
import sys
from pathlib import Path
from types import SimpleNamespace
import xml.etree.ElementTree as ET

import pytest
from studio.native.bpl import parse
from studio import create_app


@pytest.fixture
def workspace(monkeypatch):
    monkeypatch.setitem(sys.modules, 'iris', SimpleNamespace(cls=lambda _: None))
    spec = importlib.util.spec_from_file_location('visual_workspace', Path(__file__).parents[1] / 'backend/studio/native/workspace.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def binding(identifier='w:decision'):
    return dict(bindingId=identifier, agentRef=dict(id='review', revision=1),
                inputs=[dict(source='request.EventId', target='eventId', required=True)],
                outputs=dict(action='context.Action'), routes=dict(ACCEPT='Accept', REVIEW='Review'),
                fallback=dict(action='REVIEW', target='Review'), timeouts=dict(agentMs=30000))


def test_multipoint_generation_pins_identity_and_stops_after_failure(workspace):
    first, second = binding(), binding('w:second')
    root = ET.fromstring(workspace.workflow_xml([first, second]))
    calls = [n for n in root.iter('call') if n.get('target') == 'AgentDecision']
    assert len(calls) == 2
    assert [c.find("request/assign[@property='callrequest.BindingId']").get('value') for c in calls] == ['"w:decision"', '"w:second"']
    guarded = root.find("sequence/if[@name='Continue after success 1']/true/call")
    assert guarded is calls[1]
    assert 'context.Action,context.Reason' in calls[1].find("request/assign[@property='callrequest.InputJson']").get('value')
    assert workspace.workflow_xml([first]) == workspace.xml(first)


def test_legacy_normalization_does_not_mutate_snapshot(workspace, monkeypatch):
    document = {'binding': binding()}
    before = copy.deepcopy(document)
    assert workspace.bindings_of(document) == [document['binding']]
    assert document == before and 'bindings' not in document
    workflow = dict(document, workflowId='w', className='', source=workspace.xml(binding()), baseHash='base', revision=1, managed=True)
    monkeypatch.setattr(workspace, 'get', lambda _: workflow)
    monkeypatch.setattr(workspace, 'read', lambda key, default=None: 'old' if key == 'active:w' else document)
    monkeypatch.setattr(workspace, 'validate', lambda _: {'valid': True})
    monkeypatch.setattr(workspace, 'dependencies', lambda _: {})
    assert workspace.handle('preview_publish', {'workflowId': 'w'})['bindingDiff'] == ''


def test_opaque_bpl_does_not_invent_loop_body_edges():
    graph = json.loads(parse('<process><sequence><while><call target="Unknown"/></while><assign property="x"/></sequence></process>'))
    assert graph['nodes'][0]['opaque'] is True
    assert not any(n['target'] == 'Unknown' for n in graph['nodes'])
    assert not graph['recognized']


def test_if_branches_merge_without_cross_branch_edges():
    graph = json.loads(parse('<process><sequence><if><true><call target="A"/></true><false><call target="B"/></false></if></sequence></process>'))
    a, b = [n['id'] for n in graph['nodes'] if n['target'] in ('A', 'B')]
    assert not any(e['source'] == a and e['target'] == b for e in graph['edges'])
    assert any(n['kind'] == 'merge' for n in graph['nodes'])


@pytest.mark.parametrize('source', ['<!DOCTYPE x><process/>', '<process>', '<source-too-large/>'])
def test_invalid_source_is_read_only(source):
    result = json.loads(parse(source))
    assert not result['recognized'] and not result['nodes']


@pytest.mark.parametrize('source', ['x' * 1000001, '<process>' + '<scope>' * 66 + '</scope>' * 66 + '</process>'], ids=['oversized', 'deep'])
def test_large_or_deep_source_has_explicit_limit(source):
    result = json.loads(parse(source))
    assert not result['nodes'] and 'exceeds' in result['reason']


def test_atomic_save_rejects_duplicate_foreign_and_stale_points(workspace, monkeypatch):
    document = dict(workflowId='w', binding=binding(), bindings=[binding()], managed=True, bindingRevision=3, revision=4, requestClass='Studio.Msg.WorkflowRequest')
    monkeypatch.setattr(workspace, 'get', lambda _: copy.deepcopy(document))
    monkeypatch.setattr(workspace, 'validate', lambda _: {'valid': True})
    monkeypatch.setattr(workspace, 'append', lambda value: value)
    for blocks, revision, code in [([binding(), binding()], 3, 'INVALID_POINT_ID'),
                                  ([binding('other:p')], 3, 'INVALID_POINT_ID'),
                                  ([binding()], 2, 'BINDING_REVISION_CONFLICT'),
                                  ([], 3, 'INVALID_BINDINGS'),
                                  ([binding('w:p' + str(i)) for i in range(9)], 3, 'INVALID_BINDINGS')]:
        with pytest.raises(workspace.Failure) as error:
            workspace.handle('save_bindings', dict(workflowId='w', bindings=blocks, expectedRevision=revision))
        assert error.value.code == code
    result = workspace.handle('save_bindings', dict(workflowId='w', bindings=[binding(), binding('w:second')], expectedRevision=3))
    assert result['bindingRevision'] == 4 and result['revision'] == 5
    assert len(document['bindings']) == 1


def test_binding_collection_http_boundary():
    calls = []
    gateway = SimpleNamespace(save_bindings=lambda *args, **kwargs: calls.append((args, kwargs)) or {'saved': True})
    client = create_app(dict(TESTING=True, IRIS_GATEWAY=gateway, STUDIO_AUTHENTICATE=lambda _: 'user',
                             STUDIO_AUTHORIZE=lambda *_: True, STUDIO_CSRF_VALIDATE=lambda *_: True)).test_client()
    url = '/api/v1/workflows/w/bindings'
    assert client.put(url, json={'bindings': [binding()]}).status_code == 428
    assert client.put(url, json={'bindings': []}, headers={'If-Match': '"1"'}).status_code == 422
    assert not calls
    assert client.put(url, json={'bindings': [binding()]}, headers={'If-Match': '"1"'}).status_code == 200
    assert calls[0][0] == ('w', [binding()], 1)
