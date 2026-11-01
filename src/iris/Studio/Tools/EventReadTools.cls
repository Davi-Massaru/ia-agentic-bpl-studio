Include %occStatus
Class Studio.Tools.EventReadTools Extends %AI.ToolSet
{
XData Definition [ MimeType = application/xml ]
{
<ToolSet Name="EventReadTools"><Tool Name="ReadEvent" Method="ReadEvent"/></ToolSet>
}
/// Read synthetic evidence by event ID. E-OK is eligible; every other ID requires review.
ClassMethod ReadEvent(pEventId As %String) As %String
{
    If ($Length(pEventId)<1)!($Length(pEventId)>128) Return "{""error"":""EVENT_ID_INVALID""}"
    Set data={"synthetic":true}
    Do data.%Set("eventId",pEventId),data.%Set("eligible",pEventId="E-OK","boolean"),data.%Set("evidenceRef","event:"_pEventId)
    Set execution=$Get(^||StudioExecutionId)
    Set observation=##class(Studio.Trace.Recorder).Start(execution,execution,$Get(^||StudioAgentObservation),"tool","ReadEvent")
    If execution'="" {
        Set n=$Increment(^StudioAudit(execution,"toolCount"))
        If n>8 Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"TOOL_CALL_LIMIT"))
        Set event={"name":"ReadEvent","effect":"READ","source":"instrumented-tool"}
        Do event.%Set("result",data)
        Set ^StudioAudit(execution,"tools",n)=event.%ToJSON()
    }
    Do ##class(Studio.Trace.Recorder).Finish(execution,observation,"SUCCESS")
    Return data.%ToJSON()
}
}
