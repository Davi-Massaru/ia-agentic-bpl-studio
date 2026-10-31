Include %occStatus
/// Typed native ingress and owner-scoped trace collection for immutable workspace releases.
Class Studio.Admin.WorkflowTestHarness Extends %RegisteredObject
{
ClassMethod ExecuteJson(pArgsJson As %String) As %String
{
    If '##class(Studio.Admin.RuntimeBridge).HasAccess() Return ##class(Studio.Admin.ControlPlane).Error("ACCESS_DENIED","Native permission required.",403)
    Try {
        If $Length(pArgsJson)>32768 Return ##class(Studio.Admin.ControlPlane).Error("INVALID_REQUEST","Request too large.")
        Set args=##class(%DynamicObject).%FromJSON(pArgsJson),manifest=##class(Studio.Runtime.Releases).Manifest(args.releaseId)
        If 'manifest.%IsDefined("releaseId") Return ##class(Studio.Admin.ControlPlane).Error("RELEASE_NOT_FOUND","Published release required.",404)
        If 'manifest.%IsDefined("hostName") Return ##class(Studio.Admin.TestHarness).LegacyExecuteJson(pArgsJson)
        If '##class(Studio.Runtime.Releases).Compatible(manifest) Return ##class(Studio.Admin.ControlPlane).Error("RELEASE_SOURCE_CONFLICT","Release source differs from deployed BPL.",409)
        If (manifest.requestClass'="Studio.Msg.WorkflowRequest")&&(manifest.requestClass'="Studio.Msg.StockWorkflowRequest") Return ##class(Studio.Admin.ControlPlane).Error("REQUEST_CLASS_DENIED","Unsupported managed request class.",403)
        If ##class(Ens.Director).GetActiveProductionName()'=manifest.production Return ##class(Studio.Admin.ControlPlane).Error("PRODUCTION_NOT_RUNNING","Start the release Production.",409)
        Set payload=args.payload,request=$ClassMethod(manifest.requestClass,"%New")
        If 'payload.%IsA("%DynamicObject") Return ##class(Studio.Admin.ControlPlane).Error("INVALID_REQUEST","Payload object required.")
        Set iterator=payload.%GetIterator()
        While iterator.%GetNext(.name,.value) {
            If (name="CorrelationId")!(name="ReleaseId") Return ##class(Studio.Admin.ControlPlane).Error("INVALID_REQUEST","Reserved request field.")
            Set kind=##class(Studio.Runtime.InputMapper).PropertyType(manifest.requestClass,name),jsonType=payload.%GetTypeOf(name)
            If kind="" Return ##class(Studio.Admin.ControlPlane).Error("INVALID_REQUEST","Unknown scalar property.")
            If (kind="string")&&(jsonType'="string") Return ##class(Studio.Admin.ControlPlane).Error("INVALID_REQUEST","Property type mismatch.")
            If (kind="boolean")&&(jsonType'="boolean") Return ##class(Studio.Admin.ControlPlane).Error("INVALID_REQUEST","Property type mismatch.")
            If ((kind="integer")!(kind="number"))&&(jsonType'="number") Return ##class(Studio.Admin.ControlPlane).Error("INVALID_REQUEST","Property type mismatch.")
            If $IsObject(value)!($Length(value)>16384) Return ##class(Studio.Admin.ControlPlane).Error("INVALID_REQUEST","Scalar value exceeds limit.")
            Set $Property(request,name)=value
        }
        Set request.ReleaseId=args.releaseId,request.CorrelationId=$SYSTEM.Util.CreateGUID(),id=request.CorrelationId
        If (request.Mode'="LIVE")&&(request.Mode'="SIMULATION") Return ##class(Studio.Admin.ControlPlane).Error("INVALID_REQUEST","Mode must be LIVE or SIMULATION.")
        If request.Mode="SIMULATION",'##class(Studio.Runtime.Releases).SimulationAllowed(manifest) Return ##class(Studio.Admin.ControlPlane).Error("SIMULATION_DENIED","Simulation requires the local sandbox.",403)
        If request.Mode="LIVE",(request.CandidateJson'="")!(request.SimulationFault'="") Return ##class(Studio.Admin.ControlPlane).Error("INVALID_REQUEST","Fixtures require SIMULATION.")
        Set sc=request.%ValidateObject()
        If $$$ISERR(sc) Return ##class(Studio.Admin.ControlPlane).Error("INVALID_REQUEST","Required fields or values invalid.")
        Set sc=##class(Studio.Runtime.InputMapper).Map(request,"{}",manifest.binding,.redacted,1)
        If $$$ISERR(sc) Return ##class(Studio.Admin.ControlPlane).Error("INVALID_REQUEST","Mapped inputs invalid.")
        Set trace={"events":[],"toolCalls":[],"source":"native-IRIS-Production"}
        Do trace.%Set("executionId",id),trace.%Set("correlationId",id),trace.%Set("releaseId",request.ReleaseId),trace.%Set("mode",request.Mode)
        Do trace.%Set("bindingId",manifest.binding.bindingId),trace.%Set("agentRevision",manifest.agent.revision),trace.%Set("input",redacted)
        Set ^StudioAudit(id,"owner")=$USERNAME
        Set sc=##class(Ens.Director).CreateBusinessService(manifest.serviceName,.service)
        If $$$ISERR(sc) Return ##class(Studio.Admin.ControlPlane).Error("SERVICE_UNAVAILABLE","Native Service unavailable.",503)
        Set sc=service.ProcessInput(request,.response)
        Do trace.%Set("requestBodyId",request.%Id()),trace.%Set("bplClass",manifest.compiledBPLClass),trace.%Set("bplHost",manifest.hostName)
        If $$$ISERR(sc) {
            Do trace.%Set("status","ERROR"),trace.%Set("errorCode","NATIVE_MESSAGE_FAILED")
        } Else {
            Do trace.%Set("status",response.Status),trace.%Set("action",response.Action),trace.%Set("reason","[REDACTED]")
            Do trace.%Set("receipt",response.Receipt),trace.%Set("agentSessionId",response.AgentSessionId),trace.%Set("decisionExecutionId",response.DecisionExecutionId),trace.%Set("responseBodyId",response.%Id())
        }
        Set statement=##class(%SQL.Statement).%New(),sc=statement.%Prepare("SELECT TOP 1 ID, SessionId FROM Ens.MessageHeader WHERE MessageBodyClassName = ? AND MessageBodyId = ? ORDER BY ID")
        If $$$ISOK(sc) {
            Set rows=statement.%Execute(manifest.requestClass,request.%Id())
            If rows.%Next() Do trace.%Set("messageId",rows.%Get("ID")),trace.%Set("interopSessionId",rows.%Get("SessionId"))
        }
        For i=1:1:+$Get(^StudioAudit(id,"toolCount")) {
            If $Data(^StudioAudit(id,"tools",i)) Do trace.toolCalls.%Push(##class(%DynamicObject).%FromJSON(^StudioAudit(id,"tools",i)))
        }
        For key="validated","usage","rawResponse","output" {
            If $Data(^StudioAudit(id,key)) Do trace.%Set(key,##class(%DynamicObject).%FromJSON(^StudioAudit(id,key)))
        }
        Do trace.%Set("destination",$Get(^StudioAudit(id,"destination")))
        If $Get(^StudioAudit(id,"errorCode"))'="" Do trace.%Set("errorCode",^StudioAudit(id,"errorCode"))
        If 'trace.%IsDefined("errorCode") Do trace.%Set("errorCode","")
        If $Get(^StudioAudit(id,"agentSessionId"))'="" Do trace.%Set("agentSessionId",^StudioAudit(id,"agentSessionId"))
        // A native BPL deadline wins over any later decision-worker response.
        If trace.%Get("status")="TIMEOUT",trace.%Get("errorCode")="" {
            Set timedOutput={"status":"TIMEOUT","reason":"[REDACTED]","errorCode":"DECISION_DEADLINE_EXCEEDED"}
            Do timedOutput.%Set("action",trace.%Get("action")),trace.%Set("output",timedOutput),trace.%Set("errorCode","DECISION_DEADLINE_EXCEEDED")
        }
        Set event={}
        Do event.%Set("step",manifest.serviceName),event.%Set("status","SUBMITTED"),trace.events.%Push(event)
        Set event={}
        Do event.%Set("step",manifest.hostName),event.%Set("status",trace.%Get("status")),trace.events.%Push(event)
        Set event={}
        Do event.%Set("step",$Get(^StudioAudit(id,"destination"))),event.%Set("status","LOCAL_RECEIPT"),trace.events.%Push(event)
        Set ^StudioAudit(id,"trace")=trace.%ToJSON(),result={}
        Do ##class(Studio.Admin.Settings).RecordLiveProof(id)
        Do result.%Set("executionId",id)
        Return ##class(Studio.Admin.ControlPlane).OK(result)
    } Catch ex {
        Return ##class(Studio.Admin.ControlPlane).Error("NATIVE_TEST_FAILED","Native test could not complete.",502)
    }
}
}
