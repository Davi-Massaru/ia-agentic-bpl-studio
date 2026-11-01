Class Studio.Tests.TraceAcceptance Extends %RegisteredObject
{
ClassMethod Run() As %String [ Language = python ]
{
    import iris, json, uuid
    iris.cls('Studio.Runtime.Python').Prepare()
    from studio.native.tracing import native_start, native_finish
    from studio.native.vector_retrieval import search_fixture
    execution = 'trace-test-' + uuid.uuid4().hex
    # Dedicated, reusable fixture table; never drop or overwrite application tables.
    check = iris.sql.exec("SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='StudioVector' AND TABLE_NAME='TraceFixture'")
    if not list(check)[0][0]:
        iris.sql.exec('CREATE TABLE StudioVector.TraceFixture (DocumentId VARCHAR(80) PRIMARY KEY, ContentHash VARCHAR(80), ContentVector VECTOR(DOUBLE,3))')
    for identifier, vector in [('dpi689-a','1,0,0'),('dpi689-b','0,1,0')]:
        exists = list(iris.sql.exec('SELECT COUNT(*) FROM StudioVector.TraceFixture WHERE DocumentId=?', identifier))[0][0]
        if not exists:
            iris.sql.exec('INSERT INTO StudioVector.TraceFixture VALUES (?, ?, TO_VECTOR(?, DOUBLE))', identifier, 'synthetic-'+identifier, vector)
    root = native_start(execution, execution, '', 'operation', 'Acceptance')
    assert root, 'Recorder did not persist'
    iris.cls('Studio.Trace.Recorder').Context(execution, root)
    try:
        result = json.loads(search_fixture('[1,0,0]', 2))
        assert result['documents'][0]['documentId'] == 'dpi689-a', result
        assert abs(result['documents'][0]['score'] - 1) < 0.0001
        native_finish(execution, root, 'SUCCESS')
        observations = json.loads(iris.gref('^StudioAudit')[execution, 'observations'])
        assert len(observations) == 2 and all(x['status'] == 'SUCCESS' for x in observations)
        assert observations[1]['parentObservationId'] == root
        return json.dumps(dict(ok=True, executionId=execution, documents=result['documents'], observations=observations, providerInvoked=False))
    finally:
        iris.cls('Studio.Trace.Recorder').Context('', '')
}
}
