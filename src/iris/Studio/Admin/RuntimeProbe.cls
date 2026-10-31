Class Studio.Admin.RuntimeProbe Extends %RegisteredObject
{
ClassMethod Selected() As %DynamicObject
{
    Set report={"methods":[],"properties":[]}
    For c="%AI.Provider","%AI.Agent","%AI.Agent.Session","%AI.LLM.Response","%AI.ToolMgr","Ens.Director" {
        Set d=##class(%Dictionary.CompiledClass).%OpenId(c)
        Set k=""
        For {
            Set m=d.Methods.GetNext(.k)
            Quit:k=""
            If $ListFind($ListBuild("Create","UseToolSet","CreateSession","Chat","GetStats","%Init","%OnNew","RegisterToolSet","CreateBusinessService","StartProduction"),m.Name) {
                Set item={}
                Do item.%Set("class",c),item.%Set("name",m.Name),item.%Set("formalSpec",m.FormalSpec),item.%Set("returnType",m.ReturnType)
                Do report.methods.%Push(item)
            }
        }
        Set k=""
        For {
            Set p=d.Properties.GetNext(.k)
            Quit:k=""
            If p.Origin=c {
                Set item={}
                Do item.%Set("class",c),item.%Set("name",p.Name),item.%Set("type",p.Type)
                Do report.properties.%Push(item)
            }
        }
    }
    Return report
}
}
