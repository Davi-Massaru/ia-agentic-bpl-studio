Include %occStatus
/// READ only, immutable synthetic inventory. Instrumented calls are recorded by execution ID.
Class Studio.Tools.BloodStockTools Extends %AI.ToolSet
{
XData Definition [ MimeType = application/xml ]
{
<ToolSet Name="BloodStockTools"><Tool Name="ReadStock" Method="ReadStock"/></ToolSet>
}
/// Return synthetic B/C stock and ETA for O+ or A+. Never reserves or transfers stock.
ClassMethod ReadStock(pBloodGroup As %String) As %String
{
    If (pBloodGroup'="O+")&&(pBloodGroup'="A+") Return "{""error"":""GROUP_INVALID""}"
    Set result=##class(Studio.BloodDemo.Inventory).Snapshot(pBloodGroup)
    Set execution=$Get(^||StudioExecutionId)
    Set observation=##class(Studio.Trace.Recorder).Start(execution,execution,$Get(^||StudioAgentObservation),"tool","ReadStock")
    If execution'="" {
        Set n=$Increment(^StudioAudit(execution,"toolCount"))
        If n>8 Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"TOOL_CALL_LIMIT"))
        Set event={"name":"ReadStock","effect":"READ","source":"instrumented-tool"}
        Do event.%Set("group",pBloodGroup),event.%Set("result",##class(%DynamicObject).%FromJSON(result))
        Set ^StudioAudit(execution,"tools",n)=event.%ToJSON()
    }
    Do ##class(Studio.Trace.Recorder).Finish(execution,observation,"SUCCESS")
    Return result
}
}
