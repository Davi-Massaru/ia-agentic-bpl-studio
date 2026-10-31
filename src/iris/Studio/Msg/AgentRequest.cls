/// Portable AI decision input. Map any native request/context into InputJson in a BPL Call.
Class Studio.Msg.AgentRequest Extends Ens.Request
{
Property InputJson As %String(MAXLEN=65536) [ Required ];
Property CorrelationId As %String(MAXLEN=128);
}
