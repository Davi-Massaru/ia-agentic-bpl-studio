Class Studio.Msg.DecisionResponse Extends Ens.Response
{
Property SchemaVersion As %String(VALUELIST = ",1") [ InitialExpression = "1", Required ];
Property Status As %String(VALUELIST = ",SUCCESS,INVALID,ERROR,TIMEOUT,DENIED") [ Required ];
Property Action As %String(MAXLEN = 40) [ Required ];
Property Reason As %String(MAXLEN = 2048);
Property EvidenceJson As %String(MAXLEN = 8192) [ InitialExpression = "[]" ];
Property DecisionExecutionId As %String(MAXLEN = 128) [ Required ];
Property ErrorCode As %String(MAXLEN = 128);
Property AgentSessionId As %String(MAXLEN = 128);
}
