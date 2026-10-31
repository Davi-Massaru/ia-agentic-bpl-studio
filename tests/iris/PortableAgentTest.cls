Include %occStatus
/// Explicit LIVE test: two native agents inside an ordinary, editable BPL.
Class Studio.Tests.PortableAgentTest Extends %RegisteredObject
{
ClassMethod Run() As %Status
{
    Set request=##class(Studio.Msg.AgentRequest).%New()
    Set request.InputJson="{""group"":""A+"",""units"":5}",request.CorrelationId=$SYSTEM.Util.CreateGUID()
    Set sc=##class(Ens.Director).CreateBusinessService("FreeAgentService",.service)
    If $$$ISERR(sc) Return sc
    Set sc=service.ProcessInput(request,.response)
    If $$$ISERR(sc) Return sc
    Set report={"mode":"LIVE","managedReleaseRequired":false,"workflowClass":"Studio.Examples.NativeAgentWorkflow","agents":[]}
    Do report.%Set("status",response.Status),report.%Set("action",response.Action),report.%Set("correlationId",request.CorrelationId),report.%Set("requestBodyId",request.%Id())
    Set query=##class(%SQL.Statement).%New()
    Set sc=query.%Prepare("SELECT TOP 1 ID, SessionId FROM Ens.MessageHeader WHERE MessageBodyClassName = ? AND MessageBodyId = ? ORDER BY ID")
    If $$$ISERR(sc) Return sc
    Set rows=query.%Execute("Studio.Msg.AgentRequest",request.%Id())
    If rows.%Next() Do report.%Set("messageId",rows.%Get("ID")),report.%Set("interopSessionId",rows.%Get("SessionId"))
    Set id=""
    For {
        Set id=$Order(^StudioAudit(id)) Quit:id=""
        If $Data(^StudioAudit(id,"trace")) {
            Set trace=##class(%DynamicObject).%FromJSON(^StudioAudit(id,"trace"))
            If trace.%Get("correlationId")=request.CorrelationId {
                Do trace.%Set("interopSessionId",report.%Get("interopSessionId")),report.agents.%Push(trace)
            }
        }
    }
    Do report.%Set("ok",(response.Status="SUCCESS")&&(response.Action="C")&&(report.agents.%Size()=2),"boolean")
    Set stream=##class(%Stream.FileCharacter).%New(),stream.Filename="/tmp/native-free-agents.json"
    Do stream.Write(report.%ToJSON()) Set sc=stream.%Save()
    Write "NATIVE_FREE_AGENT_RESULT=",report.%ToJSON(),!
    If 'report.ok Return $$$ERROR($$$GeneralError,"NATIVE_FREE_AGENT_FAILED")
    For i=0:1:report.agents.%Size()-1 {
        Set trace=report.agents.%Get(i)
        If (trace.status'="SUCCESS")!(trace.agentSessionId="")!(trace.toolCalls.%Size()<1) Return $$$ERROR($$$GeneralError,"AGENT_EVIDENCE_MISSING")
    }
    Return sc
}
}
