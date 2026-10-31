Class Studio.Model.WorkflowRelease Extends %Persistent
{
Property ReleaseId As %String(MAXLEN = 128) [ Required ];
Property WorkflowId As %String(MAXLEN = 128) [ Required ];
Property Revision As %Integer(MINVAL = 1) [ Required ];
Property SourceHash As %String(MAXLEN = 64) [ Required ];
Property BPLClass As %String(MAXLEN = 256) [ Required ];
Property ManifestJson As %String(MAXLEN = 65536) [ Required ];
Property PublishedBy As %String;
Property PublishedAt As %TimeStamp;
Index ReleaseKey On ReleaseId [ Unique ];
Index WorkflowRevision On (WorkflowId, Revision) [ Unique ];
}
