"""Publish two example AI Hub Operations after the blood Getting Started walkthrough.

Configuration only: no model invocation. Existing host names are rejected.
Uses local Studio credentials; never reads the provider key.
"""
import base64
import json
from pathlib import Path
import re
from urllib.error import HTTPError
from urllib.request import Request, urlopen

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



stock=json.loads((root/'validation/blood-live.json').read_text())
components=[]
for name,agent,actions,policy in [('AIStockAdvisor',stock['agentId'],['B','C','REVIEW'],'blood-stock'),('AIEventReviewer','event-review',['ACCEPT','REVIEW'],'schema')]:
    result=call('components',{'production':'Studio.BloodDemo.Production','hostName':name,'agentId':agent,'agentRevision':1,'allowedActions':actions,'fallbackAction':'REVIEW','policy':policy},expected=201)
    components.append(result)
    print(json.dumps({k:result.get(k) for k in ('componentId','hostName','installed','activated')}))
(root/'validation/native-components.json').write_text(json.dumps({'components':components},indent=2))
