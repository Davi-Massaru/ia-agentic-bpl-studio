Include %occStatus
/// Stock policy uses Embedded Python; Output is preserved for native callers.
Class Studio.BloodDemo.CandidateValidator Extends %RegisteredObject
{
ClassMethod Validate(pRequest As Studio.BloodDemo.Request, pRaw As %String, Output pResult As %DynamicObject) As %Status
{
    Set pResult={"status":"INVALID","action":"REVIEW"}
    Set sc=..ValidatePython(pRequest,pRaw,pResult)
    If $$$ISOK(sc) Set pResult=pResult.value
    Return sc
}
ClassMethod ValidatePython(pRequest As Studio.BloodDemo.Request, pRaw As %String, pResult As %DynamicObject) As %Status [ Language = python ]
{
    import iris
    iris.cls('Studio.Runtime.Python').Prepare()
    from studio.native.agent_runtime import stock_candidate
    return stock_candidate(pRequest, pRaw, pResult)
}
}
