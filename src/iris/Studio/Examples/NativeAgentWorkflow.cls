/// Ordinary editable BPL: two independent agents, no managed template or Studio release.
Class Studio.Examples.NativeAgentWorkflow Extends Ens.BusinessProcessBPL
{
XData BPL [ XMLNamespace = "http://www.intersystems.com/bpl" ]
{
<process language="objectscript" request="Studio.Msg.AgentRequest" response="Studio.Msg.DecisionResponse">
<context>
<property name="StockAction" type="%String"/>
<property name="StockStatus" type="%String"/>
<property name="ReviewAction" type="%String"/>
<property name="StockExecution" type="%String"><parameters><parameter name="MAXLEN" value="128"/></parameters></property>
</context>
<sequence>
<assign property="response.Action" value='"REVIEW"'/>
<assign property="response.Status" value='"ERROR"'/>
<assign property="response.DecisionExecutionId" value="request.CorrelationId"/>
<call name="AI Hub - Stock advisor" target="AIStockAdvisor" async="0" timeout="30">
<request type="Studio.Msg.AgentRequest">
<assign property="callrequest.InputJson" value="request.InputJson"/>
<assign property="callrequest.CorrelationId" value="request.CorrelationId"/>
</request>
<response type="Studio.Msg.DecisionResponse">
<assign property="context.StockAction" value="callresponse.Action"/>
<assign property="context.StockStatus" value="callresponse.Status"/>
<assign property="context.StockExecution" value="callresponse.DecisionExecutionId"/>
<assign property="response.AgentSessionId" value="callresponse.AgentSessionId"/>
</response>
</call>
<if name="Stock decision accepted" condition='(context.StockStatus="SUCCESS")&amp;&amp;(&apos;synctimedout)'>
<true>
<call name="AI Hub - Event reviewer" target="AIEventReviewer" async="0" timeout="30">
<request type="Studio.Msg.AgentRequest">
<assign property="callrequest.InputJson" value='"{""eventId"":""E-OK""}"'/>
<assign property="callrequest.CorrelationId" value="request.CorrelationId"/>
</request>
<response type="Studio.Msg.DecisionResponse">
<assign property="response.Status" value="callresponse.Status"/>
<assign property="response.DecisionExecutionId" value="callresponse.DecisionExecutionId"/>
<assign property="response.AgentSessionId" value="callresponse.AgentSessionId"/>
<assign property="context.ReviewAction" value="callresponse.Action"/>
</response>
</call>
<if name="Reviewer deadline" condition="synctimedout"><true><assign property="response.Status" value='"TIMEOUT"'/></true></if>
<if name="Route validated result" condition='(response.Status="SUCCESS")&amp;&amp;(context.ReviewAction="ACCEPT")'>
<true><assign name="Return stock recommendation" property="response.Action" value="context.StockAction"/></true>
<false><assign name="Review on agent failure" property="response.Action" value='"REVIEW"'/></false>
</if>
</true>
<false>
<assign name="Fallback to review" property="response.Action" value='"REVIEW"'/>
<assign property="response.Status" value='"ERROR"'/>
<if name="Keep correlation on timeout" condition='context.StockExecution&apos;=""'>
<true><assign property="response.DecisionExecutionId" value="context.StockExecution"/></true>
</if>
</false>
</if>
</sequence>
</process>
}
}
