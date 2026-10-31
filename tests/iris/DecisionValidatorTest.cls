Include %occStatus

/// Run explicitly in an isolated namespace; no provider or Production required.
Class Studio.Tests.DecisionValidatorTest Extends %RegisteredObject
{
ClassMethod Run() As %Status
{
    Set binding = ##class(Studio.Model.DecisionBinding).%New()
    Set binding.RoutesJson = "{""PROCESS"":""ProcessOperation"",""REVIEW"":""ReviewOperation""}"
    Set binding.FallbackAction = "REVIEW", binding.FallbackTarget = "ReviewOperation"
    Set sc = ##class(Studio.AI.DecisionValidator).Validate(binding,"{""action"":""PROCESS""}",.result)
    If $$$ISERR(sc) Return sc
    If result.status'="SUCCESS" Return $$$ERROR($$$GeneralError,"Expected SUCCESS")
    Set sc = ##class(Studio.AI.DecisionValidator).ResolveRoute(binding,result.status,result.action,.target)
    If $$$ISERR(sc) Return sc
    If target'="ProcessOperation" Return $$$ERROR($$$GeneralError,"Wrong destination")
    Set candidates = $LISTBUILD("not json","[]","{""action"":""DELETE""}","{""action"":""PROCESS"",""target"":""UnsafeOperation""}","{""action"":true}","{""action"":""PROCESS"",""evidenceRefs"":[1]}")
    For i = 1:1:$LISTLENGTH(candidates) {
        Set sc = ##class(Studio.AI.DecisionValidator).Validate(binding,$LISTGET(candidates,i),.result)
        If $$$ISOK(sc) Return $$$ERROR($$$GeneralError,"Invalid candidate accepted")
        If result.status'="INVALID" Return $$$ERROR($$$GeneralError,"Invalid status lost")
        Set sc = ##class(Studio.AI.DecisionValidator).ResolveRoute(binding,result.status,result.action,.target)
        If $$$ISERR(sc) Return sc
        If target'="ReviewOperation" Return $$$ERROR($$$GeneralError,"Fallback not selected")
    }
    Set sc = ##class(Studio.AI.AgentRuntimeAdapter).Invoke("",{},"test",.raw,.session,.usage)
    If $$$ISOK(sc) Return $$$ERROR($$$GeneralError,"Unverified SDK accepted")
    If (raw'="")!(session'="") Return $$$ERROR($$$GeneralError,"Fabricated runtime evidence")
    Return $$$OK
}
}
