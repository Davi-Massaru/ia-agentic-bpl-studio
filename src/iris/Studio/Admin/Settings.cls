Include %occStatus
/// Local provider preferences; secrets are stored only in IRIS Wallet.
Class Studio.Admin.Settings Extends %RegisteredObject
{
ClassMethod ConnectionVerified() As %Boolean
{
    Set provider=$Get(^StudioSettings("provider")),model=$Get(^StudioSettings("model",provider))
    Return (provider'="")&&(model'="")&&($Get(^StudioSettings("connectionProof",provider,model))'="")
}
/// A proof comes only from an already persisted native LIVE trace, never from UI input.
ClassMethod RecordLiveProof(pExecutionId As %String) As %Boolean
{
    If '##class(Studio.Admin.RuntimeBridge).HasAccess() Return 0
    Set data=$Get(^StudioAudit(pExecutionId,"trace"))
    If data="" Return 0
    Try {
        Set trace=##class(%DynamicObject).%FromJSON(data)
        If (trace.%Get("mode")'="LIVE")!(trace.%Get("status")'="SUCCESS") Return 0
        If (trace.%Get("agentSessionId")="")!(trace.%Get("messageId")="") Return 0
        If 'trace.%IsDefined("usage") Return 0
        If trace.usage.%Get("total_interactions")<1 Return 0
        Set manifest=##class(Studio.Runtime.Releases).Manifest(trace.releaseId)
        If 'manifest.%IsDefined("agent") Return 0
        Set provider=manifest.agent.providerRef,model=manifest.agent.modelName
        If '+$Get(^StudioSettings("credential",provider)) Return 0
        Set ^StudioSettings("connectionProof",provider,model)=pExecutionId
        Return 1
    } Catch ex { Return 0 }
}
/// Installer-only setup; interactive users edit these entries through delegated USE permission.
ClassMethod Provision() As %Status
{
    If '$SYSTEM.Security.Check("%Admin_ConfigStore","USE") Return $$$ERROR($$$GeneralError,"INSTALLER_PERMISSION_REQUIRED")
    Set sc=##class(%ConfigStore.DescriptorManager).GetDescriptorClass("AI","LLM","",.descriptor)
    If $$$ISERR(sc) Set sc=##class(%ConfigStore.DescriptorManager).RebuildRegistry()
    If $$$ISERR(sc) Return sc
    Set permissions={"UseResource":"%Development:USE","EditResource":"%Development:USE"}
    If ##class(%Wallet.Collection).Exists("StudioSecrets") {
        Set sc=##class(%Wallet.Collection).Modify("StudioSecrets",.permissions)
    } Else {
        Set sc=##class(%Wallet.Collection).Create("StudioSecrets",.permissions)
    }
    If $$$ISERR(sc) Return sc
    For provider="openai","anthropic" {
        Set fqn="AI.LLM.studio-"_provider
        If '##class(%ConfigStore.Configuration).Exists(fqn) {
            Set details={"model":"configure-in-settings"}
            Do details.%Set("model_provider",provider),details.%Set("api_key","secret://StudioSecrets."_provider_"#api_key")
            Set sc=##class(%ConfigStore.Configuration).Create("AI","LLM","","studio-"_provider,details,"Studio "_provider,"Local Studio provider settings","%Development:USE","%Development:USE",0)
            If $$$ISERR(sc) Return sc
        }
    }
    Return $$$OK
}
ClassMethod Initialize() As %Status
{
    If '##class(Studio.Admin.RuntimeBridge).HasAccess() Return $$$ERROR($$$GeneralError,"ACCESS_DENIED")
    If ##class(%Wallet.Collection).Exists("StudioSecrets") Return $$$OK
    Set permissions={"UseResource":"%Development:USE","EditResource":"%Development:USE"}
    Return ##class(%Wallet.Collection).Create("StudioSecrets",.permissions)
}
ClassMethod Read() As %String
{
    If '##class(Studio.Admin.RuntimeBridge).HasAccess() Return ##class(Studio.Admin.ControlPlane).Error("ACCESS_DENIED","Native administrative permission required.",403)
    Set result={"providers":[{"id":"openai","name":"OpenAI"},{"id":"anthropic","name":"Anthropic"}],"storage":"IRIS Wallet + Config Store","connectionTested":false}
    Set provider=$Get(^StudioSettings("provider"))
    Set model="",configured=0
    If provider'="" Set model=$Get(^StudioSettings("model",provider)),configured=+$Get(^StudioSettings("credential",provider))
    Do result.%Set("provider",provider),result.%Set("model",model)
    Do result.%Set("hasCredential",configured,"boolean"),result.%Set("configured",configured,"boolean")
    Do result.%Set("connectionTested",..ConnectionVerified(),"boolean")
    Return ##class(Studio.Admin.ControlPlane).OK(result)
}
ClassMethod Save(pJson As %String) As %String
{
    If '##class(Studio.Admin.RuntimeBridge).HasAccess() Return ##class(Studio.Admin.ControlPlane).Error("ACCESS_DENIED","Native administrative permission required.",403)
    Set stage="VALIDATE"
    Try {
        Set value=##class(%DynamicObject).%FromJSON(pJson)
        If '##class(Studio.Admin.ControlPlane).OnlyFields(value,"provider,model,apiKey") Return ##class(Studio.Admin.ControlPlane).Error("INVALID_SETTINGS","Unknown configuration fields.")
        Set provider=value.%Get("provider"),model=value.%Get("model"),key=value.%Get("apiKey")
        If (provider'="openai")&&(provider'="anthropic") Return ##class(Studio.Admin.ControlPlane).Error("INVALID_PROVIDER","Select an installed supported provider.")
        If (value.%GetTypeOf("model")'="string")!('##class(Studio.Admin.ControlPlane).TextAllowed(model,128)) Return ##class(Studio.Admin.ControlPlane).Error("INVALID_MODEL","A model identifier is required.")
        If value.%IsDefined("apiKey"),value.%GetTypeOf("apiKey")'="string" Return ##class(Studio.Admin.ControlPlane).Error("INVALID_CREDENTIAL","Credential must be a string.")
        If $Length(key)>1024 Return ##class(Studio.Admin.ControlPlane).Error("INVALID_CREDENTIAL","Credential exceeds the supported length.")
        If key'="" {
            If '##class(Studio.Admin.ControlPlane).TextAllowed(key,1024) Return ##class(Studio.Admin.ControlPlane).Error("INVALID_CREDENTIAL","Credential contains unsupported characters.")
            Set stage="WALLET_INITIALIZE",sc=..Initialize()
            If $$$ISERR(sc) Return ##class(Studio.Admin.ControlPlane).Error("WALLET_UNAVAILABLE","Secure credential storage is unavailable.",503)
            Set secret={"Usage":"CUSTOM","Secret":{}}
            Do secret.Secret.%Set("api_key",key)
            Set name="StudioSecrets."_provider
            Set stage="WALLET_SECRET"
            If ##class(%Wallet.KeyValue).Exists(name) {
                Set sc=##class(%Wallet.KeyValue).UpdateSecret(name,secret.Secret)
            } Else {
                Set sc=##class(%Wallet.KeyValue).Create(name,.secret)
            }
            Kill key,secret
            If $$$ISERR(sc) Return ##class(Studio.Admin.ControlPlane).Error("WALLET_SAVE_FAILED","The credential could not be stored securely.",503)
            Set ^StudioSettings("credential",provider)=1
            Kill ^StudioSettings("connectionProof",provider)
        }
        If +$Get(^StudioSettings("credential",provider)) {
            Set details={}
            Do details.%Set("model_provider",provider),details.%Set("model",model),details.%Set("api_key","secret://StudioSecrets."_provider_"#api_key")
            Set fqn="AI.LLM.studio-"_provider
            Set stage="CONFIG_STORE"
            If ##class(%ConfigStore.Configuration).Exists(fqn) {
                Set sc=##class(%ConfigStore.Configuration).Modify(fqn,details,"Studio "_provider,"Local Studio provider settings","%Development:USE","%Development:USE",1)
            } Else {
                Return ##class(Studio.Admin.ControlPlane).Error("CONFIG_SETUP_REQUIRED","Run the local web configuration installer before saving provider settings.",503)
            }
            If $$$ISERR(sc) Return ##class(Studio.Admin.ControlPlane).Error("CONFIG_SAVE_FAILED","Provider metadata could not be validated/stored.",422)
        }
        Set ^StudioSettings("provider")=provider,^StudioSettings("model",provider)=model
        Return ..Read()
    } Catch ex {
        // Deliberately do not return exception text or request values.
        Return ##class(Studio.Admin.ControlPlane).Error("SETTINGS_SAVE_FAILED","Provider settings could not be saved at "_stage_".",422)
    }
}
ClassMethod ProviderSettings(pProvider As %String, Output pSettings As %DynamicObject) As %Status
{
    Set pSettings={}
    Set fqn="AI.LLM.studio-"_pProvider
    If '##class(%ConfigStore.Configuration).Exists(fqn) Return $$$OK
    Return ##class(%ConfigStore.Configuration).GetDetails(fqn,.pSettings,1,1)
}
}
