Class Studio.Msg.DecisionRequest Extends Ens.Request
{
Property SchemaVersion As %String(VALUELIST = ",1") [ InitialExpression = "1", Required ];
Property ReleaseId As %String(MAXLEN = 128) [ Required ];
Property BindingId As %String(MAXLEN = 128) [ Required ];
Property CorrelationId As %String(MAXLEN = 128) [ Required ];
Property InputJson As %String(MAXLEN = 65536) [ Required ];
Property RequestedAt As %TimeStamp;
Property Mode As %String(MAXLEN=16) [ InitialExpression="LIVE" ];
Property CandidateJson As %String(MAXLEN=16384);
Property SimulationFault As %String(MAXLEN=32);
}
