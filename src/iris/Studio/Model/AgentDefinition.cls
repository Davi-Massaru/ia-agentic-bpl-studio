/// Storage only. Administrative authorization and immutable revision service remain required.
Class Studio.Model.AgentDefinition Extends %Persistent
{
Property AgentId As %String(MAXLEN = 128) [ Required ];
Property Revision As %Integer(MINVAL = 1) [ Required ];
Property ProviderRef As %String(MAXLEN = 128) [ Required ];
Property ModelName As %String(MAXLEN = 128) [ Required ];
Property Prompt As %String(MAXLEN = 16384);
Property ToolSetRefsJson As %String(MAXLEN = 8192) [ InitialExpression = "[]" ];
Property Status As %String(VALUELIST = ",DRAFT,PUBLISHED,RETIRED") [ InitialExpression = "DRAFT" ];
Index RevisionKey On (AgentId, Revision) [ Unique ];
}
