/// Read-only Dictionary inventory. Unknown source is never silently managed.
Class Studio.Admin.BPLReader Extends %RegisteredObject
{
ClassMethod Source(pClass As %String, pName As %String = "BPL") As %String
{
    Set definition=##class(%Dictionary.ClassDefinition).%OpenId(pClass)
    If '$IsObject(definition) Return ""
    Set key="",source=""
    For {
        Set data=definition.XDatas.GetNext(.key)
        Quit:key=""
        If data.Name=pName {
            Do data.Data.Rewind()
            While 'data.Data.AtEnd {
                If $Length(source)>1000000 Return "<source-too-large/>"
                Set source=source_data.Data.Read(32000)
            }
            Quit
        }
    }
    Return source
}
ClassMethod Properties(pClass As %String) As %DynamicArray
{
    Set result=[],definition=##class(%Dictionary.CompiledClass).%OpenId(pClass)
    If '$IsObject(definition) Return result
    Set key=""
    For {
        Set property=definition.Properties.GetNext(.key)
        Quit:key=""
        If $Extract(property.Name,1)'="%" {
            Set item={}
            Do item.%Set("name",property.Name),item.%Set("type",property.Type)
            Do result.%Push(item)
        }
    }
    Return result
}
ClassMethod ProductionItems(pClass As %String) As %String [ Language = python ]
{
    import iris,json,xml.etree.ElementTree as ET
    source=str(iris.cls('Studio.Admin.BPLReader').Source(pClass,'ProductionDefinition'))
    if not source or '<!' in source: return '[]'
    try:
        root=ET.fromstring(source)
        return json.dumps([{'name':n.get('Name',''),'className':n.get('ClassName',''),
                           'enabled':n.get('Enabled','true').lower()=='true'}
                          for n in root.findall('Item')])
    except ET.ParseError: return '[]'
}
ClassMethod Parse(pSource As %String) As %String [ Language = python ]
{
    import iris
    iris.cls('Studio.Runtime.Python').Prepare()
    from studio.native.bpl import parse
    return parse(pSource)
}
ClassMethod ReadDefinition(pClass As %String) As %DynamicObject
{
    Set source=..Source(pClass),parsed=##class(%DynamicObject).%FromJSON(..Parse(source)),result={"managed":false}
    Do result.%Set("workflowId","class:"_pClass),result.%Set("className",pClass),result.%Set("source",source)
    Do result.%Set("baseHash",##class(Studio.Admin.ControlPlane).Hash(source)),result.%Set("readOnlyReason",parsed.%Get("reason"))
    Do result.%Set("graph",parsed),result.%Set("requestClass",parsed.%Get("requestClass"))
    Do result.%Set("requestProperties",..Properties(parsed.%Get("requestClass")))
    Return result
}
}
