Include %occStatus
Class Studio.Tests.RuntimeIntegration Extends %RegisteredObject
{
ClassMethod Run() As %String
{
    Set evidence={"buildTarget":"2026.3.0AI.154.0","mode":"SIMULATION","runs":[],"aiValidated":false}
    Do evidence.%Set("version",$ZVERSION)
    Set releaseId=$Get(^StudioControl("activeRelease","blood-routing"))
    For scenario=1:1:3 {
        Set payload={"Mode":"SIMULATION"}
        Do payload.%Set("BloodGroup",$Select(scenario=2:"A+",1:"O+")),payload.%Set("Units",$Select(scenario=3:20,1:5),"number")
        Set args={}
        Do args.%Set("releaseId",releaseId),args.%Set("payload",payload)
        Set submitted=##class(%DynamicObject).%FromJSON(##class(Studio.Admin.TestHarness).ExecuteJson(args.%ToJSON()))
        If 'submitted.ok {
            Do evidence.%Set("ok",0,"boolean"),evidence.%Set("error",submitted)
            Return evidence.%ToJSON()
        }
        Set fetched=##class(%DynamicObject).%FromJSON(##class(Studio.Admin.TestHarness).GetRunJson(submitted.data.executionId))
        Set expected=$Select(scenario=1:"B",scenario=2:"C",1:"REVIEW")
        If ('fetched.ok)!(fetched.data.action'=expected)!(fetched.data.messageId="") {
            Do evidence.%Set("ok",0,"boolean"),evidence.%Set("error",fetched)
            Return evidence.%ToJSON()
        }
        Do evidence.runs.%Push(fetched.data)
    }
    Do evidence.%Set("ok",1,"boolean")
    Return evidence.%ToJSON()
}
}
