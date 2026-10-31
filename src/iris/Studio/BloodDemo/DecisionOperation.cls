Include %occStatus
/// Native agent decision with pinned release configuration and deterministic validation.
Class Studio.BloodDemo.DecisionOperation Extends Ens.BusinessOperation
{
Parameter INVOCATION = "Queue";
Method Decide(pRequest As Studio.BloodDemo.Request, Output pResponse As Studio.BloodDemo.Response) As %Status
{
    Set pResponse = ##class(Studio.BloodDemo.Response).%New()
    Set pResponse.CorrelationId=pRequest.CorrelationId, pResponse.Mode=pRequest.Mode
    Set sc=##class(Studio.BloodDemo.Inventory).Validate(pRequest)
    If $$$ISERR(sc) {
        Set pResponse.Status="INVALID",pResponse.Reason="Invalid synthetic request."
        Return $$$OK
    }
    If pRequest.Mode="SIMULATION" {
        Set pResponse.Destination=##class(Studio.BloodDemo.Inventory).Recommend(pRequest)
        Set pResponse.Status="SIMULATED",pResponse.Reason="Deterministic fixture; no AI invocation."
        Return $$$OK
    }
    Set execution=pRequest.CorrelationId
    Set ^StudioAudit(execution,"decisionInvoked")=1
    Try {
        Set manifest=##class(Studio.Admin.ControlPlane).ReleaseManifest(pRequest.ReleaseId)
        If 'manifest.%IsDefined("agent") {
            Set pResponse.Status="UNAVAILABLE",pResponse.Reason="PUBLISHED_RELEASE_REQUIRED"
            Return $$$OK
        }
        If manifest.baseHash'=##class(Studio.Admin.ControlPlane).Hash(##class(Studio.Admin.ControlPlane).Source()) {
            Set pResponse.Status="INVALID",pResponse.Reason="RELEASE_SOURCE_CONFLICT"
            Return $$$OK
        }
        Set definition=manifest.agent,agent=##class(Studio.Model.AgentDefinition).%New()
        Set agent.AgentId=definition.agentId,agent.Revision=definition.revision,agent.ProviderRef=definition.providerRef
        Set agent.ModelName=definition.modelName,agent.Prompt=definition.prompt,agent.ToolSetRefsJson=definition.toolSetRefs.%ToJSON()
        Set input={}
        Do input.%Set("group",pRequest.BloodGroup),input.%Set("units",pRequest.Units,"number")
        Set sc=##class(Studio.AI.AgentRuntimeAdapter).Invoke(agent,input,execution,.raw,.sessionId,.usage)
        Set pResponse.AgentSessionId=sessionId
        If $$$ISERR(sc) {
            Set pResponse.Status="ERROR",pResponse.Reason="AI_PROVIDER_INVOCATION_FAILED"
            Return $$$OK
        }
        Set sc=##class(Studio.BloodDemo.CandidateValidator).Validate(pRequest,raw,.validated)
        If $$$ISERR(sc) {
            Set pResponse.Status="INVALID",pResponse.Reason="AI_OUTPUT_INVALID"
            Return $$$OK
        }
        If +$Get(^StudioAudit(execution,"toolCount"))=0 {
            Set pResponse.Status="INVALID",pResponse.Reason="INVENTORY_TOOL_NOT_OBSERVED"
            Return $$$OK
        }
        Set pResponse.Destination=validated.action,pResponse.Reason=validated.reason,pResponse.Status="SUCCESS"
        Set ^StudioAudit(execution,"validated")=validated.%ToJSON(),^StudioAudit(execution,"usage")=usage.%ToJSON()
    } Catch ex {
        Set pResponse.Status="ERROR",pResponse.Reason="NATIVE_DECISION_FAILED"
    }
    Return $$$OK
}
XData MessageMap
{
<MapItems>
  <MapItem MessageType="Studio.BloodDemo.Request"><Method>Decide</Method></MapItem>
</MapItems>
}
}
