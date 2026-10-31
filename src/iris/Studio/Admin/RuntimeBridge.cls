Class Studio.Admin.RuntimeBridge Extends %RegisteredObject
{
ClassMethod CurrentUser() As %String
{
    Return $USERNAME
}
ClassMethod HasAccess() As %Boolean
{
    Return ($NAMESPACE="USER")&&($USERNAME'="UnknownUser")&&$SYSTEM.Security.Check("%Development","USE")
}
ClassMethod CsrfToken() As %String
{
    If '..HasAccess() Return ""
    Lock +^StudioControl("csrfLock"):5
    If '$Test Return ""
    If $Get(^StudioControl("csrf"))="" Set ^StudioControl("csrf")=$Translate($SYSTEM.Util.CreateGUID()_$SYSTEM.Util.CreateGUID(),"-")
    Set token=^StudioControl("csrf")
    Lock -^StudioControl("csrfLock")
    Return token
}
}
