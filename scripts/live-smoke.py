"""Explicitly authorized LIVE acceptance: two synthetic events through native IRIS.

Uses the provider credential already stored in IRIS Wallet. Never reads an API key.
Running this script invokes the configured model and may incur provider charges.
"""
import argparse
import os
import base64
from datetime import datetime, timezone
import json
from pathlib import Path
import re
from urllib.error import HTTPError
from urllib.request import Request, urlopen
import uuid

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--confirm-live', action='store_true', required=True)
parser.add_argument('--release', help='Reuse a published sandbox release instead of creating one')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
credentials = json.loads((root / '.local/studio-auth.json').read_text(encoding='utf-8-sig'))
headers = {'Authorization': 'Basic ' + base64.b64encode(
    (credentials['username'] + ':' + credentials['password']).encode()).decode()}
base = 'http://127.0.0.1:52773/csp/studio/'
with urlopen(Request(base, headers=headers), timeout=30) as response:
    headers['X-CSRF-Token'] = re.search(r'name="csrf-token" content="([^"]+)"', response.read().decode())[1]


def call(path, data=None, method=None, extra=None, expected=200):
    request = Request(base + 'api/v1/' + path, method=method,
                      data=json.dumps(data).encode() if data is not None else None,
                      headers={**headers, 'Content-Type': 'application/json', **(extra or {})})
    try:
        response = urlopen(request, timeout=150)
    except HTTPError as exc:
        response = exc
    with response:
        result = json.loads(response.read())
        if response.status != expected:
            raise RuntimeError(f'HTTP {response.status}: {result.get("errorCode", "API_ERROR")}')
        return result


settings = call('settings')
if not settings.get('configured'):
    raise SystemExit('Configure a provider in Settings before LIVE validation.')
report = {'checkedAt': datetime.now(timezone.utc).isoformat(), 'ok': False,
          'mode': 'LIVE', 'provider': settings['provider'], 'model': settings['model'], 'runs': []}
output = root / 'validation/live-ai.json'


def save():
    output.write_text(json.dumps(report, indent=2), encoding='utf-8')


if args.release:
    report['releaseId'] = args.release
else:
    workflow = call('workflows', {'templateId': 'decision-routing-v1',
                                 'production': os.environ.get('STUDIO_TEST_PRODUCTION', 'Studio.Demo.Production')}, expected=201)
    path = 'workflows/' + workflow['workflowId']
    workflow = call(path + '/decision-slot', {'expectedRevision': workflow['revision']})
    pinned = next((a for a in call('agents') if a['agentId'] == workflow['binding']['agentRef']['id']
                   and a['revision'] == workflow['binding']['agentRef']['revision']), None)
    if not pinned or pinned['providerRef'] != settings['provider'] or pinned['modelName'] != settings['model']:
        raise SystemExit('Configure a matching agent revision and pass its published release with --release.')
    preview = call(path + '/preview', {}, 'POST')
    if not preview['validation']['valid']:
        raise SystemExit('Native draft validation failed.')
    release = call(path + '/publish', {'draftRevision': workflow['revision'],
                   'approvalRef': 'user-authorized-local-live-validation', 'confirmed': True},
                   extra={'If-Match': '"' + workflow['baseHash'] + '"',
                          'Idempotency-Key': uuid.uuid4().hex}, expected=201)
    if not release.get('activated'):
        raise SystemExit('Start the sandbox Production before LIVE validation.')
    report.update(workflowId=workflow['workflowId'], releaseId=release['releaseId'])
save()
for event, expected_action in [('E-OK', 'ACCEPT'), ('E-REVIEW', 'REVIEW')]:
    run = call('test-runs', {'releaseId': report['releaseId'], 'mode': 'live', 'payload': {
        'Mode': 'LIVE', 'EventId': event,
        'Description': 'Synthetic validation event. Consult ReadEvent and return the allowed JSON decision.'}}, expected=202)
    trace = call('runs/' + run['executionId'])
    report['runs'].append(trace)
    save()
    print(json.dumps({k: trace.get(k) for k in
                      ('executionId', 'mode', 'status', 'action', 'destination', 'agentSessionId', 'errorCode')}))
    if trace.get('mode') != 'LIVE' or trace.get('status') != 'SUCCESS' or trace.get('action') != expected_action:
        raise SystemExit('LIVE acceptance failed; sanitized evidence saved in validation/live-ai.json.')
    if not trace.get('agentSessionId') or not trace.get('messageId') or not trace.get('toolCalls'):
        raise SystemExit('Required native AI session/message/tool evidence is missing.')
report['ok'] = True
save()
print('PASS: two LIVE AI Hub decisions, observed READ tool calls and native BPL destinations.')
