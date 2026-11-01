Include %occStatus
/// Test ingress for published managed workflows; resolves the immutable release's host.
Class Studio.Interop.WorkflowService Extends Ens.BusinessService
{
Method OnProcessInput(pInput As Studio.Msg.WorkflowRequest, Output pOutput As Studio.Msg.WorkflowResponse) As %Status
{
    Set manifest=##class(Studio.Runtime.Releases).Manifest(pInput.ReleaseId)
    If 'manifest.%IsDefined("hostName") Return $$$ERROR($$$GeneralError,"PUBLISHED_HOST_REQUIRED")
    If '##class(Studio.Runtime.Releases).Compatible(manifest) Return $$$ERROR($$$GeneralError,"RELEASE_SOURCE_CONFLICT")
    If pInput.%ClassName(1)'=manifest.requestClass Return $$$ERROR($$$GeneralError,"REQUEST_CLASS_MISMATCH")
    If ##class(Ens.Director).GetActiveProductionName()'=manifest.production Return $$$ERROR($$$GeneralError,"PRODUCTION_MISMATCH")
    If pInput.Mode="SIMULATION",'##class(Studio.Runtime.Releases).SimulationAllowed(manifest) Return $$$ERROR($$$GeneralError,"SIMULATION_DENIED")
    If (pInput.Mode'="LIVE")&&(pInput.Mode'="SIMULATION") Return $$$ERROR($$$GeneralError,"MODE_INVALID")
    If pInput.Mode="LIVE",(pInput.CandidateJson'="")!(pInput.SimulationFault'="") Return $$$ERROR($$$GeneralError,"FIXTURES_REQUIRE_SIMULATION")
    If (pInput.EventId="")!(pInput.CorrelationId="") Return $$$ERROR($$$GeneralError,"REQUEST_FIELDS_REQUIRED")
    Set ^StudioAudit(pInput.CorrelationId,"service")=..%ConfigName
    Set ^StudioAudit(pInput.CorrelationId,"bplHost")=manifest.hostName
    // The generated BPL timer bounds the decision wait; allow time for deterministic fallback.
    Set decisionMs=manifest.binding.timeouts.agentMs
    If manifest.%IsDefined("bindings") {
        Set decisionMs=0
        For i=0:1:manifest.bindings.%Size()-1 {
            Set timeout=manifest.bindings.%Get(i).timeouts.agentMs
            If (timeout<100)!(timeout>300000) Return $$$ERROR($$$GeneralError,"DECISION_TIMEOUT_INVALID")
            Set decisionMs=decisionMs+timeout
        }
    }
    If (decisionMs<100)!(decisionMs>2400000) Return $$$ERROR($$$GeneralError,"DECISION_TIMEOUT_INVALID")
    Return ..SendRequestSync(manifest.hostName,pInput,.pOutput,(decisionMs/1000)+30)
}
}
