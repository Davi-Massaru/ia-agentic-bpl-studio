Include %occStatus
Class Studio.BloodDemo.Service Extends Ens.BusinessService
{
Method OnProcessInput(pInput As Studio.BloodDemo.Request, Output pOutput As Studio.BloodDemo.Response) As %Status
{
    Set sc=##class(Studio.BloodDemo.Inventory).Validate(pInput)
    If $$$ISERR(sc) Return sc
    Return ..SendRequestSync("BloodRouting",pInput,.pOutput,30)
}
}
