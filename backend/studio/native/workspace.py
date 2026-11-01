"""Versioned native Studio administration. Imported exclusively inside IRIS."""
from copy import deepcopy
import difflib
import hashlib
import json
import re
import uuid
import xml.etree.ElementTree as ET

import iris

W = lambda: iris.cls('Studio.Admin.Workspace')
C = lambda: iris.cls('Studio.Admin.ControlPlane')
B = lambda: iris.cls('Studio.Admin.BPLReader')


class Failure(Exception):
    def __init__(self, code, message, status=422):
        self.code, self.message, self.status = code, message, status


def read(key, default=None):
    value = str(W().Read(key))
    return json.loads(value) if value else default


def write(key, value):
    W().Write(key, json.dumps(value, separators=(',', ':')))


def digest(source):
    return hashlib.sha256(source.encode()).hexdigest()


def productions():
    # Native class dictionary, constrained by Development authorization in USER.
    return json.loads(str(W().Productions()))


def hosts(production):
    if production not in {p['name'] for p in productions()}:
        raise Failure('PRODUCTION_DENIED', 'Production is not installed or authorized.', 403)
    items = json.loads(str(B().ProductionItems(production)))
    for item in items:
        if subclass(item['className'], 'Ens.BusinessOperation'):
            item['type'] = 'BusinessOperation'
        elif subclass(item['className'], 'Ens.BusinessService'):
            item['type'] = 'BusinessService'
        else:
            item['type'] = 'BusinessProcess'
    return items


def agent(binding):
    ref = binding.get('agentRef', {})
    result = json.loads(str(C().Agent(str(ref.get('id', '')), int(ref.get('revision', 0)))._ToJSON()))
    if not result.get('agentId'):
        raise Failure('AGENT_NOT_FOUND', 'Pinned agent revision does not exist.')
    return result


def subclass(name, base):
    if name == base:
        return True
    definition = iris.cls('%Dictionary.ClassDefinition')._OpenId(name)
    # Embedded Python represents a null ObjectScript OREF as an empty string.
    if definition is None or isinstance(definition, (str, int)):
        return False
    return any(subclass(parent.strip(), base) for parent in str(definition.Super).split(',') if parent.strip())


def xml(binding, attached=True, request_class="Studio.Msg.WorkflowRequest"):
    root = ET.Element('process', language='objectscript', request=request_class, response='Studio.Msg.WorkflowResponse')
    context = ET.SubElement(root, 'context')
    for name in ('Action', 'Status', 'Reason'):
        prop = ET.SubElement(context, 'property', name=name, type='%String')
        parameters = ET.SubElement(prop, 'parameters')
        ET.SubElement(parameters, 'parameter', name='MAXLEN', value='2048' if name == 'Reason' else '40')
    sequence = ET.SubElement(root, 'sequence')

    def assign(parent, target, value):
        ET.SubElement(parent, 'assign', property=target, value=value)

    assign(sequence, 'response.CorrelationId', 'request.CorrelationId')
    if not attached:
        assign(sequence, 'response.Status', '"DRAFT"')
        return ET.tostring(root, encoding='unicode')
    call = ET.SubElement(sequence, 'call', name='AI Decision', target='AgentDecision', async_='0')
    call.set('timeout', format(binding.get('timeouts', {}).get('agentMs', 30000) / 1000, '.3f'))
    # XML uses async, not Python's reserved keyword.
    call.set('async', call.attrib.pop('async_'))
    request = ET.SubElement(call, 'request', type='Studio.Msg.DecisionRequest')
    for field in ('ReleaseId', 'CorrelationId', 'Mode', 'CandidateJson', 'SimulationFault'):
        assign(request, 'callrequest.' + field, 'request.' + field)
    assign(request, 'callrequest.BindingId', '"' + binding['bindingId'] + '"')
    assign(request, 'callrequest.InputJson', '##class(Studio.Runtime.Envelope).InputJson(request,request.ReleaseId)')
    response = ET.SubElement(call, 'response', type='Studio.Msg.DecisionResponse')
    for field in ('Action', 'Status', 'Reason'):
        assign(response, 'context.' + field, 'callresponse.' + field)
    for field in ('Action', 'Status', 'Reason', 'AgentSessionId', 'DecisionExecutionId'):
        assign(response, 'response.' + field, 'callresponse.' + field)
    for field, target in binding.get('outputs', {}).items():
        assign(response, target, 'callresponse.' + {'action': 'Action', 'reason': 'Reason'}[field])
    timeout = ET.SubElement(sequence, 'if', name='Decision deadline', condition='synctimedout')
    expired = ET.SubElement(timeout, 'true')
    assign(expired, 'context.Status', '"TIMEOUT"')
    assign(expired, 'context.Action', '"' + binding['fallback']['action'] + '"')
    assign(expired, 'response.Status', '"TIMEOUT"')
    assign(expired, 'response.DecisionExecutionId', 'request.CorrelationId')
    assign(expired, 'response.Action', '"' + binding['fallback']['action'] + '"')
    assign(expired, 'response.Reason', '"Agent deadline exceeded; configured fallback selected."')
    switch = ET.SubElement(sequence, 'switch', name='Validated static routes')

    def sink(parent, target):
        call = ET.SubElement(parent, 'call', name='Route ' + target, target=target, **{'async': '0'})
        request = ET.SubElement(call, 'request', type=request_class)
        for field in ('EventId', 'Description', 'ReleaseId', 'CorrelationId', 'Mode', 'CandidateJson', 'SimulationFault') + (('BloodGroup', 'Units') if request_class == 'Studio.Msg.StockWorkflowRequest' else ()):
            assign(request, 'callrequest.' + field, 'request.' + field)
        response = ET.SubElement(call, 'response', type='Studio.Msg.WorkflowResponse')
        assign(response, 'response.Receipt', 'callresponse.Receipt')

    for action, target in binding['routes'].items():
        case = ET.SubElement(switch, 'case', condition='((context.Status="SUCCESS")!(context.Status="SIMULATED"))&&(context.Action="' + action + '")')
        sink(case, target)
    sink(ET.SubElement(switch, 'default'), binding['fallback']['target'])
    return ET.tostring(root, encoding='unicode')


def bindings_of(document):
    """Legacy snapshots stay immutable; normalize only the read representation."""
    return document.get('bindings', [document['binding']])


def workflow_xml(bindings, attached=True, request_class='Studio.Msg.WorkflowRequest'):
    if len(bindings) == 1:
        return xml(bindings[0], attached, request_class)
    root = ET.fromstring(xml(bindings[0], attached, request_class))
    sequence = root.find('sequence')
    sequence.clear()
    parent = sequence
    for index, binding in enumerate(bindings):
        block = ET.fromstring(xml(binding, attached, request_class)).find('sequence')
        call = block.find('call')
        call.set('name', 'AI ' + binding['bindingId'].split(':')[1])
        for assignment in call.find('request').findall('assign'):
            if assignment.get('property') == 'callrequest.InputJson':
                assignment.set('value', '##class(Studio.Runtime.Envelope).InputJson(request,request.ReleaseId,"' + binding['bindingId'] + '",context.Action,context.Reason)')
        parent.extend(list(block))
        if index < len(bindings)-1:
            guard = ET.SubElement(parent, 'if', name='Continue after success ' + str(index+1), condition='(context.Status="SUCCESS")!(context.Status="SIMULATED")')
            parent = ET.SubElement(guard, 'true')
    return ET.tostring(root, encoding='unicode')


def dependencies(workflow):
    refs = {(b['agentRef']['id'], b['agentRef']['revision']) for b in bindings_of(workflow)}
    consumers = []
    for identifier in ids():
        revision = read('latest:' + identifier)
        draft = read('draft:' + identifier + ':' + str(revision), {})
        for release_id in [None] + read('releases:' + identifier, []):
            document = read('release:' + release_id, {}) if release_id else draft
            if not document.get('binding'):
                continue
            for binding in bindings_of(document):
                if (binding['agentRef']['id'], binding['agentRef']['revision']) in refs:
                    consumers.append(dict(workflowId=identifier, production=document['production'], hostName=document.get('hostName'), bindingId=binding['bindingId'], agentRef=binding['agentRef'], releaseId=release_id, resolution='registered'))
    for identifier in read('components', []):
        component = read('component:' + identifier, {})
        if (component.get('agentId'), component.get('agentRevision')) in refs:
            consumers.append(dict(componentId=identifier, production=component['production'], hostName=component['hostName'], resolution='registered'))
    references, unresolved = [], []
    installed = {h['name']: h for h in workflow.get('hosts', [])}
    for node in workflow.get('graph', {}).get('nodes', []):
        if node.get('opaque'):
            unresolved.append({'activityId': node['id'], 'reason': 'Opaque BPL activity; nested calls not resolved.'})
        if node.get('kind') not in ('call', 'ai-decision'):
            continue
        target = node.get('target', '')
        host = installed.get(target)
        reference = dict(activityId=node['id'], pointId=node.get('pointId'), target=target,
                         resolution='installed-static' if host else 'unresolved',
                         className=host['className'] if host else None)
        references.append(reference)
        if not host:
            unresolved.append({'activityId': node['id'], 'target': target, 'reason': 'Dynamic or missing target; not inferred.'})
    unresolved.append({'reason': 'Unregistered external consumers and dynamic calls are not exhaustively resolved.'})
    return {'consumers': consumers, 'references': references, 'complete': False, 'unresolved': unresolved,
            'policy': 'Published consumers remain pinned. A new release installs a separate BPL host; shared Operations are not modified.'}


def ids():
    return read('workflows', [])


def get(identifier, include_dependencies=True):
    if identifier.startswith('host:'):
        production, separator, name = identifier[5:].partition('|')
        installed = hosts(production)
        host = next((h for h in installed if h['name'] == name), None)
        if not separator or not host:
            raise Failure('WORKFLOW_NOT_FOUND', 'Business host not found in this Production.', 404)
        result = json.loads(str(B().ReadDefinition(host['className'])._ToJSON()))
        result.update(workflowId=identifier, production=production, hostName=name, hosts=installed)
        return result
    if identifier.startswith('class:'):
        name = identifier[6:]
        if not any(h['className'] == name for p in productions() for h in hosts(p['name'])):
            raise Failure('WORKFLOW_NOT_FOUND', 'Class is not present in an authorized Production.', 404)
        return json.loads(str(B().ReadDefinition(name)._ToJSON()))
    revision = read('latest:' + identifier)
    if revision is None:
        raise Failure('WORKFLOW_NOT_FOUND', 'Workflow is not registered.', 404)
    result = read('draft:' + identifier + ':' + str(revision))
    result['bindings'] = deepcopy(bindings_of(result))
    result['schemaVersion'] = 2
    result['hosts'] = hosts(result['production'])
    result['managed'] = True
    if result.get('className'):
        actual = str(B().Source(result['className']))
        if digest(actual) != result['baseHash']:
            result['managed'] = False
            result['readOnlyReason'] = 'Generated source changed outside the managed template.'
    result['requestProperties'] = json.loads(str(B().Properties(result['requestClass'])._ToJSON()))
    result['requestFields'] = result['requestProperties']
    result['outputPathsByField'] = {'action': ['context.Action', 'response.Action'], 'reason': ['context.Reason', 'response.Reason']}
    result['outputPaths'] = ['context.Action', 'response.Action', 'context.Reason', 'response.Reason']
    result['contextFields'] = [{'name': n, 'type': '%String'} for n in ('Action', 'Status', 'Reason')]
    result['exampleRequest'] = {'EventId': 'event-001', 'Description': 'Review this event'}
    if result.get('templateId') == 'blood-stock-v1':
        result['exampleRequest'] = {'EventId': 'stock-001', 'BloodGroup': 'O+', 'Units': 5, 'Description': 'Synthetic stock request from center A'}
    result['sourceHash'] = digest(result['source'])
    result['graph'] = json.loads(str(B().Parse(result['source'])))
    result['graph']['recognized'] = result['managed']
    if result['managed']:
        points = iter(result['bindings'])
        for node in result['graph']['nodes']:
            if node.get('kind') == 'call' and node.get('target') == 'AgentDecision':
                binding = next(points)
                node.update(nativeKind='call', kind='ai-decision', type='AI Decision', managedDecision=True, pointId=binding['bindingId'], bindingId=binding['bindingId'])
    if include_dependencies:
        result['dependencies'] = dependencies(result)
    return result


def append(workflow):
    saved = {k: v for k, v in workflow.items() if k not in ('graph', 'hosts', 'requestFields', 'requestProperties', 'sourceHash', 'dependencies')}
    write('draft:' + workflow['workflowId'] + ':' + str(workflow['revision']), saved)
    write('latest:' + workflow['workflowId'], workflow['revision'])
    return get(workflow['workflowId'])


def validate(workflow):
    results = [validate_one(dict(workflow, binding=binding, pointIndex=index)) for index, binding in enumerate(bindings_of(workflow))]
    issues = [binding['bindingId'] + ': ' + issue for binding, result in zip(bindings_of(workflow), results) for issue in result['issues']]
    return {'valid': not issues, 'issues': issues, 'errors': issues}


def validate_one(workflow):
    issues = []
    binding = workflow['binding']
    if not workflow['managed']:
        issues.append('Source is read-only or changed outside Studio.')
    if not workflow.get('decisionAttached', True):
        issues.append('Insert the managed AI Decision slot before publishing.')
    try:
        from studio.services.validation import validate_binding
        validate_binding(binding)
        definition = agent(binding)
        if not definition.get('toolSetRefs') or any(not C().ToolAllowed(tool) for tool in definition['toolSetRefs']):
            issues.append('Pinned agent requires installed and authorized READ ToolSets.')
    except Exception as ex:
        issues.append(getattr(ex, 'message', 'Invalid binding contract.'))
    if workflow.get('templateId') == 'blood-stock-v1':
        if binding.get('routes') != {'B': 'StockCenterB', 'C': 'StockCenterC', 'REVIEW': 'StockReview'} or binding.get('fallback') != {'action': 'REVIEW', 'target': 'StockReview'}:
            issues.append('Stock template requires its fixed B/C/REVIEW routes.')
        try:
            if 'Studio.Tools.BloodStockTools' not in agent(binding).get('toolSetRefs', []):
                issues.append('Stock agent requires the ReadStock ToolSet.')
        except Failure:
            pass
    available = {h['name']: h for h in hosts(workflow['production'])}
    if 'AgentDecision' not in available or 'StudioWorkflowService' not in available:
        issues.append('Production requires AgentDecision and StudioWorkflowService hosts.')
    routes = binding.get('routes', {})
    if not isinstance(routes, dict) or not 1 <= len(routes) <= 40:
        issues.append('One to forty static routes are required.')
        return {'valid': False, 'issues': issues, 'errors': issues}
    for action, target in routes.items():
        if not re.fullmatch(r'[A-Z][A-Z0-9_]{0,39}', action):
            issues.append('Action names must be bounded uppercase identifiers.')
        if target not in available or not available[target]['enabled']:
            issues.append('Route target must be an enabled installed host: ' + target)
        elif not subclass(available[target]['className'], 'Ens.BusinessOperation'):
            issues.append('Static route targets must be Business Operations: ' + target)
    fallback = binding.get('fallback', {})
    if fallback.get('target') not in available or routes.get(fallback.get('action')) != fallback.get('target'):
        issues.append('Fallback must name an installed target and a declared action.')
    try:
        context = {'Action': 'PREVIOUS_ACTION', 'Reason': 'Previous decision output (schema preview only)'} if workflow.get('pointIndex', 0) else {}
        preview = json.loads(str(iris.cls('Studio.Runtime.InputMapper').Preview(workflow['requestClass'], json.dumps(workflow['exampleRequest']), json.dumps(binding), json.dumps(context))))
        if not preview.get('ok'):
            issues.append('Input mapping validation failed: ' + ', '.join(preview.get('data', {}).get('issues', [])))
    except Exception:
        issues.append('Native input mapping validation unavailable.')
    timeout = binding.get('timeouts', {}).get('agentMs', 30000)
    if not isinstance(timeout, int) or timeout < 100 or timeout > 300000:
        issues.append('Agent timeout must be between 100 and 300000 milliseconds.')
    return {'valid': not issues, 'issues': issues, 'errors': issues}


def dispatch(action, arguments):
    try:
        return json.dumps({'ok': True, 'data': handle(action, json.loads(arguments))})
    except Failure as ex:
        return json.dumps({'ok': False, 'errorCode': ex.code, 'message': ex.message, 'httpStatus': ex.status})
    except (TypeError, ValueError, KeyError, AttributeError):
        return json.dumps({'ok': False, 'errorCode': 'INVALID_ARGS', 'message': 'Administrative argument contract is invalid.', 'httpStatus': 422})


def handle(action, args):
    if not isinstance(args, dict):
        raise Failure('INVALID_ARGS', 'JSON object required.')
    if action == 'publish_component':
        return publish_component(args)
    contracts = {'save_bindings': {'workflowId', 'bindings', 'expectedRevision'}, 'list_templates': set(), 'list_productions': set(), 'list_workflows': {'production'}, 'create_managed_workflow': {'templateId', 'production', 'name'}, 'save_binding': {'bindingId', 'payload', 'expectedRevision'}, 'get_workflow': {'workflowId'}, 'insert_decision_slot': {'workflowId', 'expectedRevision'}, 'preview_input': {'workflowId', 'binding', 'example'}, 'validate_workflow': {'workflowId'}, 'preview_publish': {'workflowId'}, 'list_releases': {'workflowId'}, 'rollback_workflow': {'workflowId', 'releaseId', 'expectedRevision'}, 'publish_workflow': {'workflowId', 'revision', 'baseHash', 'approvalRef', 'idempotencyKey'}}
    if action not in contracts or set(args) - contracts[action]:
        raise Failure('INVALID_ARGS', 'Unknown administrative action or fields.')
    if action == 'list_templates':
        return [{'templateId': 'decision-routing-v1', 'name': 'AI Decision routing', 'version': 1, 'requestClass': 'Studio.Msg.WorkflowRequest', 'description': 'Managed decision blocks with static routes and deterministic fallback.'}, {'templateId': 'blood-stock-v1', 'name': 'Blood-center stock decision', 'version': 1, 'requestClass': 'Studio.Msg.StockWorkflowRequest', 'description': 'Synthetic A request; READ stock; validated B/C/REVIEW routing.'}]
    if action == 'list_productions':
        return productions()
    if action == 'list_workflows':
        production = args['production']
        installed = hosts(production)
        managed = []
        for identifier in ids():
            revision = read('latest:' + identifier)
            summary = read('draft:' + identifier + ':' + str(revision), {})
            if summary.get('production') == production:
                managed.append(get(identifier, include_dependencies=False))
        classes = {w.get('className') for w in managed}
        for host in installed:
            if host['className'] not in classes and str(B().Source(host['className'])):
                item = json.loads(str(B().ReadDefinition(host['className'])._ToJSON()))
                item.update(workflowId='host:' + production + '|' + host['name'], production=production, hostName=host['name'])
                managed.append(item)
        return managed
    if action == 'create_managed_workflow':
        if args.get('templateId') not in ('decision-routing-v1', 'blood-stock-v1'):
            raise Failure('TEMPLATE_DENIED', 'Choose an installed versioned template.')
        production = args.get('production', '')
        hosts(production)
        identifier = uuid.uuid4().hex[:16]
        binding = {'bindingId': identifier + ':decision', 'agentRef': {'id': 'event-review', 'revision': 1}, 'inputs': [{'source': 'request.EventId', 'target': 'eventId', 'required': True}, {'source': 'request.Description', 'target': 'description', 'required': False}], 'outputs': {'action': 'context.Action'}, 'routes': {'ACCEPT': 'AcceptOperation', 'REVIEW': 'ReviewOperation'}, 'fallback': {'action': 'REVIEW', 'target': 'ReviewOperation'}, 'timeouts': {'agentMs': 30000}}
        stock = args['templateId'] == 'blood-stock-v1'
        request_class = 'Studio.Msg.StockWorkflowRequest' if stock else 'Studio.Msg.WorkflowRequest'
        if stock:
            binding.update(agentRef={'id': 'blood-stock', 'revision': 1}, inputs=[{'source': 'request.BloodGroup', 'target': 'group', 'required': True}, {'source': 'request.Units', 'target': 'units', 'required': True}], routes={'B': 'StockCenterB', 'C': 'StockCenterC', 'REVIEW': 'StockReview'}, fallback={'action': 'REVIEW', 'target': 'StockReview'})
        source = xml(binding, False, request_class)
        workflow = {'workflowId': identifier, 'name': args.get('name', 'Workflow ' + identifier[:8]), 'templateId': args['templateId'], 'templateVersion': 1, 'production': production, 'className': '', 'hostName': 'StudioW' + identifier, 'requestClass': request_class, 'managed': True, 'decisionAttached': False, 'decisionSlotAvailable': True, 'revision': 1, 'bindingRevision': 1, 'baseHash': digest(source), 'source': source, 'binding': binding}
        write('workflows', ids() + [identifier])
        return append(workflow)
    if action == 'save_binding':
        binding = args.get('payload', {})
        identifier = args.get('bindingId', '').split(':')[0]
        workflow = get(identifier)
        if not workflow['managed']:
            raise Failure('READ_ONLY_BPL', workflow.get('readOnlyReason', 'Read-only BPL.'), 409)
        if type(args.get('expectedRevision')) is not int or args['expectedRevision'] != workflow['bindingRevision']:
            raise Failure('BINDING_REVISION_CONFLICT', 'Binding revision changed.', 409)
        if binding.get('bindingId') not in {b['bindingId'] for b in bindings_of(workflow)} or set(binding) - {'bindingId', 'agentRef', 'inputs', 'outputs', 'routes', 'fallback', 'timeouts', 'runtime', 'outputSchema'}:
            raise Failure('INVALID_BINDING', 'Binding identity or fields are invalid.')
        bindings = [binding if b['bindingId'] == binding['bindingId'] else b for b in bindings_of(workflow)]
        candidate = dict(workflow, binding=bindings[0], bindings=bindings)
        result = validate(candidate)
        if not result['valid']:
            raise Failure('BINDING_INVALID', '; '.join(result['issues']))
        candidate.update(revision=workflow['revision'] + 1, bindingRevision=workflow['bindingRevision'] + 1)
        # baseHash stays the current installed XML hash until the next release.
        candidate['source'] = workflow_xml(bindings, request_class=workflow['requestClass'])
        return append(candidate)
    workflow = get(args.get('workflowId', ''))
    if action == 'get_workflow':
        return workflow
    if action == 'save_bindings':
        if not workflow['managed']:
            raise Failure('READ_ONLY_BPL', 'Only recognized templates can be edited.', 409)
        if type(args.get('expectedRevision')) is not int or args['expectedRevision'] != workflow['bindingRevision']:
            raise Failure('BINDING_REVISION_CONFLICT', 'Binding revision changed.', 409)
        bindings = args.get('bindings')
        if not isinstance(bindings, list) or not 1 <= len(bindings) <= 8:
            raise Failure('INVALID_BINDINGS', 'One to eight decision blocks required.')
        names = [b.get('bindingId', '') for b in bindings if isinstance(b, dict)]
        prefix = re.escape(workflow['workflowId'])
        if len(names) != len(bindings) or len(set(names)) != len(names) or any(not re.fullmatch(prefix + r':[A-Za-z][A-Za-z0-9_]{0,63}', n) for n in names):
            raise Failure('INVALID_POINT_ID', 'Unique workflow-scoped point identifiers required.')
        candidate = dict(workflow, binding=bindings[0], bindings=bindings, schemaVersion=2, decisionAttached=True, decisionSlotAvailable=False)
        validation = validate(candidate)
        if not validation['valid']:
            raise Failure('BINDING_INVALID', '; '.join(validation['issues'])[:900])
        candidate.update(revision=workflow['revision']+1, bindingRevision=workflow['bindingRevision']+1, source=workflow_xml(bindings, request_class=workflow['requestClass']))
        return append(candidate)
    if action == 'insert_decision_slot':
        if not workflow['managed']:
            raise Failure('READ_ONLY_BPL', 'Only recognized templates accept a decision slot.', 409)
        if workflow.get('decisionAttached', True):
            raise Failure('SLOT_ALREADY_PRESENT', 'The managed template already contains its single AI Decision slot.', 409)
        if args.get('expectedRevision') != workflow['revision']:
            raise Failure('REVISION_CONFLICT', 'Draft revision changed.', 409)
        workflow.update(decisionAttached=True, decisionSlotAvailable=False, revision=workflow['revision'] + 1, source=xml(workflow['binding'], request_class=workflow['requestClass']))
        return append(workflow)
    if action == 'preview_input':
        binding = args.get('binding', workflow['binding'])
        point = next((i for i, b in enumerate(bindings_of(workflow)) if b['bindingId'] == binding.get('bindingId')), 0)
        context = {'Action': 'PREVIOUS_ACTION', 'Reason': 'Previous decision output (schema preview only)'} if point else {}
        result = json.loads(str(iris.cls('Studio.Runtime.InputMapper').Preview(workflow['requestClass'], json.dumps(args.get('example', {})), json.dumps(binding), json.dumps(context))))
        return dict(result['data'], valid=result['ok'], contextSource='schema-example' if point else 'empty-initial-context')
    if action == 'list_releases':
        return [read('release:' + i) for i in read('releases:' + workflow['workflowId'], [])]
    if not workflow['managed']:
        raise Failure('READ_ONLY_BPL', workflow.get('readOnlyReason', 'Read-only BPL.'), 409)
    if action == 'validate_workflow':
        return validate(workflow)
    if action == 'preview_publish':
        previous = str(B().Source(workflow['className'])) if workflow['className'] else ''
        released = read('release:' + read('active:' + workflow['workflowId'], ''), {})
        old_bindings = bindings_of(released) if released.get('binding') else []
        return {
            'baseHash': workflow['baseHash'], 'sourceHash': digest(workflow['source']),
            'revision': workflow['revision'], 'validation': validate(workflow),
            'scope': 'Native BPL class and Production host configuration',
            'impact': dependencies(workflow),
            'diff': '\n'.join(difflib.unified_diff(previous.splitlines(), workflow['source'].splitlines(),
                fromfile='installed BPL', tofile='draft BPL', lineterm='')),
            'bindingDiff': '\n'.join(difflib.unified_diff(json.dumps(old_bindings, indent=2).splitlines(),
                json.dumps(bindings_of(workflow), indent=2).splitlines(),
                fromfile='released binding', tofile='draft binding', lineterm='')),
        }
    if action == 'rollback_workflow':
        release = read('release:' + str(args.get('releaseId', '')))
        if not release or release['workflowId'] != workflow['workflowId']:
            raise Failure('RELEASE_NOT_FOUND', 'Release does not belong to workflow.', 404)
        if args.get('expectedRevision') != workflow['revision']:
            raise Failure('REVISION_CONFLICT', 'Draft revision changed.', 409)
        workflow.update(binding=release['binding'], revision=workflow['revision'] + 1, bindingRevision=workflow['bindingRevision'] + 1, bindings=deepcopy(bindings_of(release)), schemaVersion=2, decisionAttached=True, decisionSlotAvailable=False, source=workflow_xml(bindings_of(release), request_class=workflow['requestClass']), rollbackOf=release['releaseId'])
        return append(workflow)
    if action == 'publish_workflow':
        key = args.get('idempotencyKey', '')
        if not key or len(key) > 128 or not args.get('approvalRef'):
            raise Failure('APPROVAL_REQUIRED', 'Approval reference and bounded idempotency key required.')
        fingerprint = digest(json.dumps(args, sort_keys=True))
        cached = read('idempotency:' + key)
        if cached:
            if cached['fingerprint'] != fingerprint:
                raise Failure('IDEMPOTENCY_CONFLICT', 'Idempotency key already used.', 409)
            return cached['result']
        if args.get('baseHash') != workflow['baseHash'] or args.get('revision') != workflow['revision']:
            raise Failure('BPL_SOURCE_CONFLICT', 'Draft revision or source hash changed.', 409)
        if read('published:' + workflow['workflowId'] + ':' + str(workflow['revision'])):
            raise Failure('REVISION_ALREADY_PUBLISHED', 'Draft revision already published.', 409)
        validation = validate(workflow)
        if not validation['valid']:
            raise Failure('WORKFLOW_INVALID', '; '.join(validation['issues']))
        class_name = 'Studio.Managed.W' + workflow['workflowId'] + 'R' + str(workflow['revision'])
        existing = str(B().Source(class_name))
        if existing:
            if ET.tostring(ET.fromstring(existing)) != ET.tostring(ET.fromstring(workflow['source'])):
                raise Failure('IMMUTABLE_CLASS_CONFLICT', 'Generated revision class already exists with different source.', 409)
        else:
            status = W().Stage(class_name, workflow['source'])
            if iris.cls('%SYSTEM.Status').IsError(status):
                raise Failure('STAGED_COMPILE_FAILED', 'Native generated BPL compilation failed.')
        if workflow['className'] and digest(str(B().Source(workflow['className']))) != workflow['baseHash']:
            raise Failure('BPL_SOURCE_CONFLICT', 'Installed source changed during staging.', 409)
        installed_source = str(B().Source(class_name))
        installed_hash = digest(installed_source)
        release_id = uuid.uuid4().hex
        release_host = workflow['hostName'] + 'R' + str(workflow['revision'])
        manifest = {'releaseId': release_id, 'templateId': workflow['templateId'], 'workflowId': workflow['workflowId'], 'revision': workflow['revision'], 'bindingRevision': workflow['bindingRevision'], 'sourceHash': installed_hash, 'baseHash': installed_hash, 'previousBaseHash': workflow['baseHash'], 'binding': workflow['binding'], 'agent': agent(workflow['binding']), 'compiledBPLClass': class_name, 'production': workflow['production'], 'hostName': release_host, 'serviceName': 'StudioWorkflowService', 'requestClass': workflow['requestClass'], 'compiled': True, 'published': False, 'activated': False, 'liveAIValidated': False, 'approvalRef': args['approvalRef'], 'scope': 'Native BPL compilation and Production host installation; activation requires this Production running.'}
        manifest.update(schemaVersion=2, bindings=deepcopy(bindings_of(workflow)), agents={b['bindingId']: agent(b) for b in bindings_of(workflow)})
        # Each release has its own host, so old release IDs always run their pinned class.
        deployment = json.loads(str(W().Install(workflow['production'], release_host, class_name)))
        if not deployment['installed']:
            raise Failure('DEPLOY_FAILED', 'Native Production host installation failed.')
        manifest.update(deployment, published=True)
        write('release:' + release_id, manifest)
        write('releases:' + workflow['workflowId'], read('releases:' + workflow['workflowId'], []) + [release_id])
        write('published:' + workflow['workflowId'] + ':' + str(workflow['revision']), release_id)
        write('active:' + workflow['workflowId'], release_id)
        # A publication changes metadata only; its draft revision remains immutable.
        workflow.update(className=class_name, baseHash=installed_hash, source=installed_source, revision=workflow['revision'] + 1, activeReleaseId=release_id)
        append(workflow)
        write('idempotency:' + key, {'fingerprint': fingerprint, 'result': manifest})
        return manifest
    raise Failure('ACTION_NOT_SUPPORTED', 'Administrative action not supported.', 501)


def reconcile():
    """Restore generated hosts after an intentional source reload of a Production."""
    results = []
    for identifier in ids():
        for release_id in read('releases:' + identifier, []):
            manifest = read('release:' + release_id)
            if manifest and digest(str(B().Source(manifest['compiledBPLClass']))) == manifest['sourceHash']:
                deployment = json.loads(str(W().Install(manifest['production'], manifest['hostName'], manifest['compiledBPLClass'])))
                results.append(dict(deployment, releaseId=release_id))
    for component_id in read('components', []):
        config = read('component:' + component_id)
        if config and config.get('installed'):
            deployment = json.loads(str(W().Install(config['production'], config['hostName'], config['className'])))
            results.append(dict(deployment, componentId=component_id))
    return json.dumps(results)



def publish_component(args):
    required = {'production', 'hostName', 'agentId', 'agentRevision', 'allowedActions', 'fallbackAction', 'policy'}
    if set(args) != required:
        raise Failure('INVALID_COMPONENT', 'Exact component configuration required.')
    available = hosts(args['production'])
    name = args['hostName']
    if not isinstance(name, str) or not re.fullmatch(r'[A-Za-z][A-Za-z0-9_]{0,79}', name):
        raise Failure('INVALID_HOST', 'Use a bounded alphanumeric host name.')
    if any(h['name'] == name for h in available):
        raise Failure('HOST_EXISTS', 'Choose a new host name; existing components are never overwritten.', 409)
    if type(args['agentRevision']) is not int or args['agentRevision'] < 1:
        raise Failure('INVALID_REVISION', 'Pin an existing positive agent revision.')
    definition = agent({'agentRef': {'id': args['agentId'], 'revision': args['agentRevision']}})
    actions = args['allowedActions']
    if not isinstance(actions, list) or not 1 <= len(actions) <= 40 or any(not isinstance(a, str) or not re.fullmatch(r'[A-Z][A-Z_]{0,39}', a) for a in actions) or len(set(actions)) != len(actions):
        raise Failure('INVALID_ACTIONS', 'One to forty unique uppercase actions required.')
    if args['fallbackAction'] not in actions or args['policy'] not in ('schema', 'blood-stock'):
        raise Failure('INVALID_POLICY', 'Choose an allowed fallback and installed validation policy.')
    if args['policy'] == 'blood-stock' and (set(actions) != {'B','C','REVIEW'} or args['fallbackAction'] != 'REVIEW' or 'Studio.Tools.BloodStockTools' not in definition['toolSetRefs']):
        raise Failure('INVALID_STOCK_POLICY', 'Stock policy requires B/C/REVIEW, REVIEW fallback and ReadStock.')
    identifier = uuid.uuid4().hex
    cls = 'Studio.Components.A' + identifier
    config = dict(args, componentId=identifier, className=cls, agent=definition)
    status = W().StageComponent(identifier)
    if iris.cls('%SYSTEM.Status').IsError(status):
        raise Failure('COMPONENT_COMPILE_FAILED', 'Native Operation compilation failed.')
    write('component:' + identifier, config)
    deployment = json.loads(str(W().Install(args['production'], name, cls)))
    if not deployment['installed']:
        raise Failure('COMPONENT_INSTALL_FAILED', 'Production installation failed; existing hosts preserved.')
    config.update(deployment)
    write('component:' + identifier, config)
    write('components', read('components', []) + [identifier])
    return config
