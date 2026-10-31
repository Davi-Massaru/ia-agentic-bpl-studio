Include %occStatus
Class Studio.Tests.ControlPlaneTest Extends %RegisteredObject
{
ClassMethod Run() As %Status
{
    Set sc=##class(Studio.Admin.ControlPlane).Initialize()
    If $$$ISERR(sc) Return sc
    Set result=##class(%DynamicObject).%FromJSON(##class(Studio.Admin.ControlPlane).Dispatch("get_workflow","{""workflowId"":""blood-routing""}"))
    If 'result.ok Return $$$ERROR($$$GeneralError,"WORKFLOW_READ_FAILED")
    If 'result.data.managed Return $$$ERROR($$$GeneralError,"WORKFLOW_NOT_MANAGED")
    If $LENGTH(result.data.baseHash)'=64 Return $$$ERROR($$$GeneralError,"SOURCE_HASH_INVALID")
    Set denied=##class(%DynamicObject).%FromJSON(##class(Studio.Admin.ControlPlane).Dispatch("get_workflow","{""workflowId"":""unmanaged""}"))
    If denied.ok Return $$$ERROR($$$GeneralError,"UNMANAGED_WORKFLOW_ALLOWED")
    If denied.httpStatus'=404 Return $$$ERROR($$$GeneralError,"UNMANAGED_WORKFLOW_WRONG_STATUS")
    Set validation=##class(%DynamicObject).%FromJSON(##class(Studio.Admin.ControlPlane).Dispatch("validate_workflow","{""workflowId"":""blood-routing""}"))
    If 'validation.ok Return $$$ERROR($$$GeneralError,"VALIDATION_FAILED")
    If 'validation.data.valid Return $$$ERROR($$$GeneralError,"MANAGED_TEMPLATE_INVALID")
    Set workflow=##class(Studio.Admin.ControlPlane).Workflow()
    Set args={"bindingId":"blood-routing:decision","expectedRevision":0}
    Do args.%Set("payload",workflow.binding)
    Set conflict=##class(%DynamicObject).%FromJSON(##class(Studio.Admin.ControlPlane).Dispatch("save_binding",args.%ToJSON()))
    If conflict.ok Return $$$ERROR($$$GeneralError,"STALE_BINDING_SAVED")
    If conflict.httpStatus'=409 Return $$$ERROR($$$GeneralError,"STALE_BINDING_WRONG_STATUS")
    Do args.%Set("expectedRevision",workflow.bindingRevision,"number")
    Do args.payload.routes.%Set("B","UnapprovedOperation")
    Set denied=##class(%DynamicObject).%FromJSON(##class(Studio.Admin.ControlPlane).Dispatch("save_binding",args.%ToJSON()))
    If denied.ok Return $$$ERROR($$$GeneralError,"UNAPPROVED_ROUTE_SAVED")
    Set args={"agentId":"validation-only","baseRevision":0,"definition":{"providerRef":"openai","modelName":"example-model","prompt":"Safe fictional inventory exercise.","toolSetRefs":["Studio.Tools.BloodStockTools"]}}
    Do args.definition.%Set("apiKey","dummy-secret-must-not-persist")
    Set denied=##class(%DynamicObject).%FromJSON(##class(Studio.Admin.ControlPlane).Dispatch("save_agent_revision",args.%ToJSON()))
    If denied.ok Return $$$ERROR($$$GeneralError,"CREDENTIAL_FIELD_ACCEPTED")
    If denied.httpStatus'=422 Return $$$ERROR($$$GeneralError,"CREDENTIAL_FIELD_WRONG_STATUS")
    Do args.definition.%Remove("apiKey")
    Do args.definition.%Set("providerRef","unsupported")
    Set denied=##class(%DynamicObject).%FromJSON(##class(Studio.Admin.ControlPlane).Dispatch("save_agent_revision",args.%ToJSON()))
    If denied.ok Return $$$ERROR($$$GeneralError,"UNSUPPORTED_PROVIDER_ACCEPTED")
    Do args.definition.%Set("providerRef","openai"),args.definition.%Set("toolSetRefs",[])
    Set denied=##class(%DynamicObject).%FromJSON(##class(Studio.Admin.ControlPlane).Dispatch("save_agent_revision",args.%ToJSON()))
    If denied.ok Return $$$ERROR($$$GeneralError,"EMPTY_TOOLS_ACCEPTED")
    Do args.definition.%Set("toolSetRefs",["Studio.Tools.BloodStockTools"]),args.definition.%Set("prompt","text"_$CHAR(0)_"text")
    Set denied=##class(%DynamicObject).%FromJSON(##class(Studio.Admin.ControlPlane).Dispatch("save_agent_revision",args.%ToJSON()))
    If denied.ok Return $$$ERROR($$$GeneralError,"NUL_PROMPT_ACCEPTED")
    Set denied=##class(%DynamicObject).%FromJSON(##class(Studio.Admin.ControlPlane).Dispatch("list_agents","{""workflowId"":""unmanaged""}"))
    If denied.ok Return $$$ERROR($$$GeneralError,"UNKNOWN_READ_SCOPE_IGNORED")
    Set bad={"workflowId":"blood-routing","baseHash":"stale","revision":1,"approvalRef":"test","idempotencyKey":"test-stale-key"}
    Set result=##class(%DynamicObject).%FromJSON(##class(Studio.Admin.ControlPlane).Dispatch("publish_workflow",bad.%ToJSON()))
    If result.ok Return $$$ERROR($$$GeneralError,"STALE_SOURCE_PUBLISHED")
    If result.httpStatus'=409 Return $$$ERROR($$$GeneralError,"STALE_SOURCE_WRONG_STATUS")
    Return $$$OK
}
}
