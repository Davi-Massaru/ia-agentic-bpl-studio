Include %occStatus
Class Studio.Runtime.Envelope Extends %RegisteredObject
{
ClassMethod InputJson(pRequest As %RegisteredObject, pReleaseId As %String) As %String
{
    Set manifest=##class(Studio.Runtime.Releases).Manifest(pReleaseId)
    If 'manifest.%IsDefined("binding") Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"RELEASE_REQUIRED"))
    If pRequest.%ClassName(1)'=manifest.requestClass Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"REQUEST_CLASS_MISMATCH"))
    Set sc=##class(Studio.Runtime.InputMapper).Map(pRequest,"{}",manifest.binding,.input)
    If $$$ISERR(sc) Throw ##class(%Exception.StatusException).CreateFromStatus(sc)
    Return input.%ToJSON()
}
}
