Include %occStatus

Class Studio.Tests.InputMapperTest Extends %RegisteredObject
{
ClassMethod Run() As %Status
{
    Set request=##class(Studio.Tests.InputMapperRequest).%New()
    Set request.EventId="EVT-1",request.Description="private description",request.Units=5,request.Cost=3.25,request.IsEnabled=0
    Set binding={"inputs":[{"source":"request.EventId","target":"id","required":true},{"source":"request.Units","target":"units","required":true},{"source":"request.IsEnabled","target":"enabled","required":true},{"source":"request.Cost","target":"cost","required":true}],"outputs":{"action":"context.Action","reason":"response.Reason"}}
    Set sc=##class(Studio.Runtime.InputMapper).Validate("Studio.Tests.InputMapperRequest",binding,.issues)
    If $$$ISERR(sc) Return sc
    Set sc=##class(Studio.Runtime.InputMapper).Map(request,"{}",binding,.result)
    If $$$ISERR(sc) Return sc
    If (result.id'="EVT-1")!(result.units'=5)!(result.enabled'=0) Return $$$ERROR($$$GeneralError,"TYPED_MAPPING_VALUES_FAILED")
    If (result.%GetTypeOf("units")'="number")!(result.%GetTypeOf("enabled")'="boolean")!(result.%GetTypeOf("cost")'="number") Return $$$ERROR($$$GeneralError,"TYPED_MAPPING_JSON_FAILED")
    Set sc=##class(Studio.Runtime.InputMapper).Map(request,"{}",binding,.redacted,1)
    If $$$ISERR(sc) Return sc
    If (redacted.id'="[REDACTED]")!(redacted.units'="[REDACTED]") Return $$$ERROR($$$GeneralError,"PREVIEW_LEAKED_VALUE")

    Set dynamic={"inputs":[{"source":"context.Reason","target":"contextReason","required":false},{"source":"constant:literal $System evil()","target":"constant","required":true}],"outputs":{"action":"response.Action"}}
    Set sc=##class(Studio.Runtime.InputMapper).Map(request,"{}",dynamic,.result)
    If $$$ISERR(sc) Return sc
    If result.%IsDefined("contextReason") Return $$$ERROR($$$GeneralError,"OPTIONAL_CONTEXT_NOT_OMITTED")
    If result.constant'="literal $System evil()" Return $$$ERROR($$$GeneralError,"CONSTANT_NOT_LITERAL")
    Set sc=##class(Studio.Runtime.InputMapper).Map(request,"{""Reason"":""context data""}",dynamic,.result)
    If $$$ISERR(sc) Return sc
    If result.contextReason'="context data" Return $$$ERROR($$$GeneralError,"CONTEXT_MAPPING_FAILED")

    Set required={"inputs":[{"source":"request.EventId","target":"id","required":true},{"source":"context.Reason","target":"reason","required":true}],"outputs":{"action":"context.Action"}}
    Set sc=##class(Studio.Runtime.InputMapper).Map(request,"{}",required,.result)
    If $$$ISOK(sc) Return $$$ERROR($$$GeneralError,"MISSING_REQUIRED_ACCEPTED")
    If result.%Size()'=0 Return $$$ERROR($$$GeneralError,"PARTIAL_OUTPUT_ON_FAILURE")
    Set sc=##class(Studio.Runtime.InputMapper).Map(request,"{""Reason"":true}",required,.result)
    If $$$ISOK(sc) Return $$$ERROR($$$GeneralError,"CONTEXT_TYPE_MISMATCH_ACCEPTED")

    Set sources=$ListBuild("request.Missing","request.EventId.X","request.%Save()","request.EventId[0]","request.UnsafeObject","context.Arbitrary")
    For i=1:1:$ListLength(sources) {
        Set invalid={"inputs":[],"outputs":{"action":"context.Action"}},item={"target":"value","required":true}
        Do item.%Set("source",$ListGet(sources,i)),invalid.inputs.%Push(item)
        Set sc=##class(Studio.Runtime.InputMapper).Validate("Studio.Tests.InputMapperRequest",invalid,.issues)
        If $$$ISOK(sc) Return $$$ERROR($$$GeneralError,"UNSAFE_SOURCE_ACCEPTED")
    }
    Set invalid={"inputs":[{"source":"request.EventId","target":"same","required":true},{"source":"request.Description","target":"same","required":false}],"outputs":{"action":"context.Action"}}
    Set sc=##class(Studio.Runtime.InputMapper).Validate("Studio.Tests.InputMapperRequest",invalid,.issues)
    If $$$ISOK(sc) Return $$$ERROR($$$GeneralError,"DUPLICATE_TARGET_ACCEPTED")
    Set invalid={"inputs":[{"source":"request.EventId","target":"id","required":true}],"outputs":{"action":"context.Reason"}}
    Set sc=##class(Studio.Runtime.InputMapper).Validate("Studio.Tests.InputMapperRequest",invalid,.issues)
    If $$$ISOK(sc) Return $$$ERROR($$$GeneralError,"UNSUPPORTED_OUTPUT_ACCEPTED")
    Set invalid={"inputs":[{"source":"request.EventId","target":"id","required":"true"}],"outputs":{"action":"context.Action"}}
    Set sc=##class(Studio.Runtime.InputMapper).Validate("Studio.Tests.InputMapperRequest",invalid,.issues)
    If $$$ISOK(sc) Return $$$ERROR($$$GeneralError,"REQUIRED_FLAG_NOT_BOOLEAN")

    Set example="{""EventId"":""private-id"",""Units"":5,""Cost"":3.25,""IsEnabled"":false}"
    Set preview=##class(%DynamicObject).%FromJSON(##class(Studio.Runtime.InputMapper).Preview("Studio.Tests.InputMapperRequest",example,binding.%ToJSON()))
    If 'preview.ok Return $$$ERROR($$$GeneralError,"PREVIEW_FAILED")
    If preview.data.input.id'="[REDACTED]" Return $$$ERROR($$$GeneralError,"PREVIEW_EXPOSED_INPUT")
    Set badExample="{""EventId"":""private-id"",""Units"":true}"
    Set preview=##class(%DynamicObject).%FromJSON(##class(Studio.Runtime.InputMapper).Preview("Studio.Tests.InputMapperRequest",badExample,binding.%ToJSON()))
    If preview.ok Return $$$ERROR($$$GeneralError,"PREVIEW_BOOL_AS_NUMBER_ACCEPTED")
    Set json=##class(Studio.Runtime.InputMapper).MapJson(request,binding.%ToJSON())
    Set parsed=##class(%DynamicObject).%FromJSON(json)
    If parsed.units'=5 Return $$$ERROR($$$GeneralError,"MAP_JSON_HELPER_FAILED")
    Return $$$OK
}
}
