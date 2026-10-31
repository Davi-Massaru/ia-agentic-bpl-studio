Class Studio.Model.WorkflowDraft Extends %Persistent
{
Property WorkflowId As %String(MAXLEN = 128) [ Required ];
Property Revision As %Integer(MINVAL = 1) [ Required ];
Property BaseHash As %String(MAXLEN = 64) [ Required ];
Property BindingJson As %String(MAXLEN = 32768);
Property BindingRevision As %Integer;
Property CreatedBy As %String;
Index RevisionKey On (WorkflowId, Revision) [ Unique ];
}
