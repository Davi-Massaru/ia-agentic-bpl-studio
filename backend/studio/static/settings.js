(() => {
  'use strict';
  const dialog = document.getElementById('studio-settings');
  const form = document.getElementById('settings-form');
  const status = document.getElementById('settings-status');
  const key = document.getElementById('settings-api-key');
  const api = document.body.dataset.api;
  let savedProvider = '';
  async function request(method, payload) {
    const headers = {'Accept': 'application/json'};
    if (payload) {
      headers['Content-Type'] = 'application/json';
      headers['X-CSRF-Token'] = document.querySelector('meta[name="csrf-token"]').content;
    }
    const response = await fetch(api + '/settings', {method, headers,
      credentials: 'same-origin', cache: 'no-store', body: payload ? JSON.stringify(payload) : undefined});
    const data = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error((data.errorCode || 'HTTP_' + response.status) + ': ' + (data.message || 'Settings unavailable.'));
    return data;
  }
  function populate(data) {
    savedProvider = data.provider || '';
    form.elements.provider.value = savedProvider;
    form.elements.model.value = data.model || '';
    key.value = '';
    document.getElementById('settings-credential-state').textContent = data.hasCredential
      ? (data.connectionTested ? 'Credential stored in Wallet. LIVE execution verified in a native IRIS trace.' : 'Credential stored in Wallet. Model connection has not been tested.')
      : 'No credential configured. You can enter one at any time.';
  }
  async function open() {
    if (!dialog.open) dialog.showModal();
    status.textContent = 'Loading IRIS settings…';
    try { populate(await request('GET')); status.textContent = ''; }
    catch (error) { status.textContent = error.message; }
  }
  document.getElementById('open-settings').addEventListener('click', open);
  document.getElementById('close-settings').addEventListener('click', () => { key.value = ''; dialog.close(); });
  dialog.addEventListener('cancel', () => { key.value = ''; });
  form.elements.provider.addEventListener('change', () => {
    key.value = '';
    document.getElementById('settings-credential-state').textContent = form.elements.provider.value === savedProvider
      ? 'A saved credential, when present, is preserved if this field is blank.'
      : 'Provider changed. Enter its credential or save only the preference.';
  });
  form.addEventListener('submit', async event => {
    event.preventDefault();
    const button = document.getElementById('save-settings'); button.disabled = true;
    status.textContent = 'Saving in IRIS…';
    const payload = {provider: form.elements.provider.value, model: form.elements.model.value};
    if (key.value) payload.apiKey = key.value;
    try {
      const result = await request('PUT', payload); populate(result);
      status.textContent = result.configured ? 'Configuration saved. No provider call was made. Reload the screen to refresh LIVE availability.'
        : 'Preferences saved. Credential still pending.';
    } catch (error) { status.textContent = error.message; }
    finally { key.value = ''; button.disabled = false; }
  });
  if (new URLSearchParams(location.search).get('settings') === 'open') open();
})();
