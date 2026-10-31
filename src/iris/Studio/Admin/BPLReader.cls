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
            Set source=data.Data.Read(100000)
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
    import json,xml.etree.ElementTree as ET
    if '<!' in pSource: return json.dumps({'recognized':False,'reason':'DTD and entity declarations are not supported.','nodes':[],'edges':[]})
    try:
        root=ET.fromstring(pSource)
    except ET.ParseError:
        return json.dumps({'recognized':False,'reason':'Invalid BPL XML.','nodes':[],'edges':[]})
    nodes=[];edges=[]
    def tag(node):
        return node.tag.rsplit('}',1)[-1]
    def activity(node, parent=None, kind=None, label=None):
        key='activity-'+str(len(nodes))
        item={'id':key,'label':label or node.get('name') or tag(node),
              'kind':kind or tag(node),'target':node.get('target','')}
        if parent: item['parentId']=parent
        if node.get('property'): item['property']=node.get('property')
        if node.get('condition'): item['condition']=node.get('condition')
        nodes.append(item)
        return key
    def edge(source, target, label='', kind='flow'):
        item={'source':source,'target':target,'kind':kind}
        if label: item['label']=label
        edges.append(item)
    def sequence(children, parent=None):
        entry=None;exits=[]
        for child in children:
            if tag(child) in {'context','property','parameters','parameter'}: continue
            first,last=walk(child,parent)
            if not first: continue
            if entry is None: entry=first
            for previous in exits: edge(previous,first)
            exits=last
        return entry,exits
    def walk(node, parent=None):
        kind=tag(node)
        if kind in {'process','sequence'}: return sequence(list(node),parent)
        key=activity(node,parent)
        if kind=='switch':
            branches=[child for child in node if tag(child) in {'case','default'}]
            branch_exits=[]
            for branch in branches:
                label=branch.get('condition','') if tag(branch)=='case' else 'default / fallback'
                branch_key=activity(branch,key,label=tag(branch))
                edge(key,branch_key,label or 'case')
                first,last=sequence(list(branch),branch_key)
                if first: edge(branch_key,first)
                branch_exits.extend(last or [branch_key])
            # Explicit merge joins branch exits; cases never flow into each other.
            merge=activity(node,parent,kind='merge',label='Switch exit')
            for previous in branch_exits: edge(previous,merge,'branch exit')
            if not any(tag(branch)=='default' for branch in branches): edge(key,merge,'no matching case')
            return key,[merge]
        if kind=='call':
            # Request/response assignments belong to the call, not to the outer
            # process sequence. Containment edges are distinct from control flow.
            for child in node:
                if tag(child) not in {'request','response'}: continue
                scope=activity(child,key,label=tag(child)+' mapping')
                edge(key,scope,tag(child),'contains')
                first,last=sequence(list(child),scope)
                if first: edge(scope,first,'mapping','contains')
            return key,[key]
        if kind=='scope':
            first,last=sequence(list(node),key)
            if first: edge(key,first)
            return key,last or [key]
        return key,[key]
    walk(root)
    return json.dumps({'recognized':False,'reason':'Read-only until registered as a managed Studio template.',
                       'requestClass':root.get('request',''),'responseClass':root.get('response',''),
                       'nodes':nodes,'edges':edges})
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
