Include %occStatus
/// Executes only the allowlisted synthetic Service. No direct BO or Flask workflow.
Class Studio.Admin.TestHarness Extends %RegisteredObject
{
ClassMethod ExecuteJson(pArgsJson As %String) As %String
{
    Return ##class(Studio.Admin.WorkflowTestHarness).ExecuteJson(pArgsJson)
}
ClassMethod LegacyExecuteJson(pArgsJson As %String) As %String
{
    If '##class(Studio.Admin.RuntimeBridge).HasAccess() Return ##class(Studio.Admin.ControlPlane).Error("ACCESS_DENIED","Native permission required.",403)
    Try {
        Set args=##class(%DynamicObject).%FromJSON(pArgsJson),manifest=##class(Studio.Admin.ControlPlane).ReleaseManifest(args.releaseId)
        If 'manifest.%IsDefined("releaseId") Return ##class(Studio.Admin.ControlPlane).Error("RELEASE_NOT_FOUND","Published release required.",404)
        If manifest.baseHash'=##class(Studio.Admin.ControlPlane).Hash(##class(Studio.Admin.ControlPlane).Source()) Return ##class(Studio.Admin.ControlPlane).Error("RELEASE_SOURCE_CONFLICT","The release source differs from the deployed BPL.",409)
        Set payload=args.payload,request=##class(Studio.BloodDemo.Request).%New()
        If (payload.%GetTypeOf("BloodGroup")'="string")!(payload.%GetTypeOf("Units")'="number") Return ##class(Studio.Admin.ControlPlane).Error("INVALID_REQUEST","BloodGroup string and Units integer required.")
        Set request.BloodGroup=payload.BloodGroup,request.Units=payload.Units,request.Mode=payload.%Get("Mode","LIVE")
        Set request.ReleaseId=args.releaseId,request.CorrelationId=$SYSTEM.Util.CreateGUID(),id=request.CorrelationId
        Set sc=##class(Studio.BloodDemo.Inventory).Validate(request)
        If $$$ISERR(sc) Return ##class(Studio.Admin.ControlPlane).Error("INVALID_REQUEST","Group, units or mode invalid.")
        Set trace={"events":[],"toolCalls":[],"source":"native-IRIS-Production"}
        Do trace.%Set("executionId",id),trace.%Set("correlationId",id),trace.%Set("releaseId",request.ReleaseId),trace.%Set("mode",request.Mode)
        Do trace.%Set("bindingId",manifest.binding.bindingId),trace.%Set("agentRevision",manifest.agent.revision)
        Set sc=##class(Ens.Director).CreateBusinessService("HemocentroA",.service)
        If $$$ISERR(sc) Return ##class(Studio.Admin.ControlPlane).Error("SERVICE_UNAVAILABLE","Start the sandbox Production.",503)
        Do trace.events.%Push({"step":"HemocentroA","status":"SUBMITTED"})
        Set sc=service.ProcessInput(request,.response)
        Do trace.%Set("requestBodyId",request.%Id())
        If $$$ISERR(sc) {
            Do trace.%Set("status","ERROR"),trace.%Set("errorCode","NATIVE_MESSAGE_FAILED")
        } Else {
            Do trace.%Set("status",response.Status),trace.%Set("action",response.Destination),trace.%Set("reason",response.Reason)
            Do trace.%Set("receipt",response.Receipt),trace.%Set("agentSessionId",response.AgentSessionId),trace.%Set("responseBodyId",response.%Id())
            Do trace.events.%Push({"step":"BloodRouting / decision","status":"REPLIED"})
            Set event={}
            Do event.%Set("step",response.Destination),event.%Set("receipt",response.Receipt)
            Do trace.events.%Push(event)
        }
        Set headers=##class(%SQL.Statement).%New()
        Set sc=headers.%Prepare("SELECT TOP 1 ID, SessionId FROM Ens.MessageHeader WHERE MessageBodyClassName = ? AND MessageBodyId = ? ORDER BY ID")
        If $$$ISOK(sc) {
            Set rows=headers.%Execute("Studio.BloodDemo.Request",request.%Id())
            If rows.%Next() Do trace.%Set("messageId",rows.%Get("ID")),trace.%Set("interopSessionId",rows.%Get("SessionId"))
        }
        For i=1:1:+$Get(^StudioAudit(id,"toolCount")) {
            If $Data(^StudioAudit(id,"tools",i)) Do trace.toolCalls.%Push(##class(%DynamicObject).%FromJSON(^StudioAudit(id,"tools",i)))
        }
        If $Data(^StudioAudit(id,"usage")) Do trace.%Set("usage",##class(%DynamicObject).%FromJSON(^StudioAudit(id,"usage")))
        Set ^StudioAudit(id,"trace")=trace.%ToJSON(),^StudioAudit(id,"owner")=$USERNAME
        If request.Mode="LIVE",trace.%Get("status")="SUCCESS",trace.%Get("agentSessionId")'="",trace.toolCalls.%Size()>0 {
            Set action=trace.%Get("action")
            If (action="B")!(action="C") Set ^StudioAIProof(request.ReleaseId,action)=id
        }
        Set result={}
        Do result.%Set("executionId",id)
        Return ##class(Studio.Admin.ControlPlane).OK(result)
    } Catch ex {
        Return ##class(Studio.Admin.ControlPlane).Error("NATIVE_TEST_FAILED","Native test could not complete.",502)
    }
}
ClassMethod GetRunJson(pId As %String) As %String
{
    If '##class(Studio.Admin.RuntimeBridge).HasAccess() Return ##class(Studio.Admin.ControlPlane).Error("ACCESS_DENIED","Native permission required.",403)
    If $Get(^StudioAudit(pId,"owner"))'=$USERNAME Return ##class(Studio.Admin.ControlPlane).Error("RUN_NOT_FOUND","Execution not found.",404)
    If '$Data(^StudioAudit(pId,"trace")) Return ##class(Studio.Admin.ControlPlane).Error("RUN_NOT_FOUND","Execution not found.",404)
    Set trace=##class(%DynamicObject).%FromJSON(^StudioAudit(pId,"trace"))
    If $Data(^StudioAudit(pId,"observations")) Do trace.%Set("observations",##class(%DynamicArray).%FromJSON(^StudioAudit(pId,"observations")))
    Return ##class(Studio.Admin.ControlPlane).OK(trace)
}
}
