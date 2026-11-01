Include %occStatus
/// Embedded Python validates data; native wrappers preserve Output contracts.
Class Studio.AI.DecisionValidator Extends %RegisteredObject
{
ClassMethod ParseCandidate(pRawResponse As %String, Output pCandidate As %DynamicObject) As %Status
{
    Set pCandidate="",result={}
    Set sc=..ParsePython(pRawResponse,result)
    If $$$ISOK(sc) Set pCandidate=result.value
    Return sc
}
ClassMethod ParsePython(pRaw As %String, pResult As %DynamicObject) As %Status [ Language = python ]
{
    import iris
    iris.cls('Studio.Runtime.Python').Prepare()
    from studio.native.agent_runtime import parse
    return parse(pRaw, pResult)
}
ClassMethod Validate(pBinding As Studio.Model.DecisionBinding, pRawResponse As %String, Output pValidated As %DynamicObject) As %Status
{
    Set pValidated={"status":"INVALID","action":"REVIEW","errorCode":"CANDIDATE_INVALID"}
    Set sc=..ValidatePython(pBinding,pRawResponse,pValidated)
    If $$$ISOK(sc) Set pValidated=pValidated.value
    Return sc
}
ClassMethod ValidatePython(pBinding As Studio.Model.DecisionBinding, pRaw As %String, pResult As %DynamicObject) As %Status [ Language = python ]
{
    import iris
    iris.cls('Studio.Runtime.Python').Prepare()
    from studio.native.agent_runtime import validate
    return validate(pBinding, pRaw, pResult)
}
ClassMethod ResolveRoute(pBinding As Studio.Model.DecisionBinding, pStatus As %String, pAction As %String, Output pOperationName As %String) As %Status
{
    Set result={"target":""}
    Set sc=..RoutePython(pBinding,pStatus,pAction,result)
    Set pOperationName=result.target
    Return sc
}
ClassMethod RoutePython(pBinding As Studio.Model.DecisionBinding, pStatus As %String, pAction As %String, pResult As %DynamicObject) As %Status [ Language = python ]
{
    import iris
    iris.cls('Studio.Runtime.Python').Prepare()
    from studio.native.agent_runtime import resolve_route
    return resolve_route(pBinding, pStatus, pAction, pResult)
}
}
