Include %occStatus
/// A local sink only: no network, inventory mutation, or real transfer.
Class Studio.BloodDemo.ReceiptOperation Extends Ens.BusinessOperation
{
Parameter INVOCATION = "Queue";
Property Center As %String [ InitialExpression = "REVIEW" ];
Parameter SETTINGS = "Center";
Method Receive(pRequest As Studio.BloodDemo.Request, Output pResponse As Studio.BloodDemo.Response) As %Status
{
    Set pResponse=##class(Studio.BloodDemo.Response).%New()
    Set pResponse.CorrelationId=pRequest.CorrelationId,pResponse.Mode=pRequest.Mode
    Set pResponse.Destination="REVIEW",pResponse.Status="REVIEW"
    If ((..Center="B")!(..Center="C")) {
        Set sc=##class(Studio.BloodDemo.Inventory).Validate(pRequest)
        If $$$ISOK(sc),##class(Studio.BloodDemo.Inventory).Stock(..Center,pRequest.BloodGroup)>=pRequest.Units {
            Set pResponse.Destination=..Center,pResponse.Status=$Select(pRequest.Mode="SIMULATION":"SIMULATED_ACK",1:"LOCAL_ACK")
        }
    }
    Set pResponse.Receipt="LOCAL_ONLY:"_pResponse.Destination
    Set ^StudioAudit(pRequest.CorrelationId,"destination")=pResponse.Destination
    Return $$$OK
}
XData MessageMap
{
<MapItems>
  <MapItem MessageType="Studio.BloodDemo.Request"><Method>Receive</Method></MapItem>
</MapItems>
}
}
