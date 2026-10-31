Include %occStatus
/// Optional synthetic-vector fixture, not a semantic embedding model or arbitrary SQL tool.
Class Studio.Tools.VectorReadTools Extends %AI.ToolSet
{
XData Definition [ MimeType = application/xml ]
{
<ToolSet Name="VectorReadTools"><Tool Name="SearchFixtureVectors" Method="SearchFixtureVectors"/></ToolSet>
}
/// Search the installed synthetic three-dimensional fixture. pVectorJson is a JSON array of three numbers.
ClassMethod SearchFixtureVectors(pVectorJson As %String, pTopK As %Integer = 3) As %String [ Language = python ]
{
    import iris
    iris.cls('Studio.Runtime.Python').Prepare()
    from studio.native.vector_retrieval import search_fixture
    return search_fixture(pVectorJson, int(pTopK))
}
ClassMethod NextObservation(pExecution As %String) As %Integer
{
    Return $Increment(^StudioAudit(pExecution,"toolCount"))
}
}
