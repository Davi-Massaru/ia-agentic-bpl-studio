/// Only a trusted published release may supply this record to the runtime.
Class Studio.Model.DecisionBinding Extends %Persistent
{
Property BindingId As %String(MAXLEN = 128) [ Required ];
Property Revision As %Integer(MINVAL = 1) [ Required ];
Property AgentId As %String(MAXLEN = 128) [ Required ];
Property AgentRevision As %Integer(MINVAL = 1) [ Required ];
Property InputsJson As %String(MAXLEN = 32768);
Property OutputsJson As %String(MAXLEN = 8192);
Property RoutesJson As %String(MAXLEN = 8192) [ Required ];
Property FallbackAction As %String(MAXLEN = 40) [ Required ];
Property FallbackTarget As %String(MAXLEN = 128) [ Required ];
Property AgentTimeoutMs As %Integer(MINVAL = 1000, MAXVAL = 300000) [ InitialExpression = 30000 ];
Index RevisionKey On (BindingId, Revision) [ Unique ];
}
