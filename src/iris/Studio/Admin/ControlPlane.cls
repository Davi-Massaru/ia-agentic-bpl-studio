Include %occStatus

/// Narrow administrative API for the installed managed blood-routing template.
/// Called through an authenticated embedded/native IRIS connection, never raw HTTP headers.
Class Studio.Admin.ControlPlane Extends %RegisteredObject
{
ClassMethod Error(pCode As %String, pMessage As %String, pStatus As %Integer = 422) As %String
{
    Set result={"ok":false}
    Do result.%Set("errorCode",pCode),result.%Set("message",pMessage),result.%Set("httpStatus",pStatus)
    Return result.%ToJSON()
}

ClassMethod OK(pData As %DynamicAbstractObject) As %String
{
    Set result={"ok":true}
    Do result.%Set("data",pData)
    Return result.%ToJSON()
}

ClassMethod Authorized() As %Boolean
{
    Return ($NAMESPACE="USER")&&($USERNAME'="")&&$SYSTEM.Security.Check("%Development","USE")
}

ClassMethod Hash(pSource As %String) As %String
{
    Set digest=$SYSTEM.Encryption.SHAHash(256,$ZConvert(pSource,"O","UTF8")),value="",digits="0123456789abcdef"
    For i=1:1:$LENGTH(digest) {
        Set byte=$ASCII(digest,i)
        Set value=value_$EXTRACT(digits,(byte\16)+1)_$EXTRACT(digits,(byte#16)+1)
    }
    Return value
}

ClassMethod ReleaseManifest(pReleaseId As %String) As %DynamicObject
{
    If '..Authorized() Return {}
    Set generic=##class(Studio.Admin.Workspace).ReleaseManifest(pReleaseId)
    If generic.%IsDefined("releaseId") Return generic
    Set id=$GET(^StudioControl("release",pReleaseId))
    If id="" Return {}
    Set release=##class(Studio.Model.WorkflowRelease).%OpenId(id)
    If '$ISOBJECT(release) Return {}
    Return ##class(%DynamicObject).%FromJSON(release.ManifestJson)
}

ClassMethod LiveProof() As %Boolean
{
    Set releaseId=$Get(^StudioControl("activeRelease","blood-routing"))
    If releaseId="" Return 0
    Set manifest=..ReleaseManifest(releaseId)
    If 'manifest.%IsDefined("baseHash") Return 0
    If manifest.baseHash'=..Hash(..Source()) Return 0
    Return ($Get(^StudioAIProof(releaseId,"B"))'="")&&($Get(^StudioAIProof(releaseId,"C"))'="")
}

ClassMethod Source() As %String
{
    Set definition=##class(%Dictionary.ClassDefinition).%OpenId("Studio.BloodDemo.Routing")
    If '$ISOBJECT(definition) Return ""
    Set key="",source=""
    For {
        Set xdata=definition.XDatas.GetNext(.key)
        Quit:key=""
        If xdata.Name="BPL" {
            Do xdata.Data.Rewind()
            Set source=xdata.Data.Read(100000)
            Quit
        }
    }
    Return source
}

/// Explicit install-time seed; reading metadata never mutates IRIS.
ClassMethod Initialize() As %Status
{
    If '..Authorized() Return $$$ERROR($$$GeneralError,"ADMIN_ACCESS_DENIED")
    Lock +^StudioControl("write"):5
    If '$TEST Return $$$ERROR($$$GeneralError,"ADMIN_LOCK_TIMEOUT")
    Try {
        If '$DATA(^StudioControl("baseline")) {
            Set source=..Source()
            If source="" Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"BPL_SOURCE_MISSING"))
            Set ^StudioControl("baseline")=..Hash(source)
        }
        If '$DATA(^StudioControl("agent","blood-stock","latest")) {
            Set agent=##class(Studio.Model.AgentDefinition).%New()
            Set agent.AgentId="blood-stock",agent.Revision=1,agent.ProviderRef="openai",agent.ModelName="gpt-4.1-mini"
            Set agent.Prompt="Use the authorized inventory tool. Choose sufficient same-group stock with shortest ETA; B wins ties. Return JSON action B/C/REVIEW, reason, evidenceRefs. No transfer."
            Set agent.ToolSetRefsJson="[""Studio.Tools.BloodStockTools""]"
            Set sc=agent.%Save()
            If $$$ISERR(sc) Throw ##class(%Exception.StatusException).CreateFromStatus(sc)
            Set ^StudioControl("agent","blood-stock",1)=agent.%Id(),^StudioControl("agent","blood-stock","latest")=1
        }
        If '$DATA(^StudioControl("draft","latest")) {
            Set binding={"bindingId":"blood-routing:decision","agentRef":{"id":"blood-stock","revision":1},"inputs":[{"source":"request.BloodGroup","target":"group","required":true},{"source":"request.Units","target":"units","required":true}],"outputs":{"action":"context.Destination"},"routes":{"B":"HemocentroB","C":"HemocentroC","REVIEW":"Review"},"fallback":{"action":"REVIEW","target":"Review"},"timeouts":{"agentMs":30000}}
            Set draft=##class(Studio.Model.WorkflowDraft).%New()
            Set draft.WorkflowId="blood-routing",draft.Revision=1,draft.BaseHash=^StudioControl("baseline"),draft.BindingJson=binding.%ToJSON(),draft.BindingRevision=1,draft.CreatedBy=$USERNAME
            Set sc=draft.%Save()
            If $$$ISERR(sc) Throw ##class(%Exception.StatusException).CreateFromStatus(sc)
            Set ^StudioControl("draft",1)=draft.%Id(),^StudioControl("draft","latest")=1
        }
        Set sc=$$$OK
    } Catch ex { Set sc=ex.AsStatus() }
    Lock -^StudioControl("write")
    Return sc
}

ClassMethod Agent(pId As %String, pRevision As %Integer) As %DynamicObject
{
    Set result={}
    Set id=$GET(^StudioControl("agent",pId,pRevision))
    If id="" Return result
    Set agent=##class(Studio.Model.AgentDefinition).%OpenId(id)
    If '$ISOBJECT(agent) Return result
    Do result.%Set("agentId",agent.AgentId),result.%Set("id",agent.AgentId),result.%Set("revision",agent.Revision,"number")
    Do result.%Set("providerRef",agent.ProviderRef),result.%Set("modelName",agent.ModelName),result.%Set("prompt",agent.Prompt)
    Do result.%Set("toolSetRefs",##class(%DynamicArray).%FromJSON(agent.ToolSetRefsJson))
    Return result
}

ClassMethod Workflow() As %DynamicObject
{
    Set result={"workflowId":"blood-routing","className":"Studio.BloodDemo.Routing","production":"Studio.BloodDemo.Production","bindingId":"blood-routing:decision","managed":false,"readOnlyReason":"Managed template not initialized."}
    Set source=..Source(),hash=..Hash(source),revision=$GET(^StudioControl("draft","latest"))
    Do result.%Set("source",source),result.%Set("baseHash",hash),result.%Set("revision",+revision,"number")
    If revision'="" {
        Set draft=##class(Studio.Model.WorkflowDraft).%OpenId(^StudioControl("draft",revision))
        Do result.%Set("binding",##class(%DynamicObject).%FromJSON(draft.BindingJson)),result.%Set("bindingRevision",draft.BindingRevision,"number")
        If (hash=$GET(^StudioControl("baseline")))&&(hash=draft.BaseHash) {
            Do result.%Set("managed",1,"boolean"),result.%Set("readOnlyReason","")
        } Else { Do result.%Set("readOnlyReason","BPL source changed outside managed template; review required.") }
    }
    Set graph={"nodes":[{"id":"A","label":"Hemocentro A · Service"},{"id":"Decision","label":"AI Decision · BloodDecision"},{"id":"B","label":"Hemocentro B"},{"id":"C","label":"Hemocentro C"},{"id":"Review","label":"Review / fallback"}],"edges":[{"source":"A","target":"Decision"},{"source":"Decision","target":"B"},{"source":"Decision","target":"C"},{"source":"Decision","target":"Review"}]}
    Do result.%Set("graph",graph)
    Return result
}

ClassMethod Validate() As %DynamicObject
{
    Set workflow=..Workflow(),issues=[],valid=1
    If 'workflow.managed { Do issues.%Push("BPL source is not the installed managed template.") Set valid=0 }
    If 'workflow.%IsDefined("binding") { Do issues.%Push("Binding is missing.") Set valid=0 }
    If valid {
        Set binding=workflow.binding,agent=..Agent(binding.agentRef.id,binding.agentRef.revision)
        If 'agent.%IsDefined("agentId") { Do issues.%Push("Pinned agent revision does not exist.") Set valid=0 }
        If '..BindingAllowed(binding) { Do issues.%Push("Binding is incompatible with the managed BPL template.") Set valid=0 }
        If agent.%IsDefined("toolSetRefs") {
            For i=0:1:agent.toolSetRefs.%Size()-1 {
                Set class=agent.toolSetRefs.%Get(i)
                If '..ToolAllowed(class) { Do issues.%Push("ToolSet is not installed and allowlisted.") Set valid=0 }
            }
        }
    }
    Set result={"scope":"managed workflow configuration"}
    Do result.%Set("liveAIValidated",..LiveProof(),"boolean")
    Do result.%Set("valid",valid,"boolean"),result.%Set("issues",issues)
    Return result
}

ClassMethod ToolAllowed(pClass As %String) As %Boolean
{
    Return ##class(Studio.Admin.ToolRegistry).IsAllowed(pClass)
}

ClassMethod OnlyFields(pValue As %DynamicAbstractObject, pAllowed As %String) As %Boolean
{
    If '$ISOBJECT(pValue) Return 0
    If 'pValue.%IsA("%DynamicObject") Return 0
    Set iterator=pValue.%GetIterator()
    While iterator.%GetNext(.key,.value) {
        If '$FIND(","_pAllowed_",",","_key_",") Return 0
    }
    Return 1
}

ClassMethod TextAllowed(pValue As %String, pMax As %Integer, pMultiline As %Boolean = 0) As %Boolean
{
    If ($LENGTH(pValue)>pMax)!($ZSTRIP(pValue,"<>W")="") Return 0
    For i=1:1:$LENGTH(pValue) {
        Set code=$ASCII(pValue,i)
        If code=0 Return 0
        If ('pMultiline)&&(code<32) Return 0
    }
    Return 1
}

ClassMethod IdentifierAllowed(pValue As %String) As %Boolean
{
    If '..TextAllowed(pValue,128) Return 0
    Set code=$ASCII(pValue,1)
    If '(((code>=65)&&(code<=90))!((code>=97)&&(code<=122))) Return 0
    For i=1:1:$LENGTH(pValue) {
        Set char=$EXTRACT(pValue,i),code=$ASCII(char)
        If '(((code>=65)&&(code<=90))!((code>=97)&&(code<=122))!((code>=48)&&(code<=57))!$FIND("-_.:",char)) Return 0
    }
    Return 1
}

ClassMethod BindingAllowed(pBinding As %DynamicObject) As %Boolean
{
    Try {
        If '..OnlyFields(pBinding,"bindingId,agentRef,inputs,outputs,routes,fallback,timeouts") Return 0
        If pBinding.bindingId'="blood-routing:decision" Return 0
        If '..OnlyFields(pBinding.agentRef,"id,revision") Return 0
        If (pBinding.agentRef.%GetTypeOf("id")'="string")!('..IdentifierAllowed(pBinding.agentRef.id)) Return 0
        If pBinding.agentRef.%GetTypeOf("revision")'="number" Return 0
        If pBinding.agentRef.revision\1'=pBinding.agentRef.revision Return 0
        If '..OnlyFields(pBinding.routes,"B,C,REVIEW") Return 0
        If (pBinding.routes.B'="HemocentroB")!(pBinding.routes.C'="HemocentroC")!(pBinding.routes.REVIEW'="Review") Return 0
        If pBinding.routes.%Size()'=3 Return 0
        If '..OnlyFields(pBinding.fallback,"action,target") Return 0
        If (pBinding.fallback.action'="REVIEW")!(pBinding.fallback.target'="Review") Return 0
        If '..OnlyFields(pBinding.outputs,"action") Return 0
        If (pBinding.outputs.%Size()'=1)!(pBinding.outputs.action'="context.Destination") Return 0
        If 'pBinding.inputs.%IsA("%DynamicArray") Return 0
        If pBinding.inputs.%Size()'=2 Return 0
        Set first=pBinding.inputs.%Get(0),second=pBinding.inputs.%Get(1)
        If ('..OnlyFields(first,"source,target,required"))!('..OnlyFields(second,"source,target,required")) Return 0
        If (first.%GetTypeOf("required")'="boolean")!(second.%GetTypeOf("required")'="boolean") Return 0
        If (first.source'="request.BloodGroup")!(first.target'="group")!('first.required) Return 0
        If (second.source'="request.Units")!(second.target'="units")!('second.required) Return 0
        If pBinding.agentRef.revision<1 Return 0
        If pBinding.%IsDefined("timeouts") {
            If '..OnlyFields(pBinding.timeouts,"agentMs") Return 0
            If pBinding.timeouts.%GetTypeOf("agentMs")'="number" Return 0
            If pBinding.timeouts.agentMs\1'=pBinding.timeouts.agentMs Return 0
            // This managed template has a fixed 30-second Service boundary.
            If pBinding.timeouts.agentMs'=30000 Return 0
        }
    } Catch ex { Return 0 }
    Return 1
}

ClassMethod Dispatch(pAction As %String, pArgsJson As %String = "{}") As %String
{
    If '..Authorized() Return ..Error("ACCESS_DENIED","IRIS development permission in USER is required.",403)
    If $LENGTH(pArgsJson)>65536 Return ..Error("BODY_TOO_LARGE","Administrative arguments exceed limit.",413)
    If $ListFind($ListBuild("list_templates","list_productions","list_workflows","create_managed_workflow","get_workflow","save_binding","validate_workflow","preview_publish","publish_workflow","list_releases","preview_input","insert_decision_slot","rollback_workflow"),pAction) Return ##class(Studio.Admin.Workspace).Dispatch(pAction,pArgsJson)
    Try {
        Set args=##class(%DynamicObject).%FromJSON(pArgsJson)
        If 'args.%IsA("%DynamicObject") Return ..Error("INVALID_ARGS","JSON object required.")
        Set fields=$SELECT(pAction="list_workflows":"production",pAction="create_managed_workflow":"templateId,production",pAction="save_agent_revision":"agentId,definition,baseRevision",pAction="save_binding":"bindingId,payload,expectedRevision",pAction="publish_workflow":"workflowId,baseHash,revision,approvalRef,idempotencyKey",$LISTFIND($LISTBUILD("get_workflow","validate_workflow","preview_publish","list_releases"),pAction):"workflowId",1:"")
        If '..OnlyFields(args,fields) Return ..Error("INVALID_ARGS","Unknown administrative fields are not permitted.")
        Set write=$LISTFIND($LISTBUILD("create_managed_workflow","save_agent_revision","save_binding","publish_workflow"),pAction)>0
        If write {
            Lock +^StudioControl("write"):5
            If '$TEST Return ..Error("LOCK_TIMEOUT","Another administrative operation is in progress.",409)
        }
        Try { Set result=..Handle(pAction,args) }
        Catch ex { Set result=..Error("ADMIN_OPERATION_FAILED","IRIS administrative operation failed.",500) }
        If write Lock -^StudioControl("write")
    } Catch ex { Return ..Error("INVALID_ARGS","Invalid administrative arguments.") }
    Return result
}

ClassMethod Handle(pAction As %String, pArgs As %DynamicObject) As %String
{
    If pAction="list_templates" {
        // General creation templates are advertised only once their registry is installed.
        Set result=[]
        Return ..OK(result)
    }
    If pAction="detect_capabilities" {
        Set result={"namespace":"USER","sdkVerified":true,"executionEnabled":false,"nativeSimulationEnabled":true,"administrationEnabled":true}
        Set provider=$Get(^StudioSettings("provider"))
        Set ready=(provider'="")&&(+$Get(^StudioSettings("credential",provider))=1)&&($Get(^StudioSettings("model",provider))'="")
        Do result.%Set("executionEnabled",ready,"boolean"),result.%Set("liveAIValidated",##class(Studio.Admin.Settings).ConnectionVerified(),"boolean")
        Do result.%Set("version",$ZVERSION),result.%Set("principal",$USERNAME)
        Return ..OK(result)
    }
    If pAction="list_productions" {
        Set result=[]
        If ##class(%Dictionary.CompiledClass).%ExistsId("Studio.BloodDemo.Production") Do result.%Push({"name":"Studio.BloodDemo.Production","namespace":"USER"})
        Return ..OK(result)
    }
    If pAction="list_workflows" {
        If pArgs.production'="Studio.BloodDemo.Production" Return ..Error("PRODUCTION_DENIED","Production is not allowlisted.",403)
        Set result=[] Do result.%Push(..Workflow()) Return ..OK(result)
    }
    If pAction="list_agents" {
        Set result=[],key=""
        For { Set key=$ORDER(^StudioControl("agent",key)) Quit:key=""  Do result.%Push(..Agent(key,^StudioControl("agent",key,"latest"))) }
        Return ..OK(result)
    }
    If pAction="list_toolsets" {
        Return ..OK(##class(Studio.Admin.ToolRegistry).List())
    }
    If pAction="save_agent_revision" Return ..SaveAgent(pArgs)
    If pAction="save_binding" Return ..SaveBinding(pArgs)
    If pAction="create_managed_workflow" {
        If (pArgs.templateId'="event-routing")!(pArgs.production'="Studio.BloodDemo.Production") Return ..Error("TEMPLATE_DENIED","Only the installed managed template is supported.")
        If '$DATA(^StudioControl("draft","latest")) Return ..Error("TEMPLATE_NOT_INITIALIZED","Bootstrap the managed example before creating a draft.",409)
        Return ..OK(..Workflow())
    }
    If pArgs.workflowId'="blood-routing" Return ..Error("WORKFLOW_NOT_FOUND","Workflow is not allowlisted.",404)
    If pAction="get_workflow" Return ..OK(..Workflow())
    If pAction="validate_workflow" Return ..OK(..Validate())
    If pAction="preview_publish" {
        Set workflow=..Workflow(),validation=..Validate(),result={"scope":"configuration publication; BPL source unchanged","diff":"BPL source unchanged. Publish the current binding and pinned agent revision as an immutable manifest."}
        Do result.%Set("baseHash",workflow.baseHash),result.%Set("revision",workflow.revision,"number"),result.%Set("validation",validation)
        Return ..OK(result)
    }
    If pAction="publish_workflow" Return ..Publish(pArgs)
    If pAction="list_releases" {
        Set result=[],key=""
        For {
            Set key=$ORDER(^StudioControl("release",key))
            Quit:key=""
            Set release=##class(Studio.Model.WorkflowRelease).%OpenId(^StudioControl("release",key))
            If $ISOBJECT(release),release.WorkflowId="blood-routing" Do result.%Push(##class(%DynamicObject).%FromJSON(release.ManifestJson))
        }
        Return ..OK(result)
    }
    Return ..Error("ACTION_NOT_SUPPORTED","Administrative action is not supported.",501)
}

ClassMethod SaveAgent(pArgs As %DynamicObject) As %String
{
    If (pArgs.%GetTypeOf("agentId")'="string")!('..IdentifierAllowed(pArgs.agentId)) Return ..Error("INVALID_AGENT","A bounded agent identifier is required.")
    If (pArgs.%GetTypeOf("baseRevision")'="number") Return ..Error("INVALID_REVISION","A nonnegative integer revision is required.")
    If (pArgs.baseRevision<0)!(pArgs.baseRevision\1'=pArgs.baseRevision) Return ..Error("INVALID_REVISION","A nonnegative integer revision is required.")
    Set id=pArgs.agentId,definition=pArgs.definition,base=+$GET(^StudioControl("agent",id,"latest"))
    If base'=pArgs.baseRevision Return ..Error("AGENT_REVISION_CONFLICT","Agent revision changed.",409)
    If '..OnlyFields(definition,"providerRef,modelName,prompt,toolSetRefs") Return ..Error("INVALID_AGENT","Unknown agent fields are not permitted; credentials belong in the provider store.")
    If (definition.%GetTypeOf("providerRef")'="string")!(definition.%GetTypeOf("modelName")'="string")!(definition.%GetTypeOf("prompt")'="string") Return ..Error("INVALID_AGENT","Provider, model and prompt must be strings.")
    If (definition.providerRef'="openai")&&(definition.providerRef'="anthropic") Return ..Error("PROVIDER_NOT_SUPPORTED","Only openai and anthropic provider references are supported.")
    If ('..TextAllowed(definition.modelName,128))!('..TextAllowed(definition.prompt,16384,1)) Return ..Error("INVALID_AGENT","A bounded model name and nonempty prompt up to 16384 characters are required.")
    If '$ISOBJECT(definition.toolSetRefs) Return ..Error("INVALID_TOOLS","At least one installed READ ToolSet is required.")
    Set tools=definition.toolSetRefs
    If 'tools.%IsA("%DynamicArray") Return ..Error("INVALID_TOOLS","Tool references must be an array.")
    If (tools.%Size()<1)!(tools.%Size()>40) Return ..Error("INVALID_TOOLS","At least one and at most 40 READ ToolSets are required.")
    For i=0:1:tools.%Size()-1 {
        If tools.%GetTypeOf(i)'="string" Return ..Error("INVALID_TOOLS","Tool references must be class-name strings.")
        Set tool=tools.%Get(i)
        If '..ToolAllowed(tool) Return ..Error("TOOL_DENIED","ToolSet is not installed and allowlisted.",403)
        If $DATA(seen(tool)) Return ..Error("INVALID_TOOLS","Duplicate ToolSets are not permitted.")
        Set seen(tool)=1
    }
    Set agent=##class(Studio.Model.AgentDefinition).%New()
    Set agent.AgentId=id,agent.Revision=base+1,agent.ProviderRef=definition.providerRef,agent.ModelName=definition.modelName,agent.Prompt=definition.prompt,agent.ToolSetRefsJson=tools.%ToJSON()
    TSTART
    Set sc=agent.%Save()
    If $$$ISERR(sc) {
        TROLLBACK
        Return ..Error("AGENT_SAVE_FAILED","Agent revision could not be persisted.")
    }
    Set ^StudioControl("agent",id,base+1)=agent.%Id(),^StudioControl("agent",id,"latest")=base+1
    TCOMMIT
    Return ..OK(..Agent(id,base+1))
}

ClassMethod SaveBinding(pArgs As %DynamicObject) As %String
{
    If pArgs.%GetTypeOf("expectedRevision")'="number" Return ..Error("INVALID_REVISION","Expected revision must be an integer.")
    If (pArgs.expectedRevision<0)!(pArgs.expectedRevision\1'=pArgs.expectedRevision) Return ..Error("INVALID_REVISION","Expected revision must be a nonnegative integer.")
    If (pArgs.bindingId'="blood-routing:decision")!('..BindingAllowed(pArgs.payload)) Return ..Error("BINDING_NOT_MANAGED","Binding does not match the managed BPL contract.")
    Set current=+$GET(^StudioControl("draft","latest"))
    If current=0 Return ..Error("DRAFT_MISSING","Managed draft is not initialized.",409)
    Set old=##class(Studio.Model.WorkflowDraft).%OpenId(^StudioControl("draft",current))
    If old.BindingRevision'=pArgs.expectedRevision Return ..Error("BINDING_REVISION_CONFLICT","Binding revision changed.",409)
    Set workflow=..Workflow()
    If 'workflow.managed Return ..Error("BPL_SOURCE_CONFLICT","BPL changed outside the managed template.",409)
    Set agent=..Agent(pArgs.payload.agentRef.id,pArgs.payload.agentRef.revision)
    If 'agent.%IsDefined("agentId") Return ..Error("AGENT_NOT_FOUND","Pinned agent revision does not exist.")
    Set draft=##class(Studio.Model.WorkflowDraft).%New()
    Set draft.WorkflowId="blood-routing",draft.Revision=current+1,draft.BaseHash=old.BaseHash,draft.BindingJson=pArgs.payload.%ToJSON(),draft.BindingRevision=old.BindingRevision+1,draft.CreatedBy=$USERNAME
    TSTART
    Set sc=draft.%Save()
    If $$$ISERR(sc) {
        TROLLBACK
        Return ..Error("DRAFT_SAVE_FAILED","Draft revision could not be persisted.")
    }
    Set ^StudioControl("draft",current+1)=draft.%Id(),^StudioControl("draft","latest")=current+1
    TCOMMIT
    Return ..OK(..Workflow())
}

ClassMethod Publish(pArgs As %DynamicObject) As %String
{
    If (pArgs.approvalRef="")!(pArgs.idempotencyKey="")!($LENGTH(pArgs.idempotencyKey)>128) Return ..Error("APPROVAL_REQUIRED","Approval and bounded idempotency identifiers are required.")
    Set fingerprint=..Hash(pArgs.workflowId_"|"_pArgs.baseHash_"|"_pArgs.revision_"|"_pArgs.approvalRef)
    If $DATA(^StudioControl("idempotency",pArgs.idempotencyKey)) {
        If ^StudioControl("idempotency",pArgs.idempotencyKey,"hash")'=fingerprint Return ..Error("IDEMPOTENCY_CONFLICT","Idempotency key was used for a different publication.",409)
        Return ..OK(##class(%DynamicObject).%FromJSON(^StudioControl("idempotency",pArgs.idempotencyKey)))
    }
    Set workflow=..Workflow(),validation=..Validate()
    If 'validation.valid Return ..Error("WORKFLOW_INVALID","Managed workflow validation failed.")
    If (pArgs.baseHash'=workflow.baseHash)!(pArgs.revision'=workflow.revision) Return ..Error("BPL_SOURCE_CONFLICT","Draft revision or BPL source changed.",409)
    If $DATA(^StudioControl("releaseRevision",workflow.revision)) Return ..Error("REVISION_ALREADY_PUBLISHED","This immutable workflow revision already has a release.",409)
    Set stage="Studio.Stage.BloodRoutingR"_workflow.revision
    Set stream=##class(%Stream.FileCharacter).%New(),stream.Filename="/tmp/"_stage_".cls"
    Do stream.WriteLine("Class "_stage_" Extends Ens.BusinessProcessBPL"),stream.WriteLine("{")
    Do stream.WriteLine("XData BPL [ XMLNamespace = ""http://www.intersystems.com/bpl"" ]"),stream.WriteLine("{")
    Do stream.WriteLine(workflow.source),stream.WriteLine("}"),stream.WriteLine("}")
    Set sc=stream.%Save()
    If $$$ISERR(sc) Return ..Error("STAGE_FAILED","Cannot stage managed BPL.")
    Set sc=$SYSTEM.OBJ.Load(stream.Filename,"ck")
    If $$$ISERR(sc) Return ..Error("STAGED_COMPILE_FAILED","Staged BPL compilation failed.")
    If ..Hash(..Source())'=workflow.baseHash Return ..Error("BPL_SOURCE_CONFLICT","BPL source changed during staging.",409)
    Set sc=$SYSTEM.OBJ.Compile("Studio.BloodDemo.Routing","ck")
    If $$$ISERR(sc) Return ..Error("BPL_COMPILE_FAILED","Managed BPL compilation failed.")
    Set releaseId=$SYSTEM.Util.CreateGUID(),binding=workflow.binding,agent=..Agent(binding.agentRef.id,binding.agentRef.revision)
    Set manifest={"compiled":true,"published":true,"activated":false,"scope":"configuration","workflowId":"blood-routing","compiledBPLClass":"Studio.BloodDemo.Routing","liveAIValidated":false}
    Do manifest.%Set("releaseId",releaseId),manifest.%Set("revision",workflow.revision,"number"),manifest.%Set("baseHash",workflow.baseHash),manifest.%Set("stagedClass",stage)
    Do manifest.%Set("binding",binding),manifest.%Set("agent",agent),manifest.%Set("publishedBy",$USERNAME),manifest.%Set("publishedAt",$ZDATETIME($HOROLOG,3))
    Set release=##class(Studio.Model.WorkflowRelease).%New()
    Set release.ReleaseId=releaseId,release.WorkflowId="blood-routing",release.Revision=workflow.revision,release.SourceHash=workflow.baseHash,release.BPLClass="Studio.BloodDemo.Routing",release.ManifestJson=manifest.%ToJSON(),release.PublishedBy=$USERNAME,release.PublishedAt=$ZDATETIME($HOROLOG,3)
    TSTART
    Set sc=release.%Save()
    If $$$ISERR(sc) {
        TROLLBACK
        Return ..Error("RELEASE_SAVE_FAILED","Immutable release could not be persisted.")
    }
    Set ^StudioControl("release",releaseId)=release.%Id(),^StudioControl("releaseRevision",workflow.revision)=releaseId,^StudioControl("activeRelease","blood-routing")=releaseId
    Set ^StudioControl("idempotency",pArgs.idempotencyKey)=manifest.%ToJSON(),^StudioControl("idempotency",pArgs.idempotencyKey,"hash")=fingerprint
    TCOMMIT
    Return ..OK(manifest)
}
}
