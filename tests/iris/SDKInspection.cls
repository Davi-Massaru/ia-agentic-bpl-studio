/// Development-only inspection of installed method signatures; never reads secret values.
Class Studio.Tests.SDKInspection Extends %RegisteredObject
{
ClassMethod Methods(pClass As %String) As %String
{
    Set result=[],definition=##class(%Dictionary.ClassDefinition).%OpenId(pClass),key=""
    If '$IsObject(definition) Return "[]"
    For {
        Set method=definition.Methods.GetNext(.key)
        Quit:key=""
        Set item={}
        Do item.%Set("method",method.Name),item.%Set("signature",method.FormalSpec),result.%Push(item)
    }
    Return result.%ToJSON()
}
ClassMethod ConfigClasses() As %String
{
    Set result=[],query=##class(%ResultSet).%New("%Dictionary.ClassDefinition:Summary")
    Set sc=query.Execute()
    While query.Next() {
        Set name=query.Get("Name")
        If (name["LLM")!(name["Descriptor")!(name["AI.Config") Do result.%Push(name)
    }
    Return result.%ToJSON()
}
ClassMethod Source(pClass As %String, pMethod As %String) As %String
{
    Set definition=##class(%Dictionary.ClassDefinition).%OpenId(pClass),key=""
    If '$IsObject(definition) Return "CLASS_NOT_FOUND"
    For {
        Set method=definition.Methods.GetNext(.key)
        Quit:key=""
        If method.Name=pMethod {
            Do method.Implementation.Rewind()
            Return method.Implementation.Read(30000)
        }
    }
    Return "SUPER="_definition.Super
}
ClassMethod Signatures() As %String
{
    Set result=[],classes=$ListBuild("%Wallet.Collection","%Wallet.KeyValue","%ConfigStore.Configuration","%AI.Provider","%AI.Agent","%AI.Agent.Session")
    For i=1:1:$ListLength(classes) {
        Set definition=##class(%Dictionary.ClassDefinition).%OpenId($ListGet(classes,i)),key=""
        For {
            Set method=definition.Methods.GetNext(.key)
            Quit:key=""
            If $ListFind($ListBuild("Create","UpdateSecret","Exists","Modify","GetDetails","Chat","CreateSession","UseToolSet","GetStats"),method.Name) {
                Set item={}
                Do item.%Set("class",definition.Name),item.%Set("method",method.Name),item.%Set("signature",method.FormalSpec),item.%Set("returns",method.ReturnType),result.%Push(item)
            }
        }
    }
    Return result.%ToJSON()
}
}
