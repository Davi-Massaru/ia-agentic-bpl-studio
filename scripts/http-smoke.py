"""Local authenticated end-to-end check. Creates a sandbox draft/release; no provider calls."""
import os
import base64
import json
import re
import uuid
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError

root = Path(__file__).resolve().parents[1]
credentials = json.loads((root / '.local/studio-auth.json').read_text(encoding='utf-8-sig'))
auth = base64.b64encode((credentials['username'] + ':' + credentials['password']).encode()).decode()
base = 'http://127.0.0.1:52773/csp/studio/'
headers = {'Authorization': 'Basic ' + auth}
with urlopen(Request(base, headers=headers), timeout=30) as response:
    html = response.read().decode()
headers['X-CSRF-Token'] = re.search(r'name="csrf-token" content="([^"]+)"', html)[1]


def call(path, data=None, method=None, extra=None, expected=200):
    req = Request(base + 'api/v1/' + path, data=json.dumps(data).encode() if data is not None else None,
                  headers={**headers, 'Content-Type': 'application/json', **(extra or {})}, method=method)
    try:
        response = urlopen(req, timeout=60)
    except HTTPError as exc:
        response = exc
    with response:
        raw = response.read()
        try:
            result = json.loads(raw)
        except ValueError:
            (root / '.local/http-error.txt').write_bytes(raw)
            raise AssertionError('Non-JSON native response; private diagnostic .local/http-error.txt') from None
        assert response.status == expected, (path, response.status, result.get('errorCode'))
        return result


assert call('templates')
w = call('workflows', {'templateId': 'decision-routing-v1', 'production': os.environ.get('STUDIO_TEST_PRODUCTION', 'Studio.Demo.Production')}, expected=201)
wid = w['workflowId']
path = 'workflows/' + wid
w = call(path + '/decision-slot', {'expectedRevision': w['revision']})
preview = call(path + '/preview-input', {'binding': w['binding'], 'example': {'EventId': 'E-OK', 'Description': 'synthetic'}})
assert preview['valid']
assert 'synthetic' not in json.dumps(preview)
validation = call(path + '/validate', {}, 'POST')
assert validation['valid'], validation
assert call(path + '/preview', {}, 'POST')['diff']
publish = {'draftRevision': w['revision'], 'approvalRef': 'local-http-smoke', 'confirmed': True}
extra = {'If-Match': '"' + w['baseHash'] + '"', 'Idempotency-Key': uuid.uuid4().hex}
r = call(path + '/publish', publish, extra=extra, expected=201)
assert r['compiled'] and r['installed'] and r['activated']
assert call(path + '/publish', publish, extra=extra, expected=201) == r
run = call('test-runs', {'releaseId': r['releaseId'], 'mode': 'live', 'payload': {
    'Mode': 'SIMULATION', 'EventId': 'E-OK', 'Description': 'Synthetic HTTP fixture',
    'CandidateJson': json.dumps({'action': 'ACCEPT', 'reason': 'Synthetic fixture'})}}, expected=202)
trace = call('runs/' + run['executionId'])
assert trace['mode'] == 'SIMULATION' and trace['status'] == 'SUCCESS'
assert trace['destination'] == 'AcceptOperation' and trace['messageId']
w = call(path)
rollback = call(path + '/rollback', {'releaseId': r['releaseId'], 'expectedRevision': w['revision']})
assert rollback['revision'] == w['revision'] + 1
call(path + '/rollback', {'releaseId': r['releaseId'], 'expectedRevision': w['revision']}, expected=409)
w = rollback
w['binding']['timeouts']['agentMs'] = 1000
w = call('bindings/' + w['binding']['bindingId'], w['binding'], method='PUT',
         extra={'If-Match': '"' + str(w['bindingRevision']) + '"'})
deadline_release = call(path + '/publish', {'draftRevision': w['revision'], 'approvalRef': 'local-deadline-smoke', 'confirmed': True},
                        extra={'If-Match': '"' + w['baseHash'] + '"', 'Idempotency-Key': uuid.uuid4().hex}, expected=201)
deadline_run = call('test-runs', {'releaseId': deadline_release['releaseId'], 'mode': 'live', 'payload': {
    'Mode': 'SIMULATION', 'EventId': 'E-OK', 'Description': 'Synthetic delayed fixture', 'SimulationFault': 'DELAY',
    'CandidateJson': json.dumps({'action': 'ACCEPT', 'reason': 'Delayed synthetic fixture'})}}, expected=202)
deadline_trace = call('runs/' + deadline_run['executionId'])
assert deadline_trace['status'] == 'TIMEOUT' and deadline_trace['destination'] == 'ReviewOperation'
assert deadline_trace['messageId'] and deadline_trace['mode'] == 'SIMULATION'
evidence = {'ok': True, 'workflowId': wid, 'releaseId': r['releaseId'], 'trace': trace,
            'authenticatedHTTP': True, 'liveAIValidated': False, 'rollbackDraftRevision': rollback['revision'],
            'nativeDeadlineTrace': deadline_trace, 'deadlineMs': 1000, 'injectedDelayMs': 2000}
(root / 'validation/http-generic.json').write_text(json.dumps(evidence, indent=2), encoding='utf-8')
print('Authenticated HTTP: create, slot, redacted preview, publish, idempotency, native simulation, rollback, real BPL deadline PASS.')
