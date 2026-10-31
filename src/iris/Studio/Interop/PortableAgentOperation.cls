Include %occStatus
/// Reusable AI Hub component for native BPL Calls. No managed workflow or release required.
Class Studio.Interop.PortableAgentOperation Extends Ens.BusinessOperation
{
Parameter INVOCATION = "Queue";
/// Immutable published component configuration. Credentials remain in Wallet.
Property ComponentId As %String(MAXLEN=128);
Parameter SETTINGS = "ComponentId:AI Hub";

Method Decide(pRequest As Studio.Msg.AgentRequest, Output pResponse As Studio.Msg.DecisionResponse) As %Status
{
    Set pResponse=##class(Studio.Msg.DecisionResponse).%New()
    Set id=$SYSTEM.Util.CreateGUID(),pResponse.DecisionExecutionId=id,pResponse.Status="ERROR",pResponse.Action="REVIEW",pResponse.ErrorCode="COMPONENT_NOT_CONFIGURED"
    Set trace={"mode":"LIVE","source":"native-IRIS-portable-agent","toolCalls":[],"events":[]}
    Do trace.%Set("executionId",id),trace.%Set("correlationId",pRequest.CorrelationId),trace.%Set("componentId",..ComponentId),trace.%Set("operation",..%ConfigName)
    Set ^StudioAudit(id,"owner")=$USERNAME
    Set observation=##class(Studio.Trace.Recorder).Start(id,pRequest.CorrelationId,"","operation",..%ConfigName)
    Set ^||StudioParentObservation=observation
    Try {
        Set config=##class(%DynamicObject).%FromJSON(##class(Studio.Admin.Workspace).Read("component:"_..ComponentId))
        Set pResponse.Action=config.fallbackAction
        If config.production'=##class(Ens.Director).GetActiveProductionName() Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"PRODUCTION_MISMATCH"))
        If config.hostName'=..%ConfigName Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"HOST_MISMATCH"))
        Do trace.%Set("agentId",config.agent.agentId),trace.%Set("agentRevision",config.agent.revision),trace.%Set("production",config.production)
        Set input=##class(%DynamicObject).%FromJSON(pRequest.InputJson)
        If 'input.%IsA("%DynamicObject") Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"INPUT_OBJECT_REQUIRED"))
        Set agent=##class(Studio.Model.AgentDefinition).%New(),definition=config.agent
        Set agent.AgentId=definition.agentId,agent.Revision=definition.revision,agent.ProviderRef=definition.providerRef,agent.ModelName=definition.modelName,agent.Prompt=definition.prompt,agent.ToolSetRefsJson=definition.toolSetRefs.%ToJSON()
        Set sc=##class(Studio.AI.AgentRuntimeAdapter).Invoke(agent,input,id,.raw,.session,.usage)
        Set pResponse.AgentSessionId=session
        Do trace.%Set("usage",usage)
        If $$$ISERR(sc) {
            Set pResponse.ErrorCode="AI_PROVIDER_INVOCATION_FAILED"
        } Else {
            Set binding=##class(Studio.Model.DecisionBinding).%New(),routes={}
            For i=0:1:config.allowedActions.%Size()-1 Do routes.%Set(config.allowedActions.%Get(i),"caller")
            Set binding.RoutesJson=routes.%ToJSON(),binding.FallbackAction=config.fallbackAction,binding.FallbackTarget="caller"
            Set sc=##class(Studio.AI.DecisionValidator).Validate(binding,raw,.validated)
            If $$$ISOK(sc),config.%Get("policy")="blood-stock" Set sc=##class(Studio.BloodDemo.ManagedPolicy).Validate(input,raw,"LIVE",id)
            If $$$ISERR(sc) {
                Do trace.%Set("validationError",$SYSTEM.Status.GetErrorText(sc))
                Set pResponse.Status="INVALID",pResponse.ErrorCode="AGENT_DECISION_REJECTED"
            } Else {
                Set pResponse.Status="SUCCESS",pResponse.Action=validated.action,pResponse.Reason=validated.reason,pResponse.EvidenceJson=validated.evidenceRefs.%ToJSON(),pResponse.ErrorCode=""
            }
        }
    } Catch ex {
        Set pResponse.Status="ERROR",pResponse.ErrorCode="PORTABLE_AGENT_FAILED"
    }
    For i=1:1:+$Get(^StudioAudit(id,"toolCount")) Do trace.toolCalls.%Push(##class(%DynamicObject).%FromJSON(^StudioAudit(id,"tools",i)))
    Do trace.%Set("status",pResponse.Status),trace.%Set("action",pResponse.Action),trace.%Set("agentSessionId",pResponse.AgentSessionId),trace.%Set("errorCode",pResponse.ErrorCode),trace.%Set("reason","[REDACTED]")
    Do ##class(Studio.Trace.Recorder).Finish(id,observation,pResponse.Status)
    Kill ^||StudioParentObservation
    Set ^StudioAudit(id,"trace")=trace.%ToJSON()
    // An application response carries failure/fallback to the caller's own native BPL.
    Return $$$OK
}
XData MessageMap
{
<MapItems><MapItem MessageType="Studio.Msg.AgentRequest"><Method>Decide</Method></MapItem></MapItems>
}
}
