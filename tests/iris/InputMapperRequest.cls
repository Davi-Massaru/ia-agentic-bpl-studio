Class Studio.Tests.InputMapperRequest Extends Ens.Request
{
Property EventId As %String;
Property Description As %String;
Property Units As %Integer;
Property Cost As %Numeric;
Property IsEnabled As %Boolean [ InitialExpression = 0 ];
Property UnsafeObject As %DynamicObject;
}
