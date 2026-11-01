Include %occStatus
/// Narrow native boundaries: module loading, status construction and process-private context.
Class Studio.Runtime.Python Extends %RegisteredObject
{
ClassMethod Prepare() [ Language = python ]
{
    import sys
    for path in ['/durable/studio-python', '/opt/studio/backend']:
        if path not in sys.path:
            sys.path.insert(0, path)
}
ClassMethod Error(pCode As %String) As %Status
{
    Return $$$ERROR($$$GeneralError,pCode)
}
}
