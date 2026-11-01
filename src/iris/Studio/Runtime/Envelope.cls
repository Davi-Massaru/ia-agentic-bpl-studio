Include %occStatus
Class Studio.Runtime.Envelope Extends %RegisteredObject
{
ClassMethod InputJson(pRequest As %RegisteredObject, pReleaseId As %String, pBindingId As %String = "", pAction As %String = "", pReason As %String = "") As %String
{
    Set manifest=##class(Studio.Runtime.Releases).Manifest(pReleaseId)
    If 'manifest.%IsDefined("binding") Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"RELEASE_REQUIRED"))
    If pRequest.%ClassName(1)'=manifest.requestClass Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"REQUEST_CLASS_MISMATCH"))
    Set binding=##class(Studio.Runtime.Releases).Binding(manifest,pBindingId)
    If 'binding.%IsDefined("bindingId") Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"BINDING_NOT_FOUND"))
    Set context={}
    Do context.%Set("Action",pAction),context.%Set("Reason",pReason)
    Set sc=##class(Studio.Runtime.InputMapper).Map(pRequest,context.%ToJSON(),binding,.input)
    If $$$ISERR(sc) Throw ##class(%Exception.StatusException).CreateFromStatus(sc)
    Return input.%ToJSON()
}
}
