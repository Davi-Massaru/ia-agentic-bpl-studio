Include %occStatus
/// Generic local sink for demonstrations. No external effects.
Class Studio.Demo.AcknowledgeOperation Extends Ens.BusinessOperation
{
Parameter INVOCATION = "Queue";
Property Label As %String(MAXLEN=40) [ InitialExpression="ACK" ];
Parameter SETTINGS="Label";
Method Receive(pRequest As Studio.Msg.WorkflowRequest, Output pResponse As Studio.Msg.WorkflowResponse) As %Status
{
    Set pResponse=##class(Studio.Msg.WorkflowResponse).%New()
    Set pResponse.CorrelationId=pRequest.CorrelationId,pResponse.Receipt="LOCAL_ONLY:"_..%ConfigName
    Set pResponse.Status="ACK",pResponse.Action=..Label
    Set ^StudioAudit(pRequest.CorrelationId,"destination")=..%ConfigName
    Return $$$OK
}
XData MessageMap
{
<MapItems><MapItem MessageType="Studio.Msg.WorkflowRequest"><Method>Receive</Method></MapItem></MapItems>
}
}
