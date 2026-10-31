Include %occStatus
Class Studio.BloodDemo.Harness Extends %RegisteredObject
{
ClassMethod Submit(pGroup As %String = "O+", pUnits As %Integer = 5, pMode As %String = "SIMULATION", Output pResponse As Studio.BloodDemo.Response) As %Status
{
    Set request=##class(Studio.BloodDemo.Request).%New()
    Set request.BloodGroup=pGroup,request.Units=pUnits,request.Mode=pMode
    Set request.CorrelationId=$SYSTEM.Util.CreateGUID()
    Set sc=##class(Studio.BloodDemo.Inventory).Validate(request)
    If $$$ISERR(sc) Return sc
    Set sc=##class(Ens.Director).CreateBusinessService("HemocentroA",.service)
    If $$$ISERR(sc) Return sc
    Return service.ProcessInput(request,.pResponse)
}
}
