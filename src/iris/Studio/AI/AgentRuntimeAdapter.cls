Include %occStatus

/// Native SDK adapter. Signatures verified on Community 2026.3.0AI.154.0.
Class Studio.AI.AgentRuntimeAdapter Extends %RegisteredObject
{
ClassMethod ValidateSDKCapabilities(Output pReport As %DynamicObject) As %Status
{
    Set pReport = ##class(Studio.Admin.CapabilityProbe).Inspect()
    If $ZVERSION'["Build 154" Return $$$ERROR($$$GeneralError,"AI_HUB_BUILD_MISMATCH")
    Return $$$OK
}

ClassMethod Invoke(pAgent As Studio.Model.AgentDefinition, pInput As %DynamicObject, pDecisionExecutionId As %String, Output pRawResponse As %String, Output pAgentSessionId As %String, Output pUsage As %DynamicObject) As %Status
{
    Set pRawResponse = "", pAgentSessionId = "", pUsage = {}
    Try {
        If '$IsObject(pAgent) Return $$$ERROR($$$GeneralError,"AGENT_REQUIRED")
        If (pAgent.ProviderRef'="openai")&&(pAgent.ProviderRef'="anthropic") Return $$$ERROR($$$GeneralError,"PROVIDER_NOT_ALLOWED")
        Set sc=..ValidateSDKCapabilities(.report)
        If $$$ISERR(sc) Return sc
        Set sc=##class(Studio.Admin.Settings).ProviderSettings(pAgent.ProviderRef,.settings)
        If $$$ISERR(sc) Return sc
        Set provider=##class(%AI.Provider).Create(pAgent.ProviderRef,settings)
        If '$IsObject(provider) Return $$$ERROR($$$GeneralError,"PROVIDER_NOT_CONFIGURED")
        Set agent=##class(%AI.Agent).%New(provider)
        Set agent.Model=pAgent.ModelName,agent.SystemPrompt=pAgent.Prompt,agent.MaxIterations=4
        Set agent.SystemPrompt=agent.SystemPrompt_$CHAR(10)_"Output contract: return exactly one JSON object, without Markdown, containing only action (string), reason (string), and evidenceRefs (array of strings). Never add status, target, or other fields. Never use null. Use only the actions permitted by the instructions."
        Set tools=##class(%DynamicArray).%FromJSON(pAgent.ToolSetRefsJson)
        For i=0:1:tools.%Size()-1 {
            If '##class(Studio.Admin.ToolRegistry).IsAllowed(tools.%Get(i)) Return $$$ERROR($$$GeneralError,"TOOLSET_DENIED")
            Set sc=agent.UseToolSet(tools.%Get(i))
            If $$$ISERR(sc) Return sc
        }
        Set session=agent.CreateSession()
        Set sc=session.%Save()
        If $$$ISERR(sc) Return sc
        Set pAgentSessionId=session.%Id()
        Set ^||StudioExecutionId=pDecisionExecutionId
        Set metadata={}
        Do metadata.%Set("provider",pAgent.ProviderRef),metadata.%Set("model",pAgent.ModelName)
        Set observation=##class(Studio.Trace.Recorder).Start(pDecisionExecutionId,pDecisionExecutionId,$Get(^||StudioParentObservation),"agent","AI Hub Chat",metadata.%ToJSON())
        Set ^||StudioAgentObservation=observation
        Set result=agent.Chat(session,pInput.%ToJSON())
        Set pRawResponse=result.Content,pUsage=session.GetStats()
        Set sc=session.%Save()
        Do ##class(Studio.Trace.Recorder).Finish(pDecisionExecutionId,$Get(observation),"SUCCESS","{}",pUsage.%ToJSON())
        Kill ^||StudioExecutionId,^||StudioAgentObservation
        If $$$ISERR(sc) Return sc
    } Catch ex {
        Do ##class(Studio.Trace.Recorder).Finish(pDecisionExecutionId,$Get(observation),"ERROR")
        Kill ^||StudioExecutionId,^||StudioAgentObservation
        // Do not expose provider errors, settings, credentials or raw exception text.
        Return $$$ERROR($$$GeneralError,"AI_PROVIDER_INVOCATION_FAILED")
    }
    Return $$$OK
}
}

