Class Studio.Demo.Production Extends Ens.Production
{
XData ProductionDefinition
{
<Production Name="Studio.Demo.Production" TestingEnabled="true" LogGeneralTraceEvents="true">
<Description>Generic Studio workspace sandbox. Domain demos are separate examples.</Description>
<ActorPoolSize>2</ActorPoolSize>
<Item Name="StudioWorkflowService" ClassName="Studio.Interop.WorkflowService" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="true"/>
<Item Name="AgentDecision" ClassName="Studio.Interop.AgentDecisionOperation" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="true"/>
<Item Name="AcceptOperation" ClassName="Studio.Demo.AcknowledgeOperation" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="true"><Setting Target="Host" Name="Label">ACCEPT</Setting></Item>
<Item Name="ReviewOperation" ClassName="Studio.Demo.AcknowledgeOperation" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="true"><Setting Target="Host" Name="Label">REVIEW</Setting></Item>
</Production>
}
}
