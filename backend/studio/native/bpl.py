"""Read-only BPL projection. Unknown activities are opaque, never inferred."""

def parse(pSource):
    import json,xml.etree.ElementTree as ET
    def rejected(reason):
        return json.dumps({'recognized': False, 'reason': reason, 'nodes': [], 'edges': []})
    if len(pSource) > 1000000 or pSource == '<source-too-large/>':
        return rejected('BPL exceeds the 1000000-character inspection limit; editing is blocked.')
    if '<!' in pSource: return json.dumps({'recognized':False,'reason':'DTD and entity declarations are not supported.','nodes':[],'edges':[]})
    try:
        root=ET.fromstring(pSource)
    except ET.ParseError:
        return json.dumps({'recognized':False,'reason':'Invalid BPL XML.','nodes':[],'edges':[]})
    pending, count = [(root, 0)], 0
    while pending:
        element, depth = pending.pop()
        count += 1
        if depth > 64 or count > 10000:
            return rejected('BPL exceeds supported inspection depth or activity count; editing is blocked.')
        pending.extend((child, depth + 1) for child in element)
    nodes=[];edges=[]
    supported={'process','sequence','switch','case','default','call','request','response','scope','assign','if','true','false'}
    def tag(node):
        return node.tag.rsplit('}',1)[-1]
    def activity(node, parent=None, kind=None, label=None):
        key='activity-'+str(len(nodes))
        item={'id':key,'label':label or node.get('name') or tag(node),
              'kind':kind or tag(node),'target':node.get('target',''), 'opaque':tag(node) not in supported}
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
        if kind in {'switch','if'}:
            branches=[child for child in node if tag(child) in {'case','default','true','false'}]
            branch_exits=[]
            for branch in branches:
                label=branch.get('condition','') if tag(branch)=='case' else tag(branch)
                branch_key=activity(branch,key,label=tag(branch))
                edge(key,branch_key,label or 'case')
                first,last=sequence(list(branch),branch_key)
                if first: edge(branch_key,first)
                branch_exits.extend(last or [branch_key])
            # Explicit merge joins branch exits; cases never flow into each other.
            merge=activity(node,parent,kind='merge',label=kind + ' exit')
            for previous in branch_exits: edge(previous,merge,'branch exit')
            if not any(tag(branch) in {'default','false'} for branch in branches): edge(key,merge,'no matching case')
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
    if tag(root) != 'process': return json.dumps({'recognized':False,'reason':'Expected BPL process.','nodes':[],'edges':[]})
    walk(root)
    return json.dumps({'recognized':False,'reason':'Read-only until registered as a managed Studio template.',
                       'requestClass':root.get('request',''),'responseClass':root.get('response',''),
                       'nodes':nodes,'edges':edges})
