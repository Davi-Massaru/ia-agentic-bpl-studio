Include %occStatus
/// Reusable native bridge. Fixtures are explicit and restricted to local sandbox releases.
Class Studio.Interop.AgentDecisionOperation Extends Ens.BusinessOperation
{
Parameter INVOCATION = "Queue";
Method HandleDecision(pRequest As Studio.Msg.DecisionRequest, Output pResponse As Studio.Msg.DecisionResponse) As %Status
{
    Set root=pRequest.CorrelationId
    Set release=##class(Studio.Runtime.Releases).Manifest(pRequest.ReleaseId)
    Set multipoint=release.%IsDefined("bindings")&&(release.bindings.%Size()>1)
    If multipoint Set pRequest.CorrelationId=root_":"_$Piece(pRequest.BindingId,":",2)
    Set id=pRequest.CorrelationId
    Set observation=##class(Studio.Trace.Recorder).Start(id,id,"","operation",..%ConfigName)
    Set ^||StudioParentObservation=observation
    Set sc=..Evaluate(pRequest,.pResponse)
    Do ##class(Studio.Trace.Recorder).Finish(id,observation,pResponse.Status)
    Kill ^||StudioParentObservation
    Set output={}
    Do output.%Set("status",pResponse.Status),output.%Set("action",pResponse.Action),output.%Set("reason","[REDACTED]"),output.%Set("errorCode",pResponse.ErrorCode)
    Set ^StudioAudit(id,"output")=output.%ToJSON(),^StudioAudit(id,"errorCode")=pResponse.ErrorCode
    Try {
        Set point={}
        Do point.%Set("pointId",pRequest.BindingId),point.%Set("executionId",id),point.%Set("releaseId",pRequest.ReleaseId),point.%Set("status",pResponse.Status),point.%Set("errorCode",pResponse.ErrorCode),point.%Set("action",pResponse.Action),point.%Set("agentSessionId",pResponse.AgentSessionId)
        Set definition=##class(Studio.Runtime.Releases).Agent(release,pRequest.BindingId)
        Do point.%Set("agentId",definition.agentId),point.%Set("agentRevision",definition.revision)
        Set ^StudioAudit(root,"points",pRequest.BindingId)=point.%ToJSON()
    } Catch traceError { }
    Set pRequest.CorrelationId=root
    Return sc
}
Method Evaluate(pRequest As Studio.Msg.DecisionRequest, Output pResponse As Studio.Msg.DecisionResponse) As %Status
{
    Set pResponse=##class(Studio.Msg.DecisionResponse).%New()
    Set pResponse.DecisionExecutionId=pRequest.CorrelationId,pResponse.Status="DENIED",pResponse.Action="REVIEW",pResponse.ErrorCode="PUBLISHED_BINDING_REQUIRED"
    Try {
        If pRequest.SchemaVersion'="1" Return $$$OK
        Set release=##class(Studio.Runtime.Releases).Manifest(pRequest.ReleaseId)
        If 'release.%IsDefined("binding") Return $$$OK
        Set selected=##class(Studio.Runtime.Releases).Binding(release,pRequest.BindingId)
        If 'selected.%IsDefined("bindingId") Return $$$OK
        Set binding=##class(Studio.Model.DecisionBinding).%New(),definition=##class(Studio.Runtime.Releases).Agent(release,pRequest.BindingId),agent=##class(Studio.Model.AgentDefinition).%New()
        Set binding.RoutesJson=selected.routes.%ToJSON(),binding.FallbackAction=selected.fallback.action,binding.FallbackTarget=selected.fallback.target
        Set pResponse.Action=binding.FallbackAction
        If '##class(Studio.Runtime.Releases).Compatible(release) {
            Set pResponse.ErrorCode="RELEASE_SOURCE_CONFLICT"
            Return $$$OK
        }
        Set input=##class(%DynamicObject).%FromJSON(pRequest.InputJson)
        If ('input.%IsA("%DynamicObject"))!(input.%Size()>40) {
            Set pResponse.Status="INVALID",pResponse.ErrorCode="DECISION_INPUT_INVALID"
            Return $$$OK
        }
        Set ^StudioAudit(pRequest.CorrelationId,"mode")=pRequest.Mode
        If pRequest.Mode="SIMULATION" {
            If '##class(Studio.Runtime.Releases).SimulationAllowed(release) {
                Set pResponse.ErrorCode="SIMULATION_DENIED"
                Return $$$OK
            }
            Set fault=pRequest.SimulationFault
            // Explicit sandbox-only slow response to exercise the real BPL timer and late-response guard.
            If fault="DELAY" {
                Hang 2
                Set fault=""
            }
            If fault'="" {
                Set pResponse.Status="INVALID",pResponse.ErrorCode="SIMULATION_FAULT_INVALID"
                If fault="TIMEOUT" Set pResponse.Status="TIMEOUT",pResponse.ErrorCode="SIMULATION_TIMEOUT"
                If fault="PROVIDER_DOWN" Set pResponse.Status="ERROR",pResponse.ErrorCode="SIMULATION_PROVIDER_DOWN"
                If fault="TOOL_DENIED" Set pResponse.Status="DENIED",pResponse.ErrorCode="SIMULATION_TOOL_DENIED"
                Return $$$OK
            }
            Set raw=pRequest.CandidateJson,usage={"source":"SIMULATION","providerInvoked":false}
        } ElseIf pRequest.Mode="LIVE" {
            If (pRequest.CandidateJson'="")!(pRequest.SimulationFault'="") {
                Set pResponse.ErrorCode="FIXTURES_REQUIRE_SIMULATION"
                Return $$$OK
            }
            Set agent.AgentId=definition.agentId,agent.Revision=definition.revision,agent.ProviderRef=definition.providerRef
            Set agent.ModelName=definition.modelName,agent.Prompt=definition.prompt,agent.ToolSetRefsJson=definition.toolSetRefs.%ToJSON()
            For i=0:1:definition.toolSetRefs.%Size()-1 {
                If '##class(Studio.Admin.ToolRegistry).IsAllowed(definition.toolSetRefs.%Get(i)) {
                    Set pResponse.ErrorCode="TOOLSET_DENIED"
                    Return $$$OK
                }
            }
            Set sc=##class(Studio.AI.AgentRuntimeAdapter).Invoke(agent,input,pRequest.CorrelationId,.raw,.session,.usage)
            Set pResponse.AgentSessionId=session,^StudioAudit(pRequest.CorrelationId,"agentSessionId")=session
            If $$$ISERR(sc) {
                Set pResponse.Status="ERROR",pResponse.ErrorCode="AI_PROVIDER_INVOCATION_FAILED"
                Return $$$OK
            }
        } Else {
            Set pResponse.ErrorCode="MODE_INVALID"
            Return $$$OK
        }
        Set sanitized={"content":"[REDACTED]"}
        Do sanitized.%Set("mode",pRequest.Mode),sanitized.%Set("length",$Length(raw),"number")
        Set ^StudioAudit(pRequest.CorrelationId,"rawResponse")=sanitized.%ToJSON(),^StudioAudit(pRequest.CorrelationId,"usage")=usage.%ToJSON()
        Set sc=##class(Studio.AI.DecisionValidator).Validate(binding,raw,.validated)
        If $$$ISERR(sc) {
            Set pResponse.Status="INVALID",pResponse.ErrorCode="AI_OUTPUT_INVALID"
            Return $$$OK
        }
        If release.%Get("templateId")="blood-stock-v1" {
            Set sc=##class(Studio.BloodDemo.ManagedPolicy).Validate(input,raw,pRequest.Mode,pRequest.CorrelationId)
            If $$$ISERR(sc) {
                Set pResponse.Status="INVALID",pResponse.ErrorCode="STOCK_POLICY_REJECTED"
                Return $$$OK
            }
        }
        Set pResponse.Status="SUCCESS",pResponse.Action=validated.action,pResponse.Reason=validated.reason,pResponse.EvidenceJson=validated.evidenceRefs.%ToJSON(),pResponse.ErrorCode=""
        Do validated.%Set("reason","[REDACTED]"),validated.%Set("evidenceRefs",[])
        Set ^StudioAudit(pRequest.CorrelationId,"validated")=validated.%ToJSON()
    } Catch ex {
        Set pResponse.Status="ERROR",pResponse.ErrorCode="DECISION_BRIDGE_FAILED"
    }
    Return $$$OK
}
XData MessageMap
{
<MapItems><MapItem MessageType="Studio.Msg.DecisionRequest"><Method>HandleDecision</Method></MapItem></MapItems>
}
}
