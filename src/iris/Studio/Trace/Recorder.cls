/// Payload-free application observations. Failures do not alter business results.
Class Studio.Trace.Recorder Extends %RegisteredObject
{
ClassMethod Execution() As %String
{
    Return $Get(^||StudioExecutionId)
}
ClassMethod Parent() As %String
{
    Return $Get(^||StudioAgentObservation)
}
ClassMethod Context(pExecution As %String, pParent As %String)
{
    Set ^||StudioExecutionId=pExecution,^||StudioAgentObservation=pParent
}
ClassMethod Start(pExecution As %String, pTrace As %String, pParent As %String, pType As %String, pName As %String, pMetadata As %String = "{}") As %String
{
    If pExecution="" Return ""
    Try {
        Set rows=##class(%DynamicArray).%FromJSON($Get(^StudioAudit(pExecution,"observations"),"[]"))
        If rows.%Size()>=64 Return ""
        For i=0:1:rows.%Size()-1 { If rows.%Get(i).id=pParent Set pTrace=rows.%Get(i).traceId }
        Set id=$SYSTEM.Util.CreateGUID(),row={},now=$ZTIMESTAMP
        Do row.%Set("id",id),row.%Set("executionId",pExecution),row.%Set("traceId",$Select(pTrace="":pExecution,1:pTrace)),row.%Set("parentObservationId",pParent)
        Do row.%Set("type",pType),row.%Set("name",pName),row.%Set("status","RUNNING"),row.%Set("startTime",$ZDATETIME(now,3,1)_"Z"),row.%Set("metadata",{})
        Set input=##class(%DynamicObject).%FromJSON(pMetadata)
        For key="provider","model" { If input.%IsDefined(key) Do row.metadata.%Set(key,input.%Get(key)) }
        Do rows.%Push(row)
        Set ^StudioAudit(pExecution,"observations")=rows.%ToJSON(),^||StudioClock(id)=($Piece(now,",",1)*86400)+$Piece(now,",",2)
        Return id
    } Catch ex { Return "" }
}
ClassMethod Finish(pExecution As %String, pId As %String, pStatus As %String, pMetadata As %String = "{}", pUsage As %String = "{}")
{
    If pId="" Quit
    Try {
        Set rows=##class(%DynamicArray).%FromJSON($Get(^StudioAudit(pExecution,"observations"),"[]")),now=$ZTIMESTAMP
        For i=0:1:rows.%Size()-1 {
            Set row=rows.%Get(i)
            If row.id=pId {
                Do row.%Set("status",pStatus),row.%Set("endTime",$ZDATETIME(now,3,1)_"Z")
                If $Data(^||StudioClock(pId)) Do row.%Set("durationMs",((($Piece(now,",",1)*86400)+$Piece(now,",",2))-^||StudioClock(pId))*1000,"number")
                Do row.%Set("usage",##class(%DynamicObject).%FromJSON(pUsage))
            }
        }
        Set ^StudioAudit(pExecution,"observations")=rows.%ToJSON()
        Kill ^||StudioClock(pId)
    } Catch ex { }
}
}
