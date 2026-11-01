"""Stock MVP acceptance through native IRIS; synthetic inventory only.

Uses the provider credential already stored in IRIS Wallet. Never reads an API key.
Running this script invokes the configured model and may incur provider charges.
"""
import argparse
import base64
from datetime import datetime, timezone
import json
from pathlib import Path
import re
from urllib.error import HTTPError
from urllib.request import Request, urlopen
import uuid

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--confirm-live', action='store_true')
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


report=json.loads((root/'validation/blood-live.json').read_text())
checks=[]
for group,units,action in [('O+',5,'C'),('A+',5,'B'),('O+',20,'B')]:
    run=call('test-runs', {'releaseId':report['releaseId'],'mode':'live','payload':{'Mode':'SIMULATION','EventId':'policy-negative','BloodGroup':group,'Units':units,'CandidateJson':json.dumps({'action':action,'reason':'Deliberately invalid stock choice','evidenceRefs':[]})}},expected=202)
    trace=call('runs/'+run['executionId']); checks.append(trace)
    assert trace['mode']=='SIMULATION' and trace.get('usage',{}).get('providerInvoked') is False
    assert trace['status']=='INVALID' and trace['errorCode']=='STOCK_POLICY_REJECTED' and trace['destination']=='StockReview'
(root/'validation/blood-policy.json').write_text(json.dumps({'ok':True,'runs':checks},indent=2))
print('PASS: three policy violations rejected and routed to StockReview; no provider calls.')

