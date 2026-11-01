Class Studio.BloodDemo.Production Extends Ens.Production
{
XData ProductionDefinition
{
<Production Name="Studio.BloodDemo.Production" TestingEnabled="true" LogGeneralTraceEvents="true">
  <Description>Synthetic A to B/C hello world; Managed AI Hub stock decision template and legacy demonstration.</Description>
  <ActorPoolSize>2</ActorPoolSize>
  <Item Name="HemocentroA" Category="BloodDemo" ClassName="Studio.BloodDemo.Service" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="true"/>
  <Item Name="BloodRouting" Category="BloodDemo" ClassName="Studio.BloodDemo.Routing" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="true"/>
  <Item Name="BloodDecision" Category="BloodDemo" ClassName="Studio.BloodDemo.DecisionOperation" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="true"/>
  <Item Name="HemocentroB" Category="BloodDemo" ClassName="Studio.BloodDemo.ReceiptOperation" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="true"><Setting Target="Host" Name="Center">B</Setting></Item>
  <Item Name="HemocentroC" Category="BloodDemo" ClassName="Studio.BloodDemo.ReceiptOperation" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="true"><Setting Target="Host" Name="Center">C</Setting></Item>
  <Item Name="Review" Category="BloodDemo" ClassName="Studio.BloodDemo.ReceiptOperation" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="true"><Setting Target="Host" Name="Center">REVIEW</Setting></Item>
<Item Name="StudioWorkflowService" ClassName="Studio.Interop.WorkflowService" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="true"/>
<Item Name="AgentDecision" ClassName="Studio.Interop.AgentDecisionOperation" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="true"/>
<Item Name="StockCenterB" ClassName="Studio.Demo.AcknowledgeOperation" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="true"/>
<Item Name="StockCenterC" ClassName="Studio.Demo.AcknowledgeOperation" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="true"/>
<Item Name="StockReview" ClassName="Studio.Demo.AcknowledgeOperation" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="true"/>
</Production>
}
}
