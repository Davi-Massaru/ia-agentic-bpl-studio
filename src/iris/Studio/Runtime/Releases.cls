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
        If '$Data(targets(pManifest.binding.fallback.target)) Return 0
        Set iterator=pManifest.binding.routes.%GetIterator()
        While iterator.%GetNext(.action,.target) {
            If '$Data(targets(target)) Return 0
        }
        Return 1
    } Catch ex { Return 0 }
}
}
