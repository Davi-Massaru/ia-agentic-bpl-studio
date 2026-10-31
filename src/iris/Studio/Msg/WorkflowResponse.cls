Class Studio.Msg.WorkflowResponse Extends Ens.Response
{
Property Status As %String(MAXLEN=40);
Property Action As %String(MAXLEN=40);
Property Reason As %String(MAXLEN=2048);
Property CorrelationId As %String(MAXLEN=128);
Property DecisionExecutionId As %String(MAXLEN=128);
Property AgentSessionId As %String(MAXLEN=128);
Property Receipt As %String(MAXLEN=128);
}
