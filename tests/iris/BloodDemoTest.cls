Include %occStatus
/// Run only in an isolated namespace with Studio.BloodDemo.Production started.
Class Studio.Tests.BloodDemoTest Extends %RegisteredObject
{
ClassMethod Run() As %Status
{
    Set sc=##class(Studio.BloodDemo.Harness).Submit("O+",5,"SIMULATION",.response)
    If $$$ISERR(sc) Return sc
    If response.Destination'="B" Return $$$ERROR($$$GeneralError,"EXPECTED_B")
    If response.Receipt'="LOCAL_ONLY:B" Return $$$ERROR($$$GeneralError,"MISSING_B_RECEIPT")
    Set sc=##class(Studio.BloodDemo.Harness).Submit("A+",5,"SIMULATION",.response)
    If $$$ISERR(sc) Return sc
    If response.Destination'="C" Return $$$ERROR($$$GeneralError,"EXPECTED_C")
    Set sc=##class(Studio.BloodDemo.Harness).Submit("O+",20,"SIMULATION",.response)
    If $$$ISERR(sc) Return sc
    If response.Destination'="REVIEW" Return $$$ERROR($$$GeneralError,"EXPECTED_REVIEW")
    Set sc=##class(Studio.BloodDemo.Harness).Submit("O+",5,"LIVE",.response)
    If $$$ISERR(sc) Return sc
    If response.Status'="UNAVAILABLE" Return $$$ERROR($$$GeneralError,"LIVE_MUST_FAIL_CLOSED")
    If response.Destination'="REVIEW" Return $$$ERROR($$$GeneralError,"LIVE_MUST_NOT_DISPATCH")
    Set sc=##class(Studio.BloodDemo.Harness).Submit("O+",0,"SIMULATION",.response)
    If $$$ISOK(sc) Return $$$ERROR($$$GeneralError,"INVALID_UNITS_ACCEPTED")
    Return $$$OK
}
}
