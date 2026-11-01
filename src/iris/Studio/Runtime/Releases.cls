Include %occStatus
Class Studio.Runtime.Releases Extends %RegisteredObject
{
ClassMethod Manifest(pReleaseId As %String) As %DynamicObject
{
    If ##class(%Dictionary.CompiledClass).%ExistsId("Studio.Admin.Workspace") {
        Set manifest=$ClassMethod("Studio.Admin.Workspace","ReleaseManifest",pReleaseId)
        If manifest.%IsDefined("releaseId") Return manifest
    }
    Return ##class(Studio.Admin.ControlPlane).ReleaseManifest(pReleaseId)
}
ClassMethod Binding(pManifest As %DynamicObject, pId As %String = "") As %DynamicObject
{
    If pId="" Return pManifest.binding
    If pManifest.%IsDefined("bindings") {
        For i=0:1:pManifest.bindings.%Size()-1 {
            Set binding=pManifest.bindings.%Get(i)
            If binding.bindingId=pId Return binding
        }
        Return {}
    }
    If pManifest.binding.bindingId=pId Return pManifest.binding
    Return {}
}
ClassMethod Agent(pManifest As %DynamicObject, pId As %String) As %DynamicObject
{
    If pManifest.%IsDefined("agents") Return pManifest.agents.%Get(pId)
    Return pManifest.agent
}
ClassMethod Compatible(pManifest As %DynamicObject) As %Boolean
{
    Try {
        If 'pManifest.%IsDefined("compiledBPLClass") Return 0
        Set source=##class(Studio.Admin.BPLReader).Source(pManifest.compiledBPLClass)
        Return (source'="")&&(##class(Studio.Admin.ControlPlane).Hash(source)=pManifest.baseHash)
    } Catch ex { Return 0 }
}
/// Simulation is confined to installed local sinks in the running demo Production.
ClassMethod SimulationAllowed(pManifest As %DynamicObject) As %Boolean
{
    Try {
        If (pManifest.production'="Studio.Demo.Production")&&(pManifest.production'="Studio.BloodDemo.Production") Return 0
        If ##class(Ens.Director).GetActiveProductionName()'=pManifest.production Return 0
        Set items=##class(%DynamicArray).%FromJSON(##class(Studio.Admin.BPLReader).ProductionItems(pManifest.production))
        For i=0:1:items.%Size()-1 {
            Set item=items.%Get(i)
            If item.className="Studio.Demo.AcknowledgeOperation",item.enabled Set targets(item.name)=1
        }
        Set bindings=[]
        If pManifest.%IsDefined("bindings") { Set bindings=pManifest.bindings } Else { Do bindings.%Push(pManifest.binding) }
        For j=0:1:bindings.%Size()-1 {
        Set binding=bindings.%Get(j)
        If '$Data(targets(binding.fallback.target)) Return 0
        Set iterator=binding.routes.%GetIterator()
        While iterator.%GetNext(.action,.target) {
            If '$Data(targets(target)) Return 0
        }
        }
        Return 1
    } Catch ex { Return 0 }
}
}
