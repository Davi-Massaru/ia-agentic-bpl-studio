/// Isolated generated releases in the running synthetic Production; existing hosts stay intact.
Class Studio.Tests.VisualDesignerTest Extends %RegisteredObject
{
ClassMethod Debug(pLive As %Boolean = 0) As %String [ Language = python ]
{
    import iris,traceback
    try: return str(iris.cls('Studio.Tests.VisualDesignerTest').Run(pLive))
    except Exception: return traceback.format_exc()
}
ClassMethod Run(pLive As %Boolean = 0) As %String [ Language = python ]
{
    import iris,json,uuid,copy,time
    iris.cls('Studio.Runtime.Python').Prepare()
    admin=iris.cls('Studio.Admin.ControlPlane')
    def call(action,args=None,ok=True):
        result=json.loads(str(admin.Dispatch(action,json.dumps(args or {}))))
        assert result['ok'] is ok, result
        return result.get('data',result)
    production=str(iris.cls('Ens.Director').GetActiveProductionName())
    assert production in ('Studio.Demo.Production','Studio.BloodDemo.Production')
    w=call('create_managed_workflow',dict(templateId='decision-routing-v1',production=production))
    first=copy.deepcopy(w['binding'])
    if production=='Studio.BloodDemo.Production':
        first['routes']={'ACCEPT':'StockCenterB','REVIEW':'StockReview'}
        first['fallback']={'action':'REVIEW','target':'StockReview'}
    aid='visual-'+uuid.uuid4().hex[:12]
    definition=dict(providerRef='openai',modelName='gpt-4.1-mini',prompt='Read the event using ReadEvent. Return JSON action ACCEPT if eligible, otherwise REVIEW, with reason and evidenceRefs.',toolSetRefs=['Studio.Tools.EventReadTools'])
    call('save_agent_revision',dict(agentId=aid,definition=definition,baseRevision=0))
    definition['prompt']+=' Explain the event decision concisely.'
    call('save_agent_revision',dict(agentId=aid,definition=definition,baseRevision=1))
    first['agentRef']={'id':aid,'revision':1}
    second=copy.deepcopy(first); second['bindingId']=w['workflowId']+':second'; second['agentRef']['revision']=2
    second['inputs'].append(dict(source='context.Action',target='previousAction',required=True))
    w=call('save_bindings',dict(workflowId=w['workflowId'],bindings=[first,second],expectedRevision=w['bindingRevision']))
    assert len(w['bindings'])==2 and len({n['pointId'] for n in w['graph']['nodes'] if 'pointId' in n})==2
    assert call('save_bindings',dict(workflowId=w['workflowId'],bindings=[first,second],expectedRevision=1),False)['errorCode']=='BINDING_REVISION_CONFLICT'
    args=dict(workflowId=w['workflowId'],revision=w['revision'],baseHash=w['baseHash'],approvalRef='visual-designer-regression',idempotencyKey=uuid.uuid4().hex)
    stale=dict(args,baseHash='stale-source')
    assert call('publish_workflow',stale,False)['errorCode']=='BPL_SOURCE_CONFLICT'
    release=call('publish_workflow',args)
    assert release['activated'] and len(release['agents'])==2, {'stage':'activation','activated':release['activated'],'agents':len(release['agents'])}
    assert call('publish_workflow',args)==release, 'idempotency'
    def execute(mode,fault=''):
        payload={'Mode':mode,'EventId':'E-OK','Description':'Synthetic visual designer regression'}
        if mode=='SIMULATION': payload.update(CandidateJson=json.dumps(dict(action='ACCEPT',reason='fixture',evidenceRefs=[])),SimulationFault=fault)
        result=json.loads(str(iris.cls('Studio.Admin.TestHarness').ExecuteJson(json.dumps(dict(releaseId=release['releaseId'],payload=payload)))))
        assert result['ok'],result
        trace=json.loads(str(iris.cls('Studio.Admin.TestHarness').GetRunJson(result['data']['executionId'])))['data']
        return trace
    trace=execute('SIMULATION')
    assert trace['status']=='SUCCESS',trace
    assert len(trace['points'])==2 and {p['agentRevision'] for p in trace['points']}=={1,2},trace
    failure=execute('SIMULATION','PROVIDER_DOWN')
    assert failure['status']=='ERROR' and len(failure['points'])==1,failure
    latest=call('get_workflow',dict(workflowId=w['workflowId']))
    changed=copy.deepcopy(latest['bindings']); changed[0]['agentRef']['revision']=2
    saved=call('save_bindings',dict(workflowId=w['workflowId'],bindings=changed,expectedRevision=latest['bindingRevision']))
    assert saved['bindings'][1]==second
    pinned=json.loads(str(iris.cls('Studio.Admin.Workspace').ReleaseManifest(release['releaseId'])._ToJSON()))
    assert pinned['bindings'][0]['agentRef']['revision']==1
    restored=call('rollback_workflow',dict(workflowId=w['workflowId'],releaseId=release['releaseId'],expectedRevision=saved['revision']))
    assert restored['bindings']==[first,second]
    live=execute('LIVE') if pLive else None
    if live: assert live['status']=='SUCCESS' and len(live['points'])==2 and all(p['agentSessionId'] for p in live['points']),live
    original_release=release['releaseId']
    delayed=copy.deepcopy(restored['bindings']); delayed[0]['timeouts']['agentMs']=1000
    deadline_draft=call('save_bindings',dict(workflowId=w['workflowId'],bindings=delayed,expectedRevision=restored['bindingRevision']))
    release=call('publish_workflow',dict(workflowId=w['workflowId'],revision=deadline_draft['revision'],baseHash=deadline_draft['baseHash'],approvalRef='visual-timeout-regression',idempotencyKey=uuid.uuid4().hex))
    deadline=execute('SIMULATION','DELAY')
    assert deadline['status']=='TIMEOUT',deadline
    time.sleep(2.2)
    late=json.loads(str(iris.cls('Studio.Admin.TestHarness').GetRunJson(deadline['executionId'])))['data']
    assert late['status']=='TIMEOUT' and len(late['points'])==1,late
    assert late['points'][0]['workflowStatus']=='TIMEOUT'
    return json.dumps(dict(ok=True,workflowId=w['workflowId'],releaseId=original_release,simulation=trace,fallback=failure,deadline=late,live=live))
}
}
