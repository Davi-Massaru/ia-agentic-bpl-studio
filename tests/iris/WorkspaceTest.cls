/// Native registry regression: unique workflows, isolated bindings, immutable history and rollback drafts.
Class Studio.Tests.WorkspaceTest Extends %RegisteredObject
{
ClassMethod Run() As %String [ Language = python ]
{
    import iris,json,uuid
    admin=iris.cls('Studio.Admin.ControlPlane')
    def call(action,args=None,expected=True):
        result=json.loads(str(admin.Dispatch(action,json.dumps(args or {}))))
        assert result['ok'] is expected, result
        return result.get('data',result)
    one=call('create_managed_workflow',{'templateId':'decision-routing-v1','production':'Studio.Demo.Production'})
    two=call('create_managed_workflow',{'templateId':'decision-routing-v1','production':'Studio.Demo.Production'})
    assert one['workflowId']!=two['workflowId']
    assert not call('validate_workflow',{'workflowId':one['workflowId']})['valid']
    one=call('insert_decision_slot',{'workflowId':one['workflowId'],'expectedRevision':one['revision']})
    assert one['decisionAttached'] and one['revision']==2
    assert call('insert_decision_slot',{'workflowId':one['workflowId'],'expectedRevision':2},False)['errorCode']=='SLOT_ALREADY_PRESENT'
    before=json.loads(iris.cls('Studio.Admin.Workspace').Read('draft:'+one['workflowId']+':2'))
    payload=json.loads(json.dumps(one['binding']))
    payload['inputs'][1]['source']='constant:stable'
    saved=call('save_binding',{'bindingId':payload['bindingId'],'payload':payload,'expectedRevision':one['bindingRevision']})
    assert saved['bindingRevision']==2 and saved['revision']==3
    assert call('get_workflow',{'workflowId':two['workflowId']})['binding']['inputs'][1]['source']=='request.Description'
    assert json.loads(iris.cls('Studio.Admin.Workspace').Read('draft:'+one['workflowId']+':2'))==before
    assert call('save_binding',{'bindingId':payload['bindingId'],'payload':payload,'expectedRevision':1},False)['errorCode']=='BINDING_REVISION_CONFLICT'
    preview=call('preview_publish',{'workflowId':one['workflowId']})
    assert preview['validation']['valid'] and preview['diff']
    args={'workflowId':one['workflowId'],'revision':saved['revision'],'baseHash':saved['baseHash'],'approvalRef':'native-sandbox-regression','idempotencyKey':uuid.uuid4().hex}
    release=call('publish_workflow',args)
    assert release['compiled'] and release['installed'] and release['published']
    assert call('publish_workflow',args)==release
    args['revision']+=1
    assert call('publish_workflow',args,False)['errorCode']=='IDEMPOTENCY_CONFLICT'
    latest=call('get_workflow',{'workflowId':one['workflowId']})
    rollback=call('rollback_workflow',{'workflowId':one['workflowId'],'releaseId':release['releaseId'],'expectedRevision':latest['revision']})
    assert rollback['revision']==latest['revision']+1 and rollback['binding']==release['binding']
    assert json.loads(iris.cls('Studio.Admin.Workspace').ReleaseManifest(release['releaseId'])._ToJSON())==release
    args={'workflowId':one['workflowId'],'revision':rollback['revision'],'baseHash':rollback['baseHash'],'approvalRef':'native-sandbox-regression','idempotencyKey':uuid.uuid4().hex}
    rolled_release=call('publish_workflow',args)
    assert rolled_release['compiledBPLClass']!=release['compiledBPLClass'] and rolled_release['hostName']!=release['hostName']
    assert json.loads(iris.cls('Studio.Admin.Workspace').ReleaseManifest(release['releaseId'])._ToJSON())==release
    assert len(call('list_releases',{'workflowId':one['workflowId']}))==2
    arbitrary=call('get_workflow',{'workflowId':'class:Studio.BloodDemo.Routing'})
    assert not arbitrary['managed'] and arbitrary['readOnlyReason']
    return json.dumps({'ok':True,'workflowId':one['workflowId'],'secondWorkflowId':two['workflowId'],'releaseId':release['releaseId'],'rollbackReleaseId':rolled_release['releaseId'],'activated':release['activated'],'checks':17})
}
}
