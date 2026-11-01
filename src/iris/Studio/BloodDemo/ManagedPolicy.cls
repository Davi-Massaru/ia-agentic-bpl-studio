Include %occStatus
/// Embedded Python enforces inventory policy and observed tool use.
Class Studio.BloodDemo.ManagedPolicy Extends %RegisteredObject
{
ClassMethod Validate(pInput As %DynamicObject, pRaw As %String, pMode As %String, pExecution As %String) As %Status [ Language = python ]
{
    import iris
    iris.cls('Studio.Runtime.Python').Prepare()
    from studio.native.agent_runtime import stock_policy
    return stock_policy(pInput, pRaw, pMode, pExecution)
}
}
