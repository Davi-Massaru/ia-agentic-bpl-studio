/* Administrative UI only. The IRIS Business Service/BPL own all message execution. */
(() => {
  'use strict';
  const $ = id => document.getElementById(id);
  const apiBase = document.body.dataset.api;
  const root = document.body.dataset.root || '';
  const page = document.body.dataset.page;
  const state = {capabilities: null, workflow: null, etag: null, valid: false,
    preview: false, agents: [], tools: [], workflows: [], bindingRevision: 0,
    idempotencyKey: null, loadVersion: 0, templates: [], selectedNode: null, loadedWorkflowId: null};
  const json = value => JSON.stringify(value, null, 2);
  const show = (id, value) => { if ($(id)) $(id).textContent = typeof value === 'string' ? value : json(value); };
  const value = id => $(id)?.value.trim() || '';
  const list = data => Array.isArray(data) ? data : Array.isArray(data?.items) ? data.items : [];
  const idOf = obj => typeof obj === 'string' ? obj : obj.workflowId || obj.agentId || obj.releaseId || obj.id || obj.name || '';
  const setDisabled = (id, disabled) => { if ($(id)) $(id).disabled = disabled; };
  const storedId = () => { try { return sessionStorage.getItem(root + ':workflow') || ''; } catch (_) { return ''; } };
  const remember = id => { try { sessionStorage.setItem(root + ':workflow', id); } catch (_) { /* storage is optional */ } };
  const workflowId = () => value('workflow-id');
  const workflowPath = suffix => '/workflows/' + encodeURIComponent(workflowId()) + (suffix || '');
  const notice = (message, failed = false) => {
    const target = $('notice');
    target.textContent = message;
    target.className = failed ? 'warning error' : 'warning';
  };
  async function request(path, options = {}) {
    const headers = {'Accept': 'application/json', ...(options.headers || {})};
    if (options.body !== undefined) headers['Content-Type'] = 'application/json';
    if (options.method && options.method !== 'GET') {
      const token = document.querySelector('meta[name="csrf-token"]')?.content;
      if (token) headers['X-CSRF-Token'] = token;
    }
    const response = await fetch(apiBase + path, {...options, headers, credentials: 'same-origin', cache: 'no-store',
      body: options.body === undefined ? undefined : JSON.stringify(options.body)});
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) {
      const error = new Error((payload.errorCode || 'HTTP_' + response.status) + ': ' + (payload.message || response.statusText));
      error.status = response.status;
      error.correlationId = payload.correlationId;
      throw error;
    }
    return {data: payload, etag: response.headers.get('ETag')};
  }
  const action = callback => async event => {
    if (event) event.preventDefault();
    const button = event?.submitter || (event?.currentTarget?.tagName === 'BUTTON' ? event.currentTarget : null);
    const wasDisabled = button?.disabled;
    if (button) button.disabled = true;
    try { await callback(event); }
    catch (error) {
      notice(error.message + (error.correlationId ? ' · Correlation: ' + error.correlationId : ''), true);
      if (page === 'publisher' && error.status === 409) resetPublication();
    } finally {
      if (button) button.disabled = wasDisabled;
      if (page === 'publisher') updatePublishButton();
      if (page === 'designer') { updateDesignerButtons(); updateBlockButtons(); }
    }
  };
  const on = (id, event, callback) => $(id)?.addEventListener(event, callback);
  function updateDesignerButtons() {
    const loaded = state.workflow && state.loadedWorkflowId === workflowId();
    const editable = loaded && state.workflow.managed === true && !blockSaving;
    for (const id of ['save-binding','save-agent','add-input','add-route','preview-input']) setDisabled(id, !editable);
    setDisabled('validate-workflow', !loaded);
    setDisabled('insert-decision', !editable || state.workflow.decisionSlotAvailable !== true);
  }
  const textElement = (tag, text, className) => {
    const element = document.createElement(tag);
    element.textContent = text;
    if (className) element.className = className;
    return element;
  };
  const parseField = (id, fallback) => {
    try { return JSON.parse(value(id) || fallback); }
    catch (_) { throw new Error('Invalid JSON in field: ' + $(id).previousElementSibling?.textContent); }
  };
  async function capabilities() {
    const {data} = await request('/capabilities');
    state.capabilities = data;
    show('environment-label', [data.namespace || 'Namespace not supplied', data.version || data.build || 'Build not supplied'].join(' · '));
    $('connection-dot').classList.add('connected');
    show('namespace-name', data.namespace || 'Not supplied');
    show('capabilities-data', data);
    show('runtime-metadata', data);
    notice(data.executionEnabled === true ? 'Control plane connected. Execution depends on the release and IRIS policies.'
      : 'Control plane connected. AI execution has not been confirmed by the environment.');
  }
  async function explorer() {
    await capabilities();
    const [productions, templates] = await Promise.all([request('/productions'), request('/templates')]);
    await componentCatalog();
    const data = productions.data;
    state.templates = list(templates.data);
    const templateSelect = $('template');
    templateSelect.replaceChildren(new Option('Select a template', ''));
    for (const item of state.templates) {
      const id = item.templateId || item.id;
      if (id) templateSelect.add(new Option((item.name || id) + ' · v' + (item.version || '1'), id));
    }
    if (templateSelect.options.length === 2) templateSelect.selectedIndex = 1;
    updateTemplate();
    const select = $('production');
    select.replaceChildren(new Option('Select a Production', ''));
    for (const item of list(data)) {
      const name = typeof item === 'string' ? item : item.name || item.production || item.id;
      if (name) select.add(new Option(name, name));
    }
    if (select.options.length === 2) {
      select.selectedIndex = 1;
      await loadWorkflows();
    } else {
      renderWorkflows();
    }
  }
  async function componentCatalog() {
    if (!$('component-agent')) return;
    const [agents, tools] = await Promise.all([request('/agents'), request('/toolsets')]);
    state.componentAgents = list(agents.data);
    $('component-agent').replaceChildren(new Option('Create a new agent', ''));
    state.componentAgents.forEach((agent, i) => $('component-agent').add(new Option(agent.agentId + ' @' + agent.revision, String(i))));
    $('component-tools').replaceChildren();
    for (const tool of list(tools.data)) {
      const name = tool.className || tool.name || tool.id;
      if (name) $('component-tools').add(new Option(name, name));
    }
  }
  on('component-save-agent', 'click', action(async () => {
    const id = value('component-agent-id');
    if (!id) throw new Error('Enter an Agent ID.');
    const {data} = await request('/agents/' + encodeURIComponent(id), {method: 'PUT', body: {
      baseRevision: Number(value('component-base')),
      definition: {providerRef: value('component-provider'), modelName: value('component-model'),
        prompt: value('component-prompt'), toolSetRefs: Array.from($('component-tools').selectedOptions, o => o.value)}}});
    await componentCatalog();
    $('component-agent').value = String(state.componentAgents.findIndex(a => a.agentId === id && a.revision === data.revision));
    $('component-base').value = data.revision;
    notice('Agent revision saved. Publish its Operation into the selected Production.');
  }));
  on('component-publish', 'click', action(async () => {
    const selected = value('component-agent');
    const agent = selected === '' ? null : state.componentAgents[Number(selected)];
    if (!value('production') || !agent) throw new Error('Select a Production and an existing agent revision.');
    const {data} = await request('/components', {method: 'POST', body: {
      production: value('production'), hostName: value('component-host'), agentId: agent.agentId, agentRevision: agent.revision,
      allowedActions: value('component-actions').split(',').map(a => a.trim()), fallbackAction: value('component-fallback'), policy: value('component-policy')}});
    show('component-result', {componentId: data.componentId, operation: data.hostName, className: data.className,
      agent: data.agent.agentId + ' @' + data.agent.revision, installed: data.installed, activated: data.activated,
      nativeCall: {target: data.hostName, requestType: 'Studio.Msg.AgentRequest', input: 'callrequest.InputJson = JSON built from your request/context',
        responseType: 'Studio.Msg.DecisionResponse', outputs: ['Action','Status','Reason','AgentSessionId','DecisionExecutionId'],
        next: 'Map outputs into your BPL context. Route only after checking Status. Configure a Call timeout and fallback.'}});
    notice('AI Hub Operation published. Open the native Production and BPL editor to compose its calls.');
  }));
  async function loadWorkflows() {
    const selected = value('production');
    setDisabled('create-workflow', !selected || !value('template'));
    state.workflows = [];
    if (selected) {
      const {data} = await request('/workflows?production=' + encodeURIComponent(selected));
      state.workflows = list(data);
    }
    renderWorkflows();
  }
  function renderWorkflows() {
    const filter = value('workflow-search').toLowerCase();
    const items = state.workflows.filter(item => [idOf(item), item.className || '', item.name || ''].join(' ').toLowerCase().includes(filter));
    show('workflow-count', items.length + ' processes');
    const tbody = $('workflow-list');
    tbody.replaceChildren();
    for (const item of items) {
      const id = idOf(item);
      const row = document.createElement('tr');
      const title = document.createElement('td');
      title.append(textElement('strong', item.name || id), textElement('small', item.className || id));
      const mode = textElement('td', item.managed === true ? 'Managed' : 'Read-only');
      if (item.readOnlyReason) mode.title = item.readOnlyReason;
      const open = document.createElement('a');
      open.className = 'button-link';
      open.textContent = 'Open →';
      open.href = root + '/designer?workflow=' + encodeURIComponent(id);
      open.addEventListener('click', () => remember(id));
      const cell = document.createElement('td'); cell.append(open);
      row.append(title, textElement('td', String(item.revision ?? '—')), mode, cell);
      tbody.append(row);
    }
    if (!items.length) {
      const cell = textElement('td', 'No process received for this selection.', 'empty');
      cell.colSpan = 4;
      const row = document.createElement('tr'); row.append(cell); tbody.append(row);
    }
  }
  function selectedTools() {
    return Array.from(document.querySelectorAll('#tool-list input:checked')).map(input => input.value);
  }
  function renderTools(selected = []) {
    const target = $('tool-list');
    if (!target) return;
    target.replaceChildren();
    for (const tool of state.tools) {
      const id = tool.className || tool.id || tool.name;
      if (!id) continue;
      const effect = String(tool.effect || tool.access || 'UNKNOWN').toUpperCase();
      const label = document.createElement('label'); label.className = 'tool-card';
      const checkbox = document.createElement('input'); checkbox.type = 'checkbox'; checkbox.value = id;
      checkbox.checked = selected.includes(id); checkbox.disabled = !state.workflow?.managed || effect !== 'READ';
      const description = document.createElement('span');
      description.append(textElement('strong', id), textElement('small', effect + ' · ' + (tool.description || 'No description supplied')));
      label.append(checkbox, description); target.append(label);
    }
    if (!target.children.length) target.append(textElement('p', 'No authorized ToolSet received.', 'empty'));
  }
  function fillAgent(agent) {
    if (!agent) return;
    const index=state.agents.findIndex(item=>item.agentId===(agent.agentId || agent.id) && item.revision===agent.revision);
    if(index>=0 && !Array.from($('agent-select').options).some(option=>option.value===String(index))) $('agent-select').add(new Option(agent.agentId+' @'+agent.revision,String(index)));
    $('agent-select').value=index>=0?String(index):'';
    $('agent-id').value = agent.agentId || agent.id || '';
    $('agent-revision').value = agent.revision || 1;
    $('agent-base-revision').value = agent.latestRevision || agent.revision || 0;
    $('provider-ref').value = agent.providerRef || '';
    $('model-name').value = agent.modelName || '';
    $('agent-prompt').value = agent.prompt || '';
    renderTools(agent.toolSetRefs || []);
  }
  async function designerCatalog() {
    const results = await Promise.allSettled([request('/agents'), request('/toolsets')]);
    state.agents = results[0].status === 'fulfilled' ? list(results[0].value.data) : [];
    state.tools = results[1].status === 'fulfilled' ? list(results[1].value.data) : [];
    const select = $('agent-select');
    select.replaceChildren(new Option('Select an agent', ''));
    state.agents.forEach((agent, index) => select.add(new Option((agent.agentId || agent.id) + ' @' + agent.revision, String(index))));
    renderTools();
    const failure = results.find(result => result.status === 'rejected');
    if (failure) notice('Partial catalog: ' + failure.reason.message, true);
  }
  function updateTemplate() {
    const template = state.templates.find(item => (item.templateId || item.id) === value('template'));
    show('template-description', template?.description || 'Select a template supplied by IRIS.');
    setDisabled('create-workflow', !value('production') || !template);
  }
  function sourceFields() {
    const workflow = state.workflow || {};
    return [...list(workflow.requestFields).map(field => ({...field, source: field.source || 'request.' + field.name})),
      ...list(workflow.contextFields).map(field => ({...field, source: field.source || 'context.' + field.name}))];
  }
  function operationHosts() {
    return list(state.workflow?.hosts).filter(host => {
      const type = String(host.type || host.hostType || host.kind || '').toLowerCase();
      return !type || type.includes('operation') || type === 'bo';
    }).map(host => ({value: host.name || host.id, label: (host.name || host.id) + (host.className ? ' · ' + host.className : '')})).filter(host => host.value);
  }
  function options(select, items, selected, placeholder = 'Select') {
    select.replaceChildren(new Option(placeholder, ''));
    for (const item of items) select.add(new Option(item.label || item.value, item.value));
    if (selected && !Array.from(select.options).some(option => option.value === selected)) {
      const unknown = new Option(selected + ' · unavailable in metadata', selected); unknown.disabled = true; select.add(unknown);
    }
    select.value = selected || '';
  }
  function inputControl(tag, cssClass, label, initial = '') {
    const element = document.createElement(tag); element.className = cssClass;
    element.setAttribute('aria-label', label); element.value = initial; return element;
  }
  function changedBinding() {
    show('input-preview', 'Mapping changed. Request a new IRIS preview.');
    try { show('binding-review', bindingPayload()); }
    catch (_) { show('binding-review', 'Complete the mappings to review the contract.'); }
    if (!renderingBlocks) captureBlocks();
  }
  function addInputRow(mapping = {}) {
    const row = document.createElement('div'); row.className = 'mapping-row input-row';
    const source = inputControl('select', 'input-source', 'Source field');
    const constant = inputControl('input', 'input-constant', 'Text constant value'); constant.maxLength = 247; constant.placeholder = 'Text constant';
    const isConstant = String(mapping.source || '').startsWith('constant:');
    options(source, [...sourceFields().map(field => ({value: field.source, label: field.source + ' · ' + (field.type || 'type not supplied')})), {value:'__constant',label:'Constant · text'}], isConstant ? '__constant' : mapping.source);
    constant.value = isConstant ? mapping.source.slice('constant:'.length) : ''; constant.hidden = !isConstant;
    const target = inputControl('input', 'input-target', 'Field name sent to the agent', mapping.target || '');
    target.placeholder = 'Agent field'; target.maxLength = 64;
    const requiredLabel = textElement('label', '', 'required-label');
    const required = inputControl('input', 'input-required', 'Required field'); required.type = 'checkbox'; required.checked = mapping.required === true;
    requiredLabel.append(required, document.createTextNode('Required'));
    const remove = textElement('button', 'Remove', 'remove-row'); remove.type = 'button';
    remove.addEventListener('click', () => { row.remove(); changedBinding(); });
    source.addEventListener('change', () => { constant.hidden = source.value !== '__constant'; changedBinding(); });
    row.addEventListener('input', changedBinding); row.append(source, constant, target, requiredLabel, remove);
    $('input-mappings').append(row);
  }
  function refreshFallback() {
    const action = value('fallback-action'), target = value('fallback-target');
    const actions = Array.from(document.querySelectorAll('.route-action')).map(input => input.value.trim()).filter(Boolean);
    options($('fallback-action'), [...new Set(actions)].map(item => ({value:item,label:item})), action, 'Select an action');
    options($('fallback-target'), operationHosts(), target, 'Select an Operation');
  }
  function addRouteRow(action = '', host = '') {
    const row = document.createElement('div'); row.className = 'mapping-row route-row';
    const actionInput = inputControl('input', 'route-action', 'Allowed action', action); actionInput.placeholder = 'ACTION'; actionInput.maxLength = 40;
    const select = inputControl('select', 'route-target', 'Target Operation'); options(select, operationHosts(), host, 'Select an Operation');
    const remove = textElement('button', 'Remove', 'remove-row'); remove.type = 'button';
    remove.addEventListener('click', () => { row.remove(); refreshFallback(); changedBinding(); });
    actionInput.addEventListener('change', () => { refreshFallback(); changedBinding(); });
    row.addEventListener('input', changedBinding); row.addEventListener('change', changedBinding);
    row.append(actionInput, select, remove); $('route-mappings').append(row);
  }
  function outputOptions(current, allowEmpty = false) {
    const field = allowEmpty ? 'reason' : 'action';
    const paths = list(state.workflow?.outputPathsByField?.[field]);
    const items = paths.map(path => ({value:path,label:path}));
    // Existing bindings remain visible if metadata was incomplete; saving still
    // requires paths explicitly provided by the native Reader.
    return {items, current, placeholder: allowEmpty ? 'Do not map this field' : 'Select BPL destination'};
  }
  function fillMappingControls(binding) {
    $('input-mappings').replaceChildren(); $('route-mappings').replaceChildren();
    for (const mapping of binding.inputs || []) addInputRow(mapping);
    for (const [action, target] of Object.entries(binding.routes || {})) addRouteRow(action, target);
    const action = outputOptions(binding.outputs?.action), reason = outputOptions(binding.outputs?.reason, true);
    options($('output-action'), action.items, action.current, action.placeholder);
    options($('output-reason'), reason.items, reason.current, reason.placeholder);
    refreshFallback(); $('fallback-action').value = binding.fallback?.action || ''; $('fallback-target').value = binding.fallback?.target || '';
    show('binding-review', binding);
  }
  function decisionNode(node) {
    return node && typeof node === 'object' && (node.kind === 'ai-decision' || node.type === 'AI Decision' || node.id === 'Decision' || node.managedDecision === true);
  }
  function selectNode(node) {
    state.selectedNode = node;
    for (const button of document.querySelectorAll('#workflow-graph button')) button.setAttribute('aria-pressed', String(button.dataset.nodeId === String(node.id || node.name || '')));
    show('node-details', node);
    if (decisionNode(node)) { if (blockState && node.bindingId) chooseBlock(node.bindingId); $('tab-inputs').click(); $('binding-id').focus(); }
  }
  function showGraph(workflow) {
    const nodes = workflow.graph?.nodes || workflow.activities || [];
    const target = $('workflow-graph'); target.replaceChildren();
    state.selectedNode = null;
    for (const [index, rawNode] of nodes.entries()) {
      const node = typeof rawNode === 'string' ? {id:String(index),label:rawNode} : rawNode;
      const label = node.label || node.name || node.id || node.type || 'Activity';
      const card = textElement('li', '', 'graph-node');
      const button = textElement('button', label, 'graph-select'); button.type = 'button'; button.dataset.nodeId = node.id || node.name || '';
      button.setAttribute('aria-pressed', 'false'); button.addEventListener('click', () => selectNode(node));
      card.append(button);
      if (node.type || node.opaque) card.append(textElement('small', node.opaque ? 'Opaque · read-only' : node.type));
      target.append(card);
    }
    const edges = $('workflow-edges'); edges.replaceChildren();
    for (const edge of workflow.graph?.edges || []) edges.append(textElement('li', (edge.source || edge.from) + ' → ' + (edge.target || edge.to) + (edge.label ? ' · ' + edge.label : '') + (edge.kind === 'contains' ? ' · nested mapping' : '')));
    if (!target.children.length) target.append(textElement('li', 'Graph unavailable from the IRIS Reader. Inspect the received source.', 'empty'));
    const decision = nodes.find(decisionNode);
    setDisabled('configure-decision', !decision); setDisabled('insert-decision', workflow.managed !== true || workflow.decisionSlotAvailable !== true);
    if (decision) selectNode(decision);
    show('workflow-source', workflow.source || workflow.bpl || 'Source unavailable from the Reader.');
  }
  async function loadDesigner() {
    if (page === 'designer' && blocksDirty() && !confirm('Discard local block changes?')) {
      $('workflow-id').value=state.loadedWorkflowId || '';
      $('designer-process').value=state.loadedWorkflowId || '';
      updateDesignerButtons(); updateBlockButtons(); return;
    }
    const id = workflowId();
    if (!id) throw new Error('Enter a workflow.');
    const loadVersion = ++state.loadVersion;
    blockState = null;
    state.workflow = null; state.loadedWorkflowId = null;
    setDisabled('save-binding', true); setDisabled('save-agent', true); setDisabled('validate-workflow', true);
    const {data, etag} = await request(workflowPath());
    if (loadVersion !== state.loadVersion || workflowId() !== id) return;
    state.workflow = data; state.loadedWorkflowId = id; state.etag = etag; remember(id);
    show('workflow-title', data.className || id);
    show('workflow-revision', 'Revision ' + (data.revision ?? '—'));
    show('editability', data.managed === true ? 'Managed' : 'Read-only');
    show('readonly-reason', data.managed === true ? 'Edit only the managed decision binding.' : data.readOnlyReason || 'Unrecognized structure. Editing is blocked.');
    showGraph(data);
    show('input-metadata', {requestClass:data.requestClass, fields:data.requestFields || data.inputMetadata || data.requestProperties || [], context:data.contextFields || []});
    const binding = data.binding || {};
    $('binding-id').value = binding.bindingId || '';
    state.bindingRevision = data.bindingRevision ?? binding.revision ?? 0;
    $('binding-revision').value = state.bindingRevision;
    fillMappingControls(binding);
    const example = data.exampleRequest || {};
    $('input-example').value = json(example);
    show('input-preview', 'No preview requested.');
    $('agent-id').value = binding.agentRef?.id || '';
    $('agent-revision').value = binding.agentRef?.revision || 1;
    $('agent-timeout').value = binding.timeouts?.agentMs || 30000;
    const agent = state.agents.find(item => (item.agentId || item.id) === binding.agentRef?.id && item.revision === binding.agentRef?.revision);
    if (agent) fillAgent(agent);
    else { $('agent-base-revision').value = 0; $('provider-ref').value = ''; $('model-name').value = ''; $('agent-prompt').value = ''; renderTools(); }
    document.querySelectorAll('.inspector input, .inspector textarea, .inspector select').forEach(element => element.disabled = data.managed !== true);
    $('session-policy').disabled = true;
    for (const id of ['add-input','add-route','preview-input']) setDisabled(id, data.managed !== true);
    document.querySelectorAll('.remove-row').forEach(button => button.disabled = data.managed !== true);
    const timeout = data.runtimeLimits?.agentMs || data.runtime?.agentMs;
    $('agent-timeout').min = 1000; $('agent-timeout').max = 300000;
    if (typeof timeout === 'number') { $('agent-timeout').min = timeout; $('agent-timeout').max = timeout; }
    if (timeout && typeof timeout === 'object') {
      $('agent-timeout').min = timeout.min || 1000; $('agent-timeout').max = timeout.max || 300000;
    }
    show('runtime-metadata', data.runtimeLimits || data.runtime || state.capabilities);
    renderTools(agent?.toolSetRefs || []);
    setDisabled('save-binding', data.managed !== true); setDisabled('save-agent', data.managed !== true);
    setDisabled('validate-workflow', false);
    show('designer-result', data);
    initializeBlocks(data);
    if (data.production && $('designer-production')) {
      $('designer-production').value=data.production;
      const select=$('designer-process');
      if(!Array.from(select.options).some(o=>o.value===id)) select.add(new Option(data.hostName || data.className || id,id));
      select.value=id;
    }
    notice('Workflow loaded from IRIS.');
  }
  function bindingPayload() {
    if (state.workflow?.managed !== true) throw new Error('Read-only workflow.');
    const available = new Set(sourceFields().map(field => field.source));
    const inputs = Array.from(document.querySelectorAll('#input-mappings .input-row')).map(row => {
      const selected = row.querySelector('.input-source').value;
      const source = selected === '__constant' ? 'constant:' + row.querySelector('.input-constant').value : selected;
      if (!source.startsWith('constant:') && !available.has(source)) throw new Error('Select a property supplied by the Dictionary.');
      const target = row.querySelector('.input-target').value.trim();
      if (!/^[A-Za-z][A-Za-z0-9_]{0,63}$/.test(target)) throw new Error('Enter a valid agent field name.');
      return {source, target, required:row.querySelector('.input-required').checked};
    });
    if (!inputs.length || inputs.length > 40) throw new Error('Map between 1 and 40 input fields.');
    if (new Set(inputs.map(input => input.target)).size !== inputs.length) throw new Error('Duplicate target fields.');
    const routes = {}, hosts = new Set(operationHosts().map(host => host.value));
    for (const row of document.querySelectorAll('#route-mappings .route-row')) {
      const action = row.querySelector('.route-action').value.trim(), target = row.querySelector('.route-target').value;
      if (!/^[A-Z_]{1,40}$/.test(action) || Object.prototype.hasOwnProperty.call(routes, action)) throw new Error('Use unique UPPERCASE actions.');
      if (!hosts.has(target)) throw new Error('Select an Operation installed in the Production.');
      routes[action] = target;
    }
    if (!Object.keys(routes).length) throw new Error('Define at least one route.');
    const outputs = {action:value('output-action')};
    if (value('output-reason')) outputs.reason = value('output-reason');
    if (Object.entries(outputs).some(([field,path]) => !outputOptions('', field === 'reason').items.some(item => item.value === path))) throw new Error('Select an output destination supplied by the Reader.');
    const fallback = {action:value('fallback-action'),target:value('fallback-target')};
    if (!Object.prototype.hasOwnProperty.call(routes, fallback.action) || routes[fallback.action] !== fallback.target) throw new Error('Fallback must match a declared route.');
    if (!value('binding-id') || !value('agent-id') || !Number.isInteger(Number(value('agent-revision'))) || Number(value('agent-revision')) < 1)
      throw new Error('A binding ID and a versioned agent reference are required.');
    if (!$('agent-timeout').checkValidity()) throw new Error('Enter a timeout within the native runtime limits.');
    return {bindingId:value('binding-id'), agentRef:{id:value('agent-id'),revision:Number(value('agent-revision'))},
      inputs, outputs, routes, fallback, timeouts:{agentMs:Number(value('agent-timeout'))}};
  }
  async function loadReleases() {
    if (!workflowId()) throw new Error('Enter a workflow.');
    const id = workflowId();
    remember(id);
    const [releaseResult, workflowResult] = await Promise.all([request(workflowPath('/releases')), request(workflowPath())]);
    if (workflowId() !== id) return;
    const data = releaseResult.data;
    state.workflow = workflowResult.data;
    if ($('test-payload')) {
      const sample = state.workflow.exampleRequest || state.workflow.testInput;
      if (sample) $('test-payload').value = json(sample);
    }
    if ($('release-history')) show('release-history', data);
    if ($('rollback-release')) {
      const select = $('rollback-release'); select.replaceChildren(new Option('Select a prior release', ''));
      for (const release of list(data)) { const id = release.releaseId || idOf(release); if (id) select.add(new Option(id, id)); }
      setDisabled('rollback-workflow', state.workflow?.managed !== true || !select.value);
    }
    if ($('release-id')) {
      const select = $('release-id'); select.replaceChildren(new Option('Select a release', ''));
      for (const release of list(data)) {
        const id = release.releaseId || idOf(release);
        if (id) select.add(new Option(id, id));
      }
      if (select.options.length === 2) select.selectedIndex = 1;
      updateExecuteButton();
    }
  }
  function updateExecuteButton() {
    const allowed = value('decision-mode') === 'SIMULATION'
      ? state.capabilities?.nativeSimulationEnabled === true
      : state.capabilities?.executionEnabled === true;
    setDisabled('execute-live', !value('release-id') || !allowed);
  }
  async function loadRun() {
    const id = value('execution-id');
    if (!id) throw new Error('Enter an execution identifier.');
    const {data} = await request('/runs/' + encodeURIComponent(id));
    show('run-status', data.status || 'Status not supplied');
    show('execution-mode', data.mode ? String(data.mode).toUpperCase() : 'Mode not supplied');
    $('execution-mode').dataset.mode = String(data.mode || '').toUpperCase();
    show('trace-result', data);
    const points = $('trace-points'); points.replaceChildren();
    const pointFilter = new URLSearchParams(location.search).get('point');
    for (const point of data.points || []) {
      const item = textElement('li', '', pointFilter === point.pointId ? 'selected' : '');
      item.append(textElement('strong', point.pointId + ' · ' + point.agentId + ' @' + point.agentRevision),textElement('small',point.status + ' · ' + (point.agentSessionId || 'No AI session')));
      const observations = document.createElement('ol'); StudioTraceView.render(observations, point.observations);
      const details = document.createElement('details'); details.open = pointFilter === point.pointId;
      details.append(textElement('summary','Point evidence'),textElement('pre',json(point)),observations); item.append(details); points.append(item);
    }
    if (!points.children.length) points.append(textElement('li','No per-point evidence captured for this historical execution.'));
    StudioTraceView.render($('trace-observations'), data.observations);
    const target = $('trace-events'); target.replaceChildren();
    for (const event of data.events || data.timeline || []) {
      const item = document.createElement('li');
      item.append(textElement('strong', event.name || event.stage || event.step || event.host || 'Event'),
        textElement('small', [event.status, event.timestamp, event.messageId].filter(Boolean).join(' · ')));
      if (event.details) item.append(textElement('pre', typeof event.details === 'string' ? event.details : json(event.details)));
      target.append(item);
    }
    if (!target.children.length) target.append(textElement('li', 'No instrumented event received. Inspect identifiers and native trace.', 'empty'));
    notice('Execution data retrieved from IRIS.');
  }
  function resetPublication() {
    state.valid = false; state.preview = false; state.idempotencyKey = null;
    if ($('publish-confirmed')) $('publish-confirmed').checked = false;
    updatePublishButton();
  }
  function updatePublishButton() {
    const editable = state.workflow?.managed === true && state.loadedWorkflowId === workflowId();
    setDisabled('rollback-workflow', !editable || !value('rollback-release'));
    setDisabled('publish-workflow', !(editable && state.valid && state.preview &&
      state.etag && $('publish-confirmed')?.checked && value('approval-ref')));
  }
  async function loadPublisher() {
    resetPublication(); state.workflow = null; state.etag = null; state.loadedWorkflowId = null;
    const id = workflowId(), loadVersion = ++state.loadVersion;
    setDisabled('validate-workflow', true); setDisabled('preview-workflow', true);
    const {data, etag} = await request(workflowPath());
    if (loadVersion !== state.loadVersion || workflowId() !== id) return;
    state.loadedWorkflowId = id;
    state.workflow = data; state.etag = etag || (data.baseHash ? '"' + data.baseHash + '"' : null);
    remember(workflowId());
    show('publish-class', data.className || workflowId()); show('publish-revision', data.revision ?? '—');
    show('publish-hash', data.baseHash || etag || 'Hash missing');
    setDisabled('validate-workflow', data.managed !== true); setDisabled('preview-workflow', true);
    setDisabled('refresh-releases', false);
    show('validation-result', data.managed === true ? 'Waiting for validation.' : data.readOnlyReason || 'Read-only workflow.');
    show('publish-diff', 'No preview received.'); show('publish-result', 'No publication requested.');
    await loadReleases();
  }
  let blockState = null, blockBaseline = '', blockPast = [], blockFuture = [], renderingBlocks = false;
  let chosenAgent = null, invalidBlock = false, blockSaving = false;
  const clone = object => JSON.parse(JSON.stringify(object));
  const canonical = object => JSON.stringify(object, (_, value) => value && typeof value === 'object' && !Array.isArray(value)
    ? Object.fromEntries(Object.keys(value).sort().map(key=>[key,value[key]])) : value);
  const snapshotBlocks = () => canonical(blockState && {bindings:blockState.bindings, definitions:blockState.definitions, bases:blockState.bases, attached:blockState.attached});
  const blocksDirty = () => !!blockState && (invalidBlock || snapshotBlocks() !== blockBaseline);
  function definitionOf(agent) {
    return {providerRef:agent?.providerRef || '', modelName:agent?.modelName || '', prompt:agent?.prompt || '', toolSetRefs:agent?.toolSetRefs || []};
  }
  function initializeBlocks(data) {
    const bindings = clone(data.bindings || (data.binding ? [data.binding] : []));
    blockState = {bindings, definitions:{}, bases:{}, selected:bindings[0]?.bindingId, attached:data.decisionAttached !== false};
    for (const binding of bindings) {
      const agent = state.agents.find(a => a.agentId === binding.agentRef.id && a.revision === binding.agentRef.revision);
      blockState.definitions[binding.bindingId] = definitionOf(agent);
      blockState.bases[binding.bindingId] = agent?.latestRevision || binding.agentRef.revision;
    }
    invalidBlock = false; blockPast = []; blockFuture = []; blockBaseline = snapshotBlocks();
    show('block-impact', data.dependencies || {complete:false,unresolved:['Unregistered BPL: dependencies not resolved.']});
    $('review-blocks').href = root + '/publisher?workflow=' + encodeURIComponent(workflowId());
    renderBlockInspector(); renderBlocks();
  }
  function saveHistory(previous) {
    if (canonical(JSON.parse(previous)) !== canonical(blockState)) { blockPast.push(previous); if (blockPast.length > 50) blockPast.shift(); blockFuture = []; }
  }
  function captureBlocks() {
    if (renderingBlocks || blockSaving || !blockState || !state.workflow?.managed || state.loadedWorkflowId !== workflowId() || !blockState.selected) return;
    const previous = JSON.stringify(blockState);
    try {
      const binding = bindingPayload();
      const index = blockState.bindings.findIndex(b => b.bindingId === blockState.selected);
      if (index < 0) return;
      blockState.bindings[index] = binding;
      blockState.bases[binding.bindingId] = Number(value('agent-base-revision'));
      blockState.definitions[binding.bindingId] = {providerRef:value('provider-ref'),modelName:value('model-name'),prompt:$('agent-prompt').value,toolSetRefs:selectedTools()};
      invalidBlock = false; saveHistory(previous);
    } catch (_) { invalidBlock = true; }
    updateBlockButtons();
  }
  function updateBlockButtons() {
    if (!$('block-canvas')) return;
    const editable = !blockSaving && state.workflow?.managed === true && state.loadedWorkflowId === workflowId();
    setDisabled('undo-blocks', !editable || !blockPast.length); setDisabled('redo-blocks', !editable || !blockFuture.length);
    setDisabled('save-blocks', !editable || !blockState?.bindings.length || invalidBlock);
    setDisabled('append-block', !editable || !chosenAgent || (blockState?.attached && blockState.bindings.length >= 8));
    show('draft-state', !blockState ? 'No process loaded' : !editable ? 'Read-only' : invalidBlock ? 'Invalid local fields' : blocksDirty() ? 'Unsaved local changes' : 'Saved draft · published releases unchanged');
  }
  function renderBlockInspector() {
    const binding = blockState?.bindings.find(b => b.bindingId === blockState.selected);
    if (!binding) return;
    renderingBlocks = true;
    $('binding-id').value = binding.bindingId; fillMappingControls(binding);
    fillAgent({...blockState.definitions[binding.bindingId], agentId:binding.agentRef.id,revision:binding.agentRef.revision});
    $('agent-base-revision').value = blockState.bases[binding.bindingId] ?? binding.agentRef.revision;
    $('agent-timeout').value = binding.timeouts?.agentMs || 30000;
    $('binding-revision').value = state.bindingRevision;
    const editable = state.workflow?.managed === true && state.loadedWorkflowId === workflowId() && !blockSaving;
    document.querySelectorAll('.inspector input:not(#tool-list input),.inspector textarea,.inspector select,.inspector .remove-row').forEach(element=>element.disabled=!editable);
    $('session-policy').disabled=true;
    renderingBlocks = false;
  }
  function chooseBlock(id) {
    if (!blockState || !blockState.bindings.some(b => b.bindingId === id)) return;
    captureBlocks(); if (invalidBlock) throw new Error('Correct invalid fields before selecting another block.');
    blockState.selected = id; renderBlockInspector(); renderBlocks();
  }
  function compatibility(agent) {
    if (blockSaving) return 'Wait for the current save to finish.';
    if (!state.workflow?.managed || state.loadedWorkflowId !== workflowId()) return 'This process is read-only.';
    if (!agent || !agent.toolSetRefs?.length) return 'An agent revision with authorized READ tools is required.';
    const allowed = new Set(state.tools.filter(t => String(t.effect || t.access).toUpperCase() === 'READ').map(t => t.className || t.id || t.name));
    if (agent.toolSetRefs.some(t => !allowed.has(t))) return 'Agent requires unavailable or unauthorized tools.';
    if (state.workflow.templateId === 'blood-stock-v1' && !agent.toolSetRefs.includes('Studio.Tools.BloodStockTools')) return 'Stock decisions require the ReadStock ToolSet.';
    return '';
  }
  function attachAgent(agent, target) {
    captureBlocks(); if (invalidBlock) throw new Error('Correct invalid fields before connecting a block.');
    const reason = compatibility(agent); if (reason) throw new Error(reason);
    const previous = JSON.stringify(blockState);
    let binding = blockState.bindings.find(b => b.bindingId === target);
    if (!binding) {
      if (!blockState.attached) binding = blockState.bindings[0];
      else {
        if (blockState.bindings.length >= 8) throw new Error('Maximum eight decision blocks.');
        binding = clone(blockState.bindings.at(-1));
        binding.bindingId = state.workflow.workflowId + ':p' + crypto.randomUUID().replaceAll('-','');
        blockState.bindings.push(binding);
      }
    }
    binding.agentRef = {id:agent.agentId,revision:agent.revision};
    blockState.definitions[binding.bindingId] = definitionOf(agent);
    blockState.bases[binding.bindingId] = agent.latestRevision || agent.revision;
    blockState.attached = true; blockState.selected = binding.bindingId;
    saveHistory(previous); renderBlockInspector(); renderBlocks();
    show('block-feedback','Connected locally. Review mappings; server validation runs when saving.');
  }
  function dropTarget(element, target) {
    element.addEventListener('dragover', event => {
      if (!compatibility(chosenAgent)) { event.preventDefault(); element.classList.add('can-connect'); event.dataTransfer.dropEffect='copy'; }
      else show('block-feedback',compatibility(chosenAgent));
    });
    element.addEventListener('dragleave', () => element.classList.remove('can-connect'));
    element.addEventListener('drop', action(event => {
      element.classList.remove('can-connect');
      const key = event.dataTransfer.getData('application/x-studio-agent');
      const agent = state.agents.find(a => a.agentId + '@' + a.revision === key);
      attachAgent(agent,target);
    }));
  }
  function renderBlocks() {
    if (!$('block-canvas')) return;
    const catalog = $('agent-block-catalog'); catalog.replaceChildren();
    const search = value('agent-search').toLowerCase();
    for (const agent of state.agents.filter(a => (a.agentId+' '+a.modelName).toLowerCase().includes(search))) {
      const item = textElement('button', agent.agentId + ' @' + agent.revision, 'agent-brick'); item.type='button';
      const reason=compatibility(agent); item.draggable=!reason; item.title=reason || 'Drag to a compatible socket, or select then connect.';
      item.setAttribute('aria-pressed',String(chosenAgent?.agentId===agent.agentId && chosenAgent?.revision===agent.revision));
      item.append(textElement('small',agent.modelName));
      item.addEventListener('click', () => { chosenAgent=agent; renderBlocks(); show('block-feedback',reason || 'Agent selected. Use Replace on a block or Connect selected agent.'); });
      item.addEventListener('dragstart', event => { chosenAgent=agent; event.dataTransfer.setData('application/x-studio-agent',agent.agentId+'@'+agent.revision); event.dataTransfer.effectAllowed='copy'; show('block-feedback','Drop on a block to replace it, or the + socket to append.'); });
      catalog.append(item);
    }
    const canvas=$('block-canvas'); canvas.replaceChildren();
    if (blockState?.attached) for (const [index,binding] of blockState.bindings.entries()) {
      const card=textElement('li','','decision-brick'+(blockState.selected===binding.bindingId?' selected':''));
      card.dataset.pointId=binding.bindingId;
      card.append(textElement('span','IN · request / context','block-port'));
      const select=textElement('button',(index+1)+'. '+binding.agentRef.id+' @'+binding.agentRef.revision,'block-title'); select.type='button';
      select.setAttribute('aria-pressed',String(blockState.selected===binding.bindingId));
      select.addEventListener('click',action(() => { chooseBlock(binding.bindingId); $('tab-agent').click(); })); card.append(select);
      const replace=textElement('button','Replace with selected agent'); replace.type='button'; replace.disabled=!!compatibility(chosenAgent);
      replace.addEventListener('click',action(() => attachAgent(chosenAgent,binding.bindingId))); card.append(replace);
      if (blockState.bindings.length>1) {
        const remove=textElement('button','Remove block'); remove.type='button'; remove.disabled=!state.workflow?.managed;
        remove.addEventListener('click',action(() => {
          captureBlocks(); if(invalidBlock) throw new Error('Correct invalid fields first.');
          const previous=JSON.stringify(blockState); blockState.bindings=blockState.bindings.filter(b=>b.bindingId!==binding.bindingId); delete blockState.definitions[binding.bindingId]; delete blockState.bases[binding.bindingId]; blockState.selected=blockState.bindings[0].bindingId;
          saveHistory(previous); renderBlockInspector(); renderBlocks();
        })); card.append(remove);
      }
      const routes=textElement('ul','','block-routes');
      for(const [name,host] of Object.entries(binding.routes)) routes.append(textElement('li',name+' → '+host));
      card.append(routes,textElement('small','Fallback: '+binding.fallback.action+' → '+binding.fallback.target),textElement('span',index<blockState.bindings.length-1?'OUT · success ↓ next block':'OUT · workflow response','block-port'));
      dropTarget(card,binding.bindingId); canvas.append(card);
    }
    if(!canvas.children.length) canvas.append(textElement('li',state.workflow?.managed?'Empty decision socket':'Read-only BPL · inspect activities below','empty'));
    updateBlockButtons();
  }
  async function persistAgent(id) {
    const binding=blockState.bindings.find(b=>b.bindingId===id), definition=blockState.definitions[id];
    const existing=state.agents.find(a=>a.agentId===binding.agentRef.id && a.revision===binding.agentRef.revision);
    if(existing && JSON.stringify(definitionOf(existing))===JSON.stringify(definition)) return;
    const {data}=await request('/agents/'+encodeURIComponent(binding.agentRef.id),{method:'PUT',body:{definition,baseRevision:blockState.bases[id] ?? binding.agentRef.revision}});
    const previousBase=blockState.bases[id] ?? binding.agentRef.revision;
    binding.agentRef.revision=data.revision; blockState.bases[id]=data.revision;
    for(const point of blockState.bindings) if(point.agentRef.id===binding.agentRef.id && blockState.bases[point.bindingId]===previousBase) blockState.bases[point.bindingId]=data.revision;
    for(const agent of state.agents) if(agent.agentId===binding.agentRef.id) agent.latestRevision=data.revision;
    state.agents.push({...definition,agentId:binding.agentRef.id,revision:data.revision,latestRevision:data.revision});
    blockPast=[]; blockFuture=[];
    show('block-feedback','Revision '+data.revision+' saved. Its binding is still pending until Save all blocks succeeds.');
  }
  async function saveBlocks() {
    captureBlocks(); if(invalidBlock || !blockState?.bindings.length || !state.workflow?.managed) throw new Error('Valid editable blocks required.');
    await lockedBlockSave(async () => {
      for(const binding of blockState.bindings) await persistAgent(binding.bindingId);
      const {data}=await request(workflowPath('/bindings'),{method:'PUT',headers:{'If-Match':'"'+state.bindingRevision+'"'},body:{bindings:blockState.bindings}});
      blockBaseline=snapshotBlocks(); blockState=null;
      await loadDesigner(); show('designer-result',data); notice('All blocks saved. Validate and review before publication.');
    });
  }
  async function lockedBlockSave(callback) {
    if(blockSaving) throw new Error('A save is already in progress.');
    if(state.loadedWorkflowId !== workflowId()) throw new Error('Load the selected process before saving.');
    const controls=Array.from(document.querySelectorAll('.visual-workbench input,.visual-workbench textarea,.visual-workbench select,.visual-workbench button,.designer-navigation select,#workflow-id,#load-workflow button,.native-structure button'));
    const disabled=controls.map(element=>element.disabled);
    blockSaving=true; controls.forEach(element=>element.disabled=true); show('draft-state','Saving…');
    try { return await callback(); }
    finally {
      blockSaving=false; controls.forEach((element,index)=>{ if(element.isConnected) element.disabled=disabled[index]; });
      renderBlockInspector(); renderBlocks(); updateDesignerButtons();
    }
  }
  async function designerNavigation() {
    const {data}=await request('/productions');
    for(const production of list(data)) $('designer-production').add(new Option(production.name,production.name));
  }
  on('designer-production','change',action(async()=>{
    const select=$('designer-process'); select.replaceChildren(new Option('Select a process',''));
    if(!value('designer-production')) return;
    const {data}=await request('/workflows?production='+encodeURIComponent(value('designer-production')));
    for(const workflow of list(data)) select.add(new Option((workflow.hostName||workflow.name||workflow.className)+' · '+(workflow.managed?'managed':'read-only'),idOf(workflow)));
  }));
  on('designer-process','change',action(async()=>{ if(value('designer-process')) { $('workflow-id').value=value('designer-process'); await loadDesigner(); } }));
  on('agent-search','input',renderBlocks);
  on('append-block','click',action(()=>attachAgent(chosenAgent,null)));
  if($('append-block')) dropTarget($('append-block'),null);
  on('save-blocks','click',action(saveBlocks));
  on('inspect-block','click',action(() => {
    if (!value('block-execution')) throw new Error('Enter the execution ID to inspect.');
    location.href=root+'/test-trace?execution='+encodeURIComponent(value('block-execution'))+'&point='+encodeURIComponent(blockState?.selected || '');
  }));
  on('undo-blocks','click',()=>{ if(blockPast.length) { blockFuture.push(JSON.stringify(blockState)); blockState=JSON.parse(blockPast.pop()); invalidBlock=false; renderBlockInspector();renderBlocks(); } });
  on('redo-blocks','click',()=>{ if(blockFuture.length) { blockPast.push(JSON.stringify(blockState)); blockState=JSON.parse(blockFuture.pop()); invalidBlock=false; renderBlockInspector();renderBlocks(); } });
  document.querySelector('.inspector')?.addEventListener('input',captureBlocks);
  document.querySelector('.inspector')?.addEventListener('change',captureBlocks);
  window.addEventListener('beforeunload',event=>{ if(blocksDirty()) { event.preventDefault(); event.returnValue=''; } });

  document.querySelectorAll('[role="tab"]').forEach(tab => {
    function activate() {
      document.querySelectorAll('[role="tab"]').forEach(item => {
        const active = item === tab;
        item.setAttribute('aria-selected', String(active)); item.tabIndex = active ? 0 : -1;
        $(item.getAttribute('aria-controls')).hidden = !active;
      });
    }
    tab.addEventListener('click', activate);
    tab.addEventListener('keydown', event => {
      const tabs = Array.from(document.querySelectorAll('[role="tab"]'));
      const index = tabs.indexOf(tab);
      const key = {ArrowRight: (index + 1) % tabs.length, ArrowLeft: (index + tabs.length - 1) % tabs.length,
        Home: 0, End: tabs.length - 1}[event.key];
      if (key !== undefined) { event.preventDefault(); tabs[key].click(); tabs[key].focus(); }
    });
  });
  if ($('workflow-id')) $('workflow-id').value = new URLSearchParams(location.search).get('workflow') || storedId();
  on('refresh-explorer', 'click', action(explorer));
  on('template', 'change', updateTemplate);
  on('production', 'change', action(loadWorkflows)); on('workflow-search', 'input', renderWorkflows);
  on('create-workflow', 'click', action(async () => {
    const {data} = await request('/workflows', {method: 'POST', body: {templateId: value('template'), production: value('production')}});
    notice('Draft created in IRIS.'); await loadWorkflows();
    if (idOf(data)) { remember(idOf(data)); location.href = root + '/designer?workflow=' + encodeURIComponent(idOf(data)); }
  }));
  on('load-workflow', 'submit', action(page === 'publisher' ? loadPublisher : loadDesigner));
  on('workflow-id', 'input', () => {
    if(page !== 'designer') { state.workflow = null; state.loadedWorkflowId = null; }
    state.loadVersion++;
    ['save-binding', 'save-agent', 'validate-workflow', 'preview-workflow', 'refresh-releases'].forEach(id => setDisabled(id, true));
    if (page === 'publisher') resetPublication();
    if (page === 'designer') {
      updateDesignerButtons();
      document.querySelectorAll('.inspector input, .inspector textarea, .inspector select, .remove-row').forEach(element => element.disabled = true);
      setDisabled('configure-decision', true);
    }
    if (page === 'test_trace') { $('release-id').replaceChildren(new Option('Load releases', '')); updateExecuteButton(); }
  });
  on('agent-select', 'change', () => { if (value('agent-select') !== '') { fillAgent(state.agents[Number(value('agent-select'))]); captureBlocks(); renderBlocks(); } });
  on('add-input', 'click', () => { if (state.workflow?.managed === true) { addInputRow(); changedBinding(); } });
  on('add-route', 'click', () => { if (state.workflow?.managed === true) { addRouteRow(); refreshFallback(); changedBinding(); } });
  for (const id of ['agent-id','agent-revision','agent-timeout','output-action','output-reason','fallback-action','fallback-target','input-example']) on(id, 'change', changedBinding);
  on('fallback-action', 'change', () => {
    const row = Array.from(document.querySelectorAll('.route-row')).find(row => row.querySelector('.route-action').value.trim() === value('fallback-action'));
    if (row) $('fallback-target').value = row.querySelector('.route-target').value;
    changedBinding();
  });
  on('configure-decision', 'click', () => {
    const node = (state.workflow?.graph?.nodes || state.workflow?.activities || []).find(decisionNode);
    if (node) selectNode(node);
  });
  on('insert-decision', 'click', action(async () => {
    if (state.workflow?.managed !== true || state.workflow?.decisionSlotAvailable !== true) throw new Error('The template has no available insertion slot.');
    await request(workflowPath('/decision-slot'), {method:'POST', body:{expectedRevision:state.workflow.revision}});
    blockBaseline = ''; blockState = null; await loadDesigner(); notice('AI Decision inserted in the slot recognized by IRIS.');
  }));
  on('preview-input', 'click', action(async () => {
    const {data} = await request(workflowPath('/preview-input'), {method:'POST', body:{binding:bindingPayload(),example:parseField('input-example','{}')}});
    show('input-preview',data); show('binding-review',bindingPayload());
  }));
  on('save-agent', 'click', action(async () => {
    captureBlocks();
    if(invalidBlock) throw new Error('Correct invalid fields before saving.');
    await lockedBlockSave(() => persistAgent(blockState.selected));
    renderBlockInspector(); renderBlocks();
    notice('Agent revision saved. Save all blocks to attach it. Published releases remain unchanged.');
  }));
  on('save-binding', 'click', action(saveBlocks));
  on('validate-workflow', 'click', action(async () => {
    if (page === 'publisher') resetPublication();
    const {data} = await request(workflowPath('/validate'), {method: 'POST'});
    show(page === 'publisher' ? 'validation-result' : 'designer-result', data);
    if (page === 'publisher') { state.valid = data.valid === true; setDisabled('preview-workflow', !state.valid); }
    notice(data.valid === true ? 'IRIS validation passed.' : 'Inspect the validation report.', data.valid !== true);
  }));
  on('preview-workflow', 'click', action(async () => {
    state.preview = false; updatePublishButton();
    const {data} = await request(workflowPath('/preview'), {method: 'POST'});
    show('publish-diff', typeof data.diff === 'string' ? data.diff + '\n\n' + json({...data, diff: undefined}) : data);
    state.preview = Object.prototype.hasOwnProperty.call(data, 'diff') && data.valid !== false;
    state.idempotencyKey = crypto.randomUUID();
    $('publish-confirmed').checked = false;
    notice(state.preview ? 'Diff received. Review it before authorizing publication.' : 'Incomplete preview; publication blocked.', !state.preview);
  }));
  on('approval-ref', 'input', updatePublishButton); on('publish-confirmed', 'change', updatePublishButton);
  on('publish-form', 'submit', action(async () => {
    updatePublishButton();
    if ($('publish-workflow').disabled && !(state.valid && state.preview && $('publish-confirmed').checked && state.etag && value('approval-ref')))
      throw new Error('Validation, diff and authorization are required.');
    const {data} = await request(workflowPath('/publish'), {method: 'POST',
      headers: {'If-Match': state.etag, 'Idempotency-Key': state.idempotencyKey},
      body: {draftRevision: state.workflow.revision, approvalRef: value('approval-ref'), confirmed: true}});
    show('publish-result', data); resetPublication();
    if (data.compiled !== true || data.published !== true || !data.releaseId)
      throw new Error('Publication is not confirmed. Inspect the native result before proceeding.');
    notice(data.activated === true
      ? 'IRIS compiled and published release ' + data.releaseId + ' and activated its Production host.'
      : 'IRIS compiled and installed release ' + data.releaseId + '. Activation is pending; the target Production must be running.');
    await loadReleases();
  }));
  on('refresh-releases', 'click', action(loadReleases)); on('load-releases', 'submit', action(loadReleases));
  on('rollback-release', 'change', () => setDisabled('rollback-workflow', state.workflow?.managed !== true || !value('rollback-release')));
  on('rollback-workflow', 'click', action(async () => {
    if (state.workflow?.managed !== true || !value('rollback-release')) throw new Error('Select a release from a managed workflow.');
    const {data} = await request(workflowPath('/rollback'), {method:'POST', body:{releaseId:value('rollback-release'),expectedRevision:state.workflow.revision}});
    await loadPublisher(); show('publish-result', data);
    notice('Release configuration restored as a new draft. Review, validate and publish it to create a release.');
  }));
  on('release-id', 'change', updateExecuteButton);
  on('decision-mode', 'change', updateExecuteButton);
  on('execute-test', 'submit', action(async () => {
    updateExecuteButton();
    if ($('execute-live').disabled) throw new Error('Execution mode is unavailable or a release is missing.');
    const payload = parseField('test-payload', '{}');
    payload.Mode = value('decision-mode');
    const {data} = await request('/test-runs', {method: 'POST', body: {releaseId: value('release-id'), mode: 'live', payload}});
    $('execution-id').value = data.executionId;
    notice('Message accepted. Retrieving execution evidence.'); await loadRun();
  }));
  on('load-run', 'submit', action(loadRun));
  action(async () => {
    if (page === 'explorer') return explorer();
    await capabilities();
    if (page === 'designer') { await designerCatalog(); await designerNavigation(); if (workflowId()) await loadDesigner(); }
    if (page === 'publisher' && workflowId()) await loadPublisher();
    if (page === 'test_trace') {
      if (workflowId()) await loadReleases();
      const execution = new URLSearchParams(location.search).get('execution');
      if (execution) { $('execution-id').value = execution; await loadRun(); }
    }
  })();
})();
