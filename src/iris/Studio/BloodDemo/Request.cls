Class Studio.BloodDemo.Request Extends Ens.Request
{
Property BloodGroup As %String(VALUELIST = ",O+,A+") [ Required ];
Property Units As %Integer(MINVAL = 1, MAXVAL = 100) [ Required ];
Property Mode As %String(VALUELIST = ",SIMULATION,LIVE") [ InitialExpression = "SIMULATION" ];
Property CorrelationId As %String(MAXLEN = 128) [ Required ];
Property ReleaseId As %String(MAXLEN = 128);
}
