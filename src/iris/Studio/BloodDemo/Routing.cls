Class Studio.BloodDemo.Routing Extends Ens.BusinessProcessBPL
{
XData BPL [ XMLNamespace = "http://www.intersystems.com/bpl" ]
{
<process language="objectscript" request="Studio.BloodDemo.Request" response="Studio.BloodDemo.Response">
<context><property name="Destination" type="%String"/><property name="DecisionStatus" type="%String"/></context>
<sequence>
<assign property="response.CorrelationId" value="request.CorrelationId"/>
<assign property="response.Mode" value="request.Mode"/>
<call name="Decision" target="BloodDecision" async="0"><request type="Studio.BloodDemo.Request">
<assign property="callrequest.BloodGroup" value="request.BloodGroup"/>
<assign property="callrequest.Units" value="request.Units"/>
<assign property="callrequest.Mode" value="request.Mode"/>
<assign property="callrequest.CorrelationId" value="request.CorrelationId"/>
<assign property="callrequest.ReleaseId" value="request.ReleaseId"/>
</request>
<response type="Studio.BloodDemo.Response">
<assign property="context.Destination" value="callresponse.Destination"/>
<assign property="context.DecisionStatus" value="callresponse.Status"/>
<assign property="response.Status" value="callresponse.Status"/>
<assign property="response.Reason" value="callresponse.Reason"/>
<assign property="response.AgentSessionId" value="callresponse.AgentSessionId"/>
</response>
</call>
<switch name="Allowlisted destination">
<case condition='((context.DecisionStatus="SIMULATED")!(context.DecisionStatus="SUCCESS"))&amp;&amp;(context.Destination="B")'><call name="Send HemocentroB" target="HemocentroB" async="0"><request type="Studio.BloodDemo.Request">
<assign property="callrequest.BloodGroup" value="request.BloodGroup"/>
<assign property="callrequest.Units" value="request.Units"/>
<assign property="callrequest.Mode" value="request.Mode"/>
<assign property="callrequest.CorrelationId" value="request.CorrelationId"/>
<assign property="callrequest.ReleaseId" value="request.ReleaseId"/>
</request>
<response type="Studio.BloodDemo.Response">
<assign property="response.Receipt" value="callresponse.Receipt"/>
<assign property="response.Destination" value="callresponse.Destination"/>
</response></call></case>
<case condition='((context.DecisionStatus="SIMULATED")!(context.DecisionStatus="SUCCESS"))&amp;&amp;(context.Destination="C")'><call name="Send HemocentroC" target="HemocentroC" async="0"><request type="Studio.BloodDemo.Request">
<assign property="callrequest.BloodGroup" value="request.BloodGroup"/>
<assign property="callrequest.Units" value="request.Units"/>
<assign property="callrequest.Mode" value="request.Mode"/>
<assign property="callrequest.CorrelationId" value="request.CorrelationId"/>
<assign property="callrequest.ReleaseId" value="request.ReleaseId"/>
</request>
<response type="Studio.BloodDemo.Response">
<assign property="response.Receipt" value="callresponse.Receipt"/>
<assign property="response.Destination" value="callresponse.Destination"/>
</response></call></case>
<default><call name="Send Review" target="Review" async="0"><request type="Studio.BloodDemo.Request">
<assign property="callrequest.BloodGroup" value="request.BloodGroup"/>
<assign property="callrequest.Units" value="request.Units"/>
<assign property="callrequest.Mode" value="request.Mode"/>
<assign property="callrequest.CorrelationId" value="request.CorrelationId"/>
<assign property="callrequest.ReleaseId" value="request.ReleaseId"/>
</request>
<response type="Studio.BloodDemo.Response">
<assign property="response.Receipt" value="callresponse.Receipt"/>
<assign property="response.Destination" value="callresponse.Destination"/>
</response></call></default>
</switch>
</sequence>
</process>
}
}
