"""Real browser + authenticated local IRIS regression; never invokes a provider.

Run with the project venv and Playwright installed. Creates isolated test agents
and a managed draft in the synthetic BloodDemo Production; does not publish.
When a native validation receipt exists, sends one explicit SIMULATION message
to that synthetic release to verify the per-point trace UI.
"""
import copy
import json
import time
import uuid
from pathlib import Path

from playwright.sync_api import sync_playwright, expect

ROOT = Path(__file__).resolve().parents[1]
BASE = 'http://127.0.0.1:52773/csp/studio/'


def main():
    auth = json.loads((ROOT / '.local/studio-auth.json').read_text(encoding='utf-8-sig'))
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(channel='msedge', headless=True)
        context = browser.new_context(http_credentials={k: auth[k] for k in ('username', 'password')},
                                      viewport={'width': 1600, 'height': 1000})
        page = context.new_page()
        errors = []
        page.on('pageerror', lambda error: errors.append(str(error)))
        page.goto(BASE + 'designer', wait_until='networkidle')
        expect(page.locator('.block-workspace > .inspector')).to_have_count(1)
        expect(page.locator('.native-structure')).to_have_count(1)
        token = page.locator('meta[name="csrf-token"]').get_attribute('content')

        def api(path, data=None, method='GET', headers=None):
            response = context.request.fetch(BASE + 'api/v1/' + path, method=method, data=data,
                headers={'X-CSRF-Token': token, **(headers or {})})
            assert response.ok, (path, response.status, response.text()[:500])
            return response.json()

        agent_id = 'visual-ui-' + uuid.uuid4().hex[:12]
        original = next(a for a in api('agents') if a['agentId'] == 'event-review')
        definition = {k: original[k] for k in ('providerRef', 'modelName', 'prompt', 'toolSetRefs')}
        api('agents/' + agent_id, {'definition': definition, 'baseRevision': 0}, 'PUT')
        definition['prompt'] += '\nUse the configured decision contract.'
        api('agents/' + agent_id, {'definition': definition, 'baseRevision': 1}, 'PUT')
        workflow = api('workflows', {'templateId': 'decision-routing-v1', 'production': 'Studio.BloodDemo.Production'}, 'POST')
        first = workflow['binding']
        first.update(agentRef={'id': agent_id, 'revision': 1}, routes={'ACCEPT': 'StockCenterB', 'REVIEW': 'StockReview'}, fallback={'action': 'REVIEW', 'target': 'StockReview'})
        second = copy.deepcopy(first)
        second['bindingId'] = workflow['workflowId'] + ':second'
        second['agentRef']['revision'] = 2
        path = 'workflows/' + workflow['workflowId']
        api(path + '/bindings', {'bindings': [first, second]}, 'PUT', {'If-Match': '"1"'})
        started = time.perf_counter()
        page.goto(BASE + 'designer?workflow=' + workflow['workflowId'], wait_until='networkidle')
        expect(page.locator('.decision-brick')).to_have_count(2)
        load_ms = round((time.perf_counter() - started) * 1000)
        expect(page.locator('#designer-production')).to_have_value('Studio.BloodDemo.Production')
        page.locator('#agent-search').fill(agent_id)
        agent = page.locator('.agent-brick').filter(has_text=agent_id + ' @2')
        page.locator('.block-workspace').scroll_into_view_if_needed()
        agent.hover()
        origin = agent.bounding_box()
        target = page.locator('.decision-brick').first.bounding_box()
        page.mouse.down()
        page.mouse.move(origin['x'] + origin['width']/2 + 12, origin['y'] + origin['height']/2, steps=4)
        page.mouse.move(target['x'] + 30, target['y'] + 30, steps=12)
        page.mouse.up()
        if '@2' not in page.locator('.decision-brick').first.locator('.block-title').inner_text():
            page.screenshot(path=str(ROOT / '.tmp/visual-drag-failure.png'), full_page=True)
            print(json.dumps({'draggable':agent.get_attribute('draggable'),'title':agent.get_attribute('title'),'notice':page.locator('#notice').inner_text(),'feedback':page.locator('#block-feedback').inner_text(),'state':page.locator('#draft-state').inner_text(),'errors':errors}))
        expect(page.locator('.decision-brick').first.locator('.block-title')).to_contain_text('@2')
        page.locator('#undo-blocks').click()
        expect(page.locator('.decision-brick').first.locator('.block-title')).to_contain_text('@1')
        page.locator('#redo-blocks').click()
        expect(page.locator('.decision-brick').first.locator('.block-title')).to_contain_text('@2')
        agent.focus()
        page.keyboard.press('Enter')
        page.locator('#append-block').focus()
        page.keyboard.press('Enter')
        expect(page.locator('.decision-brick')).to_have_count(3)
        page.locator('.decision-brick').last.locator('.block-title').click()
        prompt = page.locator('#agent-prompt').input_value()
        page.locator('#agent-prompt').fill(prompt + '\nReturn a concise explanation.')
        page.locator('#undo-blocks').click()
        expect(page.locator('#agent-prompt')).to_have_value(prompt)
        page.locator('#redo-blocks').click()
        expect(page.locator('#agent-prompt')).to_have_value(prompt + '\nReturn a concise explanation.')
        # Agent revision persists, binding fails: retry must not create another revision.
        page.route('**/api/v1/' + path + '/bindings', lambda route: route.fulfill(status=409,
                   content_type='application/json', body=json.dumps({'errorCode': 'TEST_CONFLICT', 'message': 'Injected binding conflict'})), times=1)
        page.locator('#save-blocks').click()
        expect(page.locator('#notice')).to_contain_text('TEST_CONFLICT', timeout=30000)
        expect(page.locator('#agent-revision')).to_have_value('3')
        page.locator('#save-blocks').click()
        expect(page.locator('#notice')).to_contain_text('All blocks saved', timeout=30000)
        saved = api(path)
        assert [b['agentRef']['revision'] for b in saved['bindings']] == [2, 2, 3]
        assert len([a for a in api('agents') if a['agentId'] == agent_id]) == 3
        assert not api(path + '/releases'), 'Dragging or saving must not publish'
        # An unrecognized BPL must not become editable through a visual socket.
        page.goto(BASE + 'designer?workflow=class:Studio.BloodDemo.Routing', wait_until='networkidle')
        expect(page.locator('#append-block')).to_be_disabled()
        expect(page.locator('#save-blocks')).to_be_disabled()
        page.goto(BASE + 'designer?workflow=' + workflow['workflowId'], wait_until='networkidle')
        page.locator('.decision-brick').last.locator('.block-title').click()
        expect(page.locator('#draft-state')).to_contain_text('Saved draft')
        page.screenshot(path=str(ROOT / 'validation/screens/visual-blocks.png'), full_page=True)
        assert not errors, errors
        result = {'ok': True, 'workflowId': workflow['workflowId'], 'loadMs': load_ms,
                  'checks': ['native-auth', 'drag-replace', 'keyboard-append', 'undo-redo', 'prompt-edit',
                             'partial-save-retry', 'pinned-independent-revisions', 'no-auto-publication', 'read-only-bpl'],
                  'providerInvoked': False, 'browser': 'Microsoft Edge / Playwright'}
        receipt = ROOT / 'validation/visual-designer-native.json'
        if receipt.exists():
            native = json.loads(receipt.read_text(encoding='utf-8'))
            execution = api('test-runs', {'releaseId': native['releaseId'], 'mode': 'live', 'payload': {
                'Mode': 'SIMULATION', 'EventId': 'E-OK', 'Description': 'Synthetic trace UI check',
                'CandidateJson': json.dumps({'action': 'ACCEPT', 'reason': 'fixture', 'evidenceRefs': []})}}, 'POST')
            page.goto(BASE + 'test-trace?execution=' + execution['executionId'], wait_until='networkidle')
            expect(page.locator('#run-status')).to_have_text('SUCCESS')
            expect(page.locator('#trace-points > li')).to_have_count(2)
            expect(page.locator('#trace-points')).to_contain_text('@1')
            expect(page.locator('#trace-points')).to_contain_text('@2')
            result['checks'].append('per-point-native-simulation-trace')
            result['executionId'] = execution['executionId']
        assert not errors, errors
        (ROOT / 'validation/visual-designer-browser.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
        print(json.dumps(result))
        browser.close()


if __name__ == '__main__':
    main()
