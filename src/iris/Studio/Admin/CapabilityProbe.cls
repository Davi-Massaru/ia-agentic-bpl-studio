/// Read-only, bounded inventory. Class presence is never SDK compatibility evidence.
Class Studio.Admin.CapabilityProbe Extends %RegisteredObject
{
ClassMethod Inspect() As %DynamicObject
{
    Set report = {}, classes = []
    Do report.%Set("version",$ZVERSION)
    Do report.%Set("namespace",$NAMESPACE)
    Do report.%Set("sdkVerified",0,"boolean")
    Do report.%Set("executionEnabled",0,"boolean")
    Do report.%Set("classes",classes)
    Set names = $LISTBUILD("%AI.Agent","%AI.Provider","%AI.Agent.Session","%AI.LLM.Response","%AI.ToolSet","%AI.ToolMgr","Ens.BusinessProcessBPL","Ens.BusinessOperation")
    For i = 1:1:$LISTLENGTH(names) {
        Set name = $LISTGET(names,i), entry = {}, methods = []
        Do entry.%Set("name",name)
        Do entry.%Set("methods",methods)
        Try {
            Set definition = ##class(%Dictionary.CompiledClass).%OpenId(name)
            Do entry.%Set("present",$ISOBJECT(definition),"boolean")
            If $ISOBJECT(definition) {
                Set key = "", count = 0
                For {
                    Set method = definition.Methods.GetNext(.key)
                    Quit:key=""
                    Set count = count + 1
                    Quit:count>300
                    Set item = {}
                    Do item.%Set("name",method.Name)
                    Do item.%Set("formalSpec",method.FormalSpec)
                    Do item.%Set("returnType",method.ReturnType)
                    Do methods.%Push(item)
                }
                Do entry.%Set("truncated",count>300,"boolean")
            }
        } Catch ex {
            Do entry.%Set("inspectionError","DICTIONARY_READ_FAILED")
        }
        Do classes.%Push(entry)
    }
    Return report
}
}

