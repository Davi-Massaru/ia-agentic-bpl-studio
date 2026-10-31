Include %occStatus
/// Immutable synthetic fixtures. No clinical compatibility or real reservation.
Class Studio.BloodDemo.Inventory Extends %RegisteredObject
{
ClassMethod Validate(pRequest As Studio.BloodDemo.Request) As %Status
{
    If '$ISOBJECT(pRequest) Return $$$ERROR($$$GeneralError,"REQUEST_REQUIRED")
    If (pRequest.BloodGroup'="O+")&&(pRequest.BloodGroup'="A+") Return $$$ERROR($$$GeneralError,"GROUP_INVALID")
    If (pRequest.Units<1)!(pRequest.Units>100)!(pRequest.Units\1'=pRequest.Units) Return $$$ERROR($$$GeneralError,"UNITS_INVALID")
    If (pRequest.Mode'="SIMULATION")&&(pRequest.Mode'="LIVE") Return $$$ERROR($$$GeneralError,"MODE_INVALID")
    If (pRequest.CorrelationId="")!($LENGTH(pRequest.CorrelationId)>128) Return $$$ERROR($$$GeneralError,"CORRELATION_REQUIRED")
    Return $$$OK
}
ClassMethod Stock(pCenter As %String, pGroup As %String) As %Integer
{
    If pCenter="B" Return $SELECT(pGroup="O+":12,pGroup="A+":2,1:0)
    If pCenter="C" Return $SELECT(pGroup="O+":3,pGroup="A+":15,1:0)
    Return 0
}
ClassMethod Recommend(pRequest As Studio.BloodDemo.Request) As %String
{
    // B ETA 30, C ETA 55. Only sufficient same-group stock is eligible.
    If $$$ISERR(..Validate(pRequest)) Return "REVIEW"
    If ..Stock("B",pRequest.BloodGroup)>=pRequest.Units Return "B"
    If ..Stock("C",pRequest.BloodGroup)>=pRequest.Units Return "C"
    Return "REVIEW"
}
ClassMethod Snapshot(pGroup As %String) As %String
{
    Set data = {"synthetic":true,"B":{"minutes":30},"C":{"minutes":55}}
    Do data.%Set("group",pGroup)
    Do data.B.%Set("units",..Stock("B",pGroup))
    Do data.C.%Set("units",..Stock("C",pGroup))
    Return data.%ToJSON()
}
}
