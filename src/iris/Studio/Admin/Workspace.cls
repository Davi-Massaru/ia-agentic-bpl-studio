Include %occStatus
/// Native administrative registry. Only generated, hash-verified template classes are editable.
Class Studio.Admin.Workspace Extends %RegisteredObject
{
ClassMethod Read(pKey As %String) As %String
{
    Return $Get(^StudioWorkspace(pKey))
}
/// Dictionary's supported class query avoids SELECT grants on protected system SQL tables.
ClassMethod Productions() As %String
{
    If '##class(Studio.Admin.ControlPlane).Authorized() Return "[]"
    Set result=[],query=##class(%ResultSet).%New("%Dictionary.ClassDefinition:Summary")
    Set sc=query.Execute()
    If $$$ISERR(sc) Return "[]"
    While query.Next() {
        Set name=query.Get("Name"),super=query.Get("Super")
        If $ListFind($ListFromString(super),"Ens.Production") {
            If ##class(Studio.Admin.BPLReader).Source(name,"ProductionDefinition")'="" {
                Set item={"namespace":"USER"}
                Do item.%Set("name",name),result.%Push(item)
            }
        }
    }
    Return result.%ToJSON()
}
ClassMethod Write(pKey As %String, pValue As %String)
{
    Set ^StudioWorkspace(pKey)=pValue
}
ClassMethod ReleaseManifest(pId As %String) As %DynamicObject
{
    If '##class(Studio.Admin.ControlPlane).Authorized() Return {}
    Set data=..Read("release:"_pId)
    If data="" Return {}
    Return ##class(%DynamicObject).%FromJSON(data)
}
ClassMethod Stage(pClass As %String, pXML As %String) As %Status
{
    Set stream=##class(%Stream.FileCharacter).%New(),stream.Filename="/tmp/"_pClass_".cls"
    Do stream.WriteLine("Class "_pClass_" Extends Ens.BusinessProcessBPL"),stream.WriteLine("{")
    Do stream.WriteLine("XData BPL [ XMLNamespace = ""http://www.intersystems.com/bpl"" ]"),stream.WriteLine("{")
    Do stream.WriteLine(pXML),stream.WriteLine("}"),stream.WriteLine("}")
    Set sc=stream.%Save()
    If $$$ISERR(sc) Return sc
    Return $SYSTEM.OBJ.Load(stream.Filename,"ck-d")
}
/// Only generated hexadecimal IDs enter the class source; all agent data stays in the registry.
ClassMethod StageComponent(pId As %String) As %Status
{
    If pId'?32AN Return $$$ERROR($$$GeneralError,"COMPONENT_ID_INVALID")
    Set stream=##class(%Stream.FileCharacter).%New(),stream.Filename="/tmp/StudioAgent"_pId_".cls"
    Do stream.WriteLine("Class Studio.Components.A"_pId_" Extends Studio.Interop.PortableAgentOperation")
    Do stream.WriteLine("{"),stream.WriteLine("Property ComponentId As %String(MAXLEN=128) [ InitialExpression="""_pId_""" ];"),stream.WriteLine("}")
    Set sc=stream.%Save()
    If $$$ISERR(sc) Return sc
    Return $SYSTEM.OBJ.Load(stream.Filename,"ck-d")
}
ClassMethod Install(pProduction As %String, pHost As %String, pClass As %String) As %String
{
    Set result={"installed":false,"activated":false}
    Set production=##class(Ens.Config.Production).%OpenId(pProduction)
    If '$IsObject(production) Return result.%ToJSON()
    Set key="",found=0
    For {
        Set item=production.Items.GetNext(.key)
        Quit:key=""
        If item.Name=pHost { Set found=1 Quit }
    }
    If 'found {
        Set item=##class(Ens.Config.Item).%New(pClass),item.Name=pHost,item.Enabled=1,item.PoolSize=1
        Do production.Items.Insert(item)
    } Else {
        // Reconciliation may reuse the exact generated host, never replace an unrelated host.
        If item.ClassName'=pClass Return result.%ToJSON()
    }
    Set sc=production.%Save()
    If $$$ISERR(sc) Return result.%ToJSON()
    Set sc=production.SaveToClass(item)
    If $$$ISERR(sc) Return result.%ToJSON()
    Set sc=$SYSTEM.OBJ.Compile(pProduction,"ck-d")
    If $$$ISERR(sc) Return result.%ToJSON()
    Do result.%Set("installed",1,"boolean")
    Set sc=##class(Ens.Director).GetProductionStatus(.running,.state)
    If $$$ISOK(sc),running=pProduction,state=1 {
        Set sc=..QuietUpdate()
        If $$$ISOK(sc) Do result.%Set("activated",1,"boolean")
    }
    Return result.%ToJSON()
}
/// Native Director also emits foreground log text; keep it out of HTTP JSON responses.
ClassMethod QuietUpdate() As %Status
{
    Set previousDevice=$IO
    Open "/dev/null":("WNS"):2
    If '$Test Return $$$ERROR($$$GeneralError,"OUTPUT_DEVICE_UNAVAILABLE")
    Use "/dev/null"
    Try { Set sc=##class(Ens.Director).UpdateProduction(20) }
    Catch ex { Set sc=ex.AsStatus() }
    Use previousDevice
    Close "/dev/null"
    Return sc
}
ClassMethod Dispatch(pAction As %String, pArgs As %String) As %String
{
    If '##class(Studio.Admin.ControlPlane).Authorized() Return ##class(Studio.Admin.ControlPlane).Error("ACCESS_DENIED","Development permission required.",403)
    Lock +^StudioWorkspace("write"):10
    If '$Test Return ##class(Studio.Admin.ControlPlane).Error("LOCK_TIMEOUT","Workspace is busy.",409)
    Try { Set result=..Invoke(pAction,pArgs) }
    Catch ex { Set result=##class(Studio.Admin.ControlPlane).Error("WORKSPACE_FAILED","Native workspace operation failed.",500) }
    Lock -^StudioWorkspace("write")
    Return result
}
ClassMethod Invoke(pAction As %String, pArgs As %String) As %String [ Language = python ]
{
    import sys
    if '/durable/studio-python' not in sys.path: sys.path.insert(0,'/durable/studio-python')
    if '/opt/studio/backend' not in sys.path: sys.path.insert(0,'/opt/studio/backend')
    from studio.native.workspace import dispatch
    return dispatch(pAction,pArgs)
}
ClassMethod ReconcileDeployments() As %String
{
    If '##class(Studio.Admin.ControlPlane).Authorized() Return "[]"
    Lock +^StudioWorkspace("write"):10
    If '$Test Return "[]"
    Try { Set result=..ReconcileNative() }
    Catch ex { Set result="[]" }
    Lock -^StudioWorkspace("write")
    Return result
}
ClassMethod ReconcileNative() As %String [ Language = python ]
{
    import sys
    for path in ['/durable/studio-python','/opt/studio/backend']:
        if path not in sys.path: sys.path.insert(0,path)
    from studio.native.workspace import reconcile
    return reconcile()
}
}
