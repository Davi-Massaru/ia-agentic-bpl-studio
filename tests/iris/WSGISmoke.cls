/// Exercises Flask and the real EmbeddedGateway in an authenticated IRIS job.
/// This is not a Web Gateway login/end-to-end browser test.
Class Studio.Tests.WSGISmoke Extends %RegisteredObject
{
ClassMethod Run() As %String [ Language = python ]
{
    import sys,json
    sys.path[:0] = ['/durable/studio-python','/opt/studio/backend']
    from wsgi_iris import create_iris_app
    app=create_iris_app()
    client=app.test_client()
    results=[]
    for path in ['/', '/designer', '/test-trace', '/publisher', '/health', '/api/v1/capabilities',
                 '/api/v1/productions', '/api/v1/workflows?production=Studio.BloodDemo.Production',
                 '/api/v1/workflows/blood-routing', '/api/v1/agents', '/api/v1/toolsets']:
        response=client.get(path)
        results.append({'path':path,'status':response.status_code})
        if response.status_code != 200:
            return json.dumps({'ok':False,'results':results,'error':response.get_json()})
    response=client.post('/api/v1/workflows/blood-routing/validate',json={})
    results.append({'path':'csrf-denied','status':response.status_code})
    if response.status_code!=403: return json.dumps({'ok':False,'results':results})
    token=app.config['STUDIO_CSRF_TOKEN']
    response=client.post('/api/v1/workflows/blood-routing/validate',json={},headers={'X-CSRF-Token':token})
    results.append({'path':'native-validate','status':response.status_code,'data':response.get_json()})
    return json.dumps({'ok':response.status_code==200,'results':results})
}
}
