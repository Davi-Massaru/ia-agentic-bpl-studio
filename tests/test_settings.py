from studio import create_app


class SettingsGateway:
    def __init__(self):
        self.saved = None

    def get_settings(self, *, principal):
        assert principal == 'studio'
        return {'provider': '', 'model': '', 'hasCredential': False, 'configured': False}

    def save_settings(self, payload, *, principal):
        self.saved = payload
        return {'provider': payload['provider'], 'model': payload['model'],
                'hasCredential': bool(payload.get('apiKey')), 'configured': False}


def client():
    gateway = SettingsGateway()
    app = create_app({'TESTING': True, 'IRIS_GATEWAY': gateway,
                      'STUDIO_AUTHENTICATE': lambda request: 'studio',
                      'STUDIO_AUTHORIZE': lambda principal, action: True,
                      'STUDIO_CSRF_VALIDATE': lambda request, principal: request.headers.get('X-CSRF-Token') == 'test-token'})
    return app.test_client(), gateway


def test_settings_read_does_not_return_credentials():
    c, gateway = client()
    data = c.get('/api/v1/settings').get_json()
    assert data['hasCredential'] is False
    assert 'apiKey' not in data


def test_credential_submission_requires_csrf_and_is_never_echoed():
    c, gateway = client()
    payload = {'provider': 'openai', 'model': 'test-model', 'apiKey': 'test-only-not-a-real-key'}
    assert c.put('/api/v1/settings', json=payload).status_code == 403
    assert gateway.saved is None
    result = c.put('/api/v1/settings', json=payload, headers={'X-CSRF-Token': 'test-token'})
    assert result.status_code == 200
    assert gateway.saved['apiKey'] == payload['apiKey']
    assert payload['apiKey'] not in result.get_data(as_text=True)


def test_settings_rejects_unknown_destination_and_malformed_credentials():
    c, gateway = client()
    for payload in [
        {'provider': 'other', 'model': 'test-model'},
        {'provider': 'openai', 'model': 'test-model', 'endpoint': 'http://unapproved.invalid'},
        {'provider': 'openai', 'model': 'test-model', 'apiKey': {'secret': 'invalid'}},
        {'provider': 'openai', 'model': 'test-model', 'apiKey': 'invalid\ncredential'}
    ]:
        assert c.put('/api/v1/settings', json=payload, headers={'X-CSRF-Token': 'test-token'}).status_code == 422
    assert gateway.saved is None


def test_all_existing_screens_offer_the_same_settings_dialog():
    c = create_app({'TESTING': True}).test_client()
    for path in ['/', '/designer', '/test-trace', '/publisher']:
        html = c.get(path).get_data(as_text=True)
        assert 'id="studio-settings"' in html
        assert 'id="settings-api-key"' in html
        assert 'type="password"' in html
        assert 'id="settings-title">Settings' in html
        assert 'Saving does not call the model.' in html
        assert 'placeholder="Model identifier" required autocomplete="off"' in html
        assert 'Leave the credential blank to keep a saved key' in html
