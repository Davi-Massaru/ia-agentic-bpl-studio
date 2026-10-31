import json
import sys
from types import SimpleNamespace
from studio.native import tracing


def test_hierarchy_redaction_and_failure(monkeypatch):
    class Global(dict):
        def __getitem__(self, key):
            return self.get(key, '')
    audit = Global()
    monkeypatch.setitem(sys.modules, 'iris', SimpleNamespace(gref=lambda name: audit))
    root = tracing.native_start('e', 'workflow', '', 'operation', 'Host')
    child = tracing.native_start('e', 'e', root, 'agent', 'Chat',
                                 '{"model":"m","prompt":"secret","apiKey":"secret"}')
    tracing.native_finish('e', child, 'ERROR')
    tracing.native_finish('e', root, 'ERROR')
    rows = json.loads(audit['e', 'observations'])
    assert rows[1]['traceId'] == 'workflow'
    assert rows[1]['metadata'] == {'model': 'm'}
    assert all(row['durationMs'] >= 0 and row['status'] == 'ERROR' for row in rows)
    assert 'secret' not in audit['e', 'observations']


def test_recording_failure_does_not_break_business(monkeypatch):
    monkeypatch.setitem(sys.modules, 'iris', SimpleNamespace(gref=lambda _: 1/0))
    assert tracing.native_start('e', 'e', '', 'agent', 'Chat') == ''
    assert tracing.native_finish('e', 'id', 'ERROR') is None
