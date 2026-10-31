Class Studio.Msg.WorkflowRequest Extends Ens.Request
{
Property EventId As %String(MAXLEN=128) [ Required ];
Property Description As %String(MAXLEN=4096);
Property CorrelationId As %String(MAXLEN=128) [ Required ];
Property ReleaseId As %String(MAXLEN=128) [ Required ];
Property Mode As %String(MAXLEN=16) [ InitialExpression="LIVE" ];
Property CandidateJson As %String(MAXLEN=16384);
Property SimulationFault As %String(MAXLEN=32);
}
