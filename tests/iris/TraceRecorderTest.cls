Class Studio.Tests.TraceRecorderTest Extends %RegisteredObject
{
ClassMethod Run() As %Boolean
{
    Set execution="recorder-test-"_$SYSTEM.Util.CreateGUID()
    Set root=##class(Studio.Trace.Recorder).Start(execution,"workflow","","operation","root")
    Set child=##class(Studio.Trace.Recorder).Start(execution,execution,root,"agent","child","{""model"":""test"",""prompt"":""secret""}")
    If (root="")!(child="") Return 0
    Do ##class(Studio.Trace.Recorder).Finish(execution,child,"ERROR")
    Do ##class(Studio.Trace.Recorder).Finish(execution,root,"ERROR")
    Set rows=##class(%DynamicArray).%FromJSON(^StudioAudit(execution,"observations"))
    If rows.%Size()'=2 Return 0
    Set row=rows.%Get(1)
    If (row.traceId'="workflow")!(row.parentObservationId'=root)!(row.status'="ERROR") Return 0
    If row.metadata.%IsDefined("prompt") Return 0
    If ('row.%IsDefined("durationMs"))!(row.durationMs<0) Return 0
    For i=3:1:64 Set id=##class(Studio.Trace.Recorder).Start(execution,"workflow",root,"tool","bounded")
    If ##class(Studio.Trace.Recorder).Start(execution,"workflow",root,"tool","overflow")'="" Return 0
    Return 1
}
}
