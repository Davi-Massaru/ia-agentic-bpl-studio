Class Studio.BloodDemo.Response Extends Ens.Response
{
Property Destination As %String(VALUELIST = ",B,C,REVIEW") [ InitialExpression = "REVIEW" ];
Property Status As %String(MAXLEN = 40);
Property Reason As %String(MAXLEN = 2048);
Property Mode As %String(MAXLEN = 20);
Property CorrelationId As %String(MAXLEN = 128);
Property Receipt As %String(MAXLEN = 128);
Property AgentSessionId As %String(MAXLEN = 128);
}
