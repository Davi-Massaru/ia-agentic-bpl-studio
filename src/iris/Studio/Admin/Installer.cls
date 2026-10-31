Include %occStatus
Class Studio.Admin.Installer Extends %RegisteredObject
{
/// Explicit source migration for the known v1->v2 package update; never an HTTP action.
ClassMethod UpgradeTemplate() As %Status
{
    If '##class(Studio.Admin.RuntimeBridge).HasAccess() Return $$$ERROR($$$GeneralError,"ACCESS_DENIED")
    Set old="c9b44f4eb5278f4fd2197301983939b60431d533f7fd2a2cc175d61b792a2415"
    Set hash=##class(Studio.Admin.ControlPlane).Hash(##class(Studio.Admin.ControlPlane).Source())
    If $Get(^StudioControl("baseline"))=hash Return $$$OK
    If $Get(^StudioControl("baseline"))'=old Return $$$ERROR($$$GeneralError,"UNRECOGNIZED_TEMPLATE_MIGRATION")
    Lock +^StudioControl("write"):5
    If '$Test Return $$$ERROR($$$GeneralError,"INSTALL_LOCK_TIMEOUT")
    Try {
        TStart
        Set previous=##class(Studio.Model.WorkflowDraft).%OpenId(^StudioControl("draft",^StudioControl("draft","latest")))
        Set draft=##class(Studio.Model.WorkflowDraft).%New()
        Set draft.WorkflowId=previous.WorkflowId,draft.Revision=previous.Revision+1,draft.BaseHash=hash
        Set draft.BindingJson=previous.BindingJson,draft.BindingRevision=previous.BindingRevision,draft.CreatedBy=$USERNAME
        Set sc=draft.%Save()
        If $$$ISERR(sc) Throw ##class(%Exception.StatusException).CreateFromStatus(sc)
        Set ^StudioControl("draft",draft.Revision)=draft.%Id(),^StudioControl("draft","latest")=draft.Revision,^StudioControl("baseline")=hash
        TCommit
    } Catch ex {
        TRollback
        Set sc=ex.AsStatus()
    }
    Lock -^StudioControl("write")
    Return sc
}
}
