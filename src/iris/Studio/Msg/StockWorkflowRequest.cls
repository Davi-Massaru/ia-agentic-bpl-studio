/// Synthetic redistribution request for the installed stock decision template.
Class Studio.Msg.StockWorkflowRequest Extends Studio.Msg.WorkflowRequest
{
Property BloodGroup As %String(VALUELIST=",O+,A+") [ Required ];
Property Units As %Integer(MINVAL=1,MAXVAL=100) [ Required ];
}
