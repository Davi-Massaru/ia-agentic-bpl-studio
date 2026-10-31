Include %occStatus
/// Explicitly authorized local install: project account and password-authenticated WSGI.
Class Studio.Admin.WebSetup Extends %RegisteredObject
{
ClassMethod Configure(pCredentialFile As %String = "/tmp/studio-auth.json") As %Status
{
    If '##class(Studio.Admin.RuntimeBridge).HasAccess() Return $$$ERROR($$$GeneralError,"INSTALL_ACCESS_DENIED")
    Set stream=##class(%Stream.FileCharacter).%New()
    Set sc=stream.LinkToFile(pCredentialFile)
    If $$$ISERR(sc) Return sc
    Set credentials=##class(%DynamicObject).%FromJSON(stream)
    If credentials.username'="studio" Return $$$ERROR($$$GeneralError,"INSTALL_USER_INVALID")
    New $Namespace
    Set $Namespace="%SYS"
    If '##class(Security.Users).Exists("studio") {
        Set sc=##class(Security.Users).Create("studio","%Developer,%DB_USER,%EnsRole_Administrator",credentials.password,"Agentic BPL Studio local developer","USER","","",0,1,"User-authorized local project account")
        If $$$ISERR(sc) Return sc
    }
    // Native BPL editing requires write access; Administrator grants only read.
    If '##class(Security.Roles).Exists("StudioBPLEditor") {
        Set sc=##class(Security.Roles).Create("StudioBPLEditor","Local Studio native BPL editing","%Ens_Code:RW")
        If $$$ISERR(sc) Return sc
    }
    Set sc=##class(Security.Users).Get("studio",.userProps)
    If $$$ISERR(sc) Return sc
    Set existingRoles=userProps("Roles")
    Kill userProps
    Set userProps("Roles")=existingRoles_$Select((","_existingRoles_",")[",StudioBPLEditor,":"",1:",StudioBPLEditor")
    Set sc=##class(Security.Users).Modify("studio",.userProps)
    If $$$ISERR(sc) Return sc
    Set props("NameSpace")="USER",props("Description")="Agentic BPL Studio",props("Enabled")=1
    Set props("Type")=2,props("DispatchClass")="%SYS.Python.WSGI",props("AutheEnabled")=32
    Set props("LoginPage")="%CSP.Login.cls"
    Set props("CSPZENEnabled")=1,props("WSGIAppLocation")="/opt/studio/backend",props("WSGIAppName")="wsgi_iris",props("WSGICallable")="application",props("WSGIType")=1
    Set props("Path")="",props("ServeFiles")=0,props("CookiePath")="/csp/studio/",props("UseCookies")=2
    Set props("Recurse")=1
    If ##class(Security.Applications).Exists("/csp/studio") Return ##class(Security.Applications).Modify("/csp/studio",.props)
    Return ##class(Security.Applications).Create("/csp/studio",.props)
}
}
