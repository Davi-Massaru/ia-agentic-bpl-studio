Include %occStatus
/// Explicit fixtures through Service -> compiled BPL -> bridge -> local sink, never an AI proof.
Class Studio.Tests.WorkflowRuntimeTest Extends %RegisteredObject
{
ClassMethod Run(pReleaseId As %String) As %Status
{
    Set manifest=##class(Studio.Runtime.Releases).Manifest(pReleaseId)
    If '##class(Studio.Runtime.Releases).SimulationAllowed(manifest) Return $$$ERROR($$$GeneralError,"LOCAL_SANDBOX_REQUIRED")
    Set routes=manifest.binding.routes,iterator=routes.%GetIterator(),count=0
    While iterator.%GetNext(.action,.target) {
        Set candidate={}
        // Real LLM reasons often exceed the BPL default string length of 50.
        Do candidate.%Set("action",action),candidate.%Set("reason",$Translate($Justify("",512)," ","x"))
        Set sc=..Submit(pReleaseId,candidate.%ToJSON(),"",.trace)
        If $$$ISERR(sc) Return sc
        If trace.status'="SUCCESS" Return $$$ERROR($$$GeneralError,"VALID_FIXTURE_FAILED")
        If trace.action'=action Return $$$ERROR($$$GeneralError,"CONFIGURED_ACTION_NOT_USED")
        If trace.destination'=target Return $$$ERROR($$$GeneralError,"CONFIGURED_ROUTE_NOT_USED")
        If trace.receipt'=("LOCAL_ONLY:"_target) Return $$$ERROR($$$GeneralError,"NATIVE_RECEIPT_MISSING")
        Set count=count+1
    }
    If count<2 Return $$$ERROR($$$GeneralError,"TWO_CONFIGURED_ROUTES_REQUIRED")
    Set cases=$ListBuild("not JSON","[]","{""action"":""UNREGISTERED""}","{""action"":true}","{""action"":""ACCEPT"",""target"":""ExternalOperation""}")
    For i=1:1:$ListLength(cases) {
        Set sc=..Submit(pReleaseId,$ListGet(cases,i),"",.trace)
        If $$$ISERR(sc) Return sc
        If trace.status'="INVALID" Return $$$ERROR($$$GeneralError,"INVALID_FIXTURE_ACCEPTED")
        If trace.destination'=manifest.binding.fallback.target Return $$$ERROR($$$GeneralError,"INVALID_FALLBACK_MISSING")
    }
    For fault="TIMEOUT","PROVIDER_DOWN","TOOL_DENIED" {
        Set sc=..Submit(pReleaseId,"",fault,.trace)
        If $$$ISERR(sc) Return sc
        Set expected=$Select(fault="TIMEOUT":"TIMEOUT",fault="TOOL_DENIED":"DENIED",1:"ERROR")
        If trace.status'=expected Return $$$ERROR($$$GeneralError,"FAULT_STATUS_LOST")
        If trace.destination'=manifest.binding.fallback.target Return $$$ERROR($$$GeneralError,"FAULT_FALLBACK_MISSING")
    }
    Set args={"payload":{"EventId":"invalid","Mode":"SIMULATION","UnknownProperty":"rejected"}}
    Do args.%Set("releaseId",pReleaseId)
    Set result=##class(%DynamicObject).%FromJSON(##class(Studio.Admin.TestHarness).ExecuteJson(args.%ToJSON()))
    If result.ok Return $$$ERROR($$$GeneralError,"UNKNOWN_REQUEST_FIELD_ACCEPTED")
    Set args={"payload":{"EventId":17,"Mode":"SIMULATION"}}
    Do args.%Set("releaseId",pReleaseId)
    Set result=##class(%DynamicObject).%FromJSON(##class(Studio.Admin.TestHarness).ExecuteJson(args.%ToJSON()))
    If result.ok Return $$$ERROR($$$GeneralError,"REQUEST_TYPE_COERCED")
    Set args={"payload":{"EventId":"synthetic","Mode":"LIVE","CandidateJson":"{}"}}
    Do args.%Set("releaseId",pReleaseId)
    Set result=##class(%DynamicObject).%FromJSON(##class(Studio.Admin.TestHarness).ExecuteJson(args.%ToJSON()))
    If result.ok Return $$$ERROR($$$GeneralError,"LIVE_FIXTURE_ACCEPTED")
    Set original=manifest.baseHash
    Do manifest.%Set("baseHash","stale")
    If ##class(Studio.Runtime.Releases).Compatible(manifest) Return $$$ERROR($$$GeneralError,"STALE_RELEASE_ACCEPTED")
    Do manifest.%Set("baseHash",original),manifest.%Set("production","Unauthorized.Production")
    If ##class(Studio.Runtime.Releases).SimulationAllowed(manifest) Return $$$ERROR($$$GeneralError,"SIMULATION_ESCAPED_SANDBOX")
    Return $$$OK
}
ClassMethod Submit(pReleaseId As %String, pCandidate As %String, pFault As %String, Output pTrace As %DynamicObject) As %Status
{
    Set args={"payload":{"EventId":"synthetic-test","Description":"Generic native fixture","Mode":"SIMULATION"}}
    Do args.%Set("releaseId",pReleaseId),args.payload.%Set("CandidateJson",pCandidate),args.payload.%Set("SimulationFault",pFault)
    Set result=##class(%DynamicObject).%FromJSON(##class(Studio.Admin.TestHarness).ExecuteJson(args.%ToJSON()))
    If 'result.ok Return $$$ERROR($$$GeneralError,"EXECUTION_FAILED:"_result.%ToJSON())
    Set run=##class(%DynamicObject).%FromJSON(##class(Studio.Admin.TestHarness).GetRunJson(result.data.executionId))
    If 'run.ok Return $$$ERROR($$$GeneralError,"TRACE_NOT_FOUND")
    Set pTrace=run.data
    If pTrace.mode'="SIMULATION" Return $$$ERROR($$$GeneralError,"SIMULATION_LABEL_MISSING")
    If pTrace.%Get("messageId")="" Return $$$ERROR($$$GeneralError,"NATIVE_MESSAGE_ID_MISSING")
    If pTrace.%Get("interopSessionId")="" Return $$$ERROR($$$GeneralError,"NATIVE_SESSION_ID_MISSING")
    If pTrace.%Get("decisionExecutionId")="" Return $$$ERROR($$$GeneralError,"DECISION_EXECUTION_ID_MISSING")
    If pTrace.%Get("agentSessionId")'="" Return $$$ERROR($$$GeneralError,"FABRICATED_AI_SESSION")
    If pTrace.toolCalls.%Size()'=0 Return $$$ERROR($$$GeneralError,"FABRICATED_AI_TOOLS")
    Return $$$OK
}
/// Real native BPL timer, using a slow sandbox worker and checking the late reply cannot reroute.
ClassMethod Deadline(pReleaseId As %String) As %Status
{
    Set manifest=##class(Studio.Runtime.Releases).Manifest(pReleaseId)
    If manifest.binding.timeouts.agentMs>500 Return $$$ERROR($$$GeneralError,"SHORT_DEADLINE_RELEASE_REQUIRED")
    Set sc=..Submit(pReleaseId,"{""action"":""ACCEPT""}","DELAY",.trace)
    If $$$ISERR(sc) Return sc
    If trace.status'="TIMEOUT" Return $$$ERROR($$$GeneralError,"NATIVE_DEADLINE_NOT_ENFORCED")
    If trace.destination'=manifest.binding.fallback.target Return $$$ERROR($$$GeneralError,"DEADLINE_FALLBACK_MISSING")
    Hang 3
    If $Get(^StudioAudit(trace.executionId,"destination"))'=manifest.binding.fallback.target Return $$$ERROR($$$GeneralError,"LATE_RESPONSE_REROUTED_WORKFLOW")
    Set result=##class(%DynamicObject).%FromJSON(##class(Studio.Admin.TestHarness).GetRunJson(trace.executionId))
    If result.data.status'="TIMEOUT" Return $$$ERROR($$$GeneralError,"LATE_RESPONSE_REWROTE_TRACE")
    Return $$$OK
}
}
