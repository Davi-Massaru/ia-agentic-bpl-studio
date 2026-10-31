"""Publication boundaries without an IRIS instance or provider calls."""
import importlib.util
import json
from pathlib import Path
import sys
from types import SimpleNamespace

import pytest


@pytest.fixture
def workspace(monkeypatch):
    monkeypatch.setitem(sys.modules, 'iris', SimpleNamespace(
        cls=lambda name: SimpleNamespace(IsError=lambda status: False)))
    path = Path(__file__).parents[1] / 'backend/studio/native/workspace.py'
    spec = importlib.util.spec_from_file_location('portable_workspace_test', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    monkeypatch.setattr(module, 'hosts', lambda production: [])
    monkeypatch.setattr(module, 'agent', lambda binding: {'toolSetRefs': []})
    return module


def config(**changes):
    return dict(dict(production='Example.Production', hostName='AgentOne',
                     agentId='review', agentRevision=1,
                     allowedActions=['ACCEPT', 'REVIEW'], fallbackAction='REVIEW',
                     policy='schema'), **changes)


@pytest.mark.parametrize('changes,code', [
    ({'hostName': 'unsafe.host'}, 'INVALID_HOST'),
    ({'agentRevision': True}, 'INVALID_REVISION'),
    ({'allowedActions': ['ACCEPT', 'ACCEPT']}, 'INVALID_ACTIONS'),
    ({'allowedActions': ['arbitrary code']}, 'INVALID_ACTIONS'),
    ({'fallbackAction': 'UNKNOWN'}, 'INVALID_POLICY'),
    ({'policy': 'blood-stock'}, 'INVALID_STOCK_POLICY'),
    ({'releaseId': 'not-required'}, 'INVALID_COMPONENT'),
])
def test_invalid_components_never_stage(workspace, monkeypatch, changes, code):
    def forbidden():
        pytest.fail('Invalid configuration reached native compilation')
    monkeypatch.setattr(workspace, 'W', forbidden)
    with pytest.raises(workspace.Failure) as error:
        workspace.publish_component(config(**changes))
    assert error.value.code == code


def test_existing_host_is_preserved(workspace, monkeypatch):
    monkeypatch.setattr(workspace, 'hosts', lambda _: [{'name': 'AgentOne'}])
    with pytest.raises(workspace.Failure) as error:
        workspace.publish_component(config())
    assert error.value.code == 'HOST_EXISTS'


def test_component_pins_agent_without_managed_release(workspace, monkeypatch):
    store, installed = {}, []
    monkeypatch.setattr(workspace, 'read', lambda key, default=None: store.get(key, default))
    monkeypatch.setattr(workspace, 'write', lambda key, value: store.update({key: value}))
    def install(*args):
        installed.append(args)
        return json.dumps({'installed': True, 'activated': True})
    monkeypatch.setattr(workspace, 'W', lambda: SimpleNamespace(
        StageComponent=lambda _: 1, Install=install))
    result = workspace.publish_component(config())
    assert result['agentRevision'] == 1
    assert 'releaseId' not in result
    assert store['components'] == [result['componentId']]
    assert installed == [('Example.Production', 'AgentOne', result['className'])]
    monkeypatch.setattr(workspace, 'ids', lambda: [])
    restored = json.loads(workspace.reconcile())
    assert restored[0]['componentId'] == result['componentId']
    assert len(installed) == 2
