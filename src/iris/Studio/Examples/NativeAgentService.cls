Include %occStatus
/// Local demonstration ingress. No Studio managed release is required.
Class Studio.Examples.NativeAgentService Extends Ens.BusinessService
{
Property Target As %String [ InitialExpression="FreeAgentWorkflow" ];
Parameter SETTINGS="Target";
Method OnProcessInput(pInput As Studio.Msg.AgentRequest, Output pOutput As Studio.Msg.DecisionResponse) As %Status
{
    Return ..SendRequestSync(..Target,pInput,.pOutput,75)
}
}
