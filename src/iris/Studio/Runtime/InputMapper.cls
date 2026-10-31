Include %occStatus

/// Bounded, typed property mapping. Expressions and arbitrary member traversal are forbidden.
Class Studio.Runtime.InputMapper Extends %RegisteredObject
{
ClassMethod Identifier(pValue As %String, pMaximum As %Integer = 64) As %Boolean
{
    If ($Length(pValue)<1)!($Length(pValue)>pMaximum) Return 0
    For i=1:1:$Length(pValue) {
        Set char=$Extract(pValue,i),code=$Ascii(char)
        Set letter=((code>=65)&&(code<=90))!((code>=97)&&(code<=122))
        If (i=1)&&('letter) Return 0
        If ('letter)&&('((code>=48)&&(code<=57)))&&(char'="_") Return 0
    }
    Return 1
}

/// Returns only supported scalar type families from the compiled Dictionary.
ClassMethod PropertyType(pClass As %String, pName As %String) As %String
{
    If '..Identifier(pName) Return ""
    Set definition=##class(%Dictionary.CompiledClass).%OpenId(pClass)
    If '$IsObject(definition) Return ""
    Set key="",kind=""
    For {
        Set property=definition.Properties.GetNext(.key)
        Quit:key=""
        If property.Name=pName {
            If property.Collection'="" Quit
            Set type=property.Type
            If $ListFind($ListBuild("%String","%Library.String"),type) Set kind="string"
            If $ListFind($ListBuild("%Integer","%Library.Integer","%SmallInt","%Library.SmallInt","%BigInt","%Library.BigInt"),type) Set kind="integer"
            If $ListFind($ListBuild("%Numeric","%Library.Numeric","%Float","%Library.Float","%Double","%Library.Double","%Decimal","%Library.Decimal"),type) Set kind="number"
            If $ListFind($ListBuild("%Boolean","%Library.Boolean"),type) Set kind="boolean"
            Quit
        }
    }
    Return kind
}

ClassMethod SourceType(pRequestClass As %String, pSource As %String) As %String
{
    If ($Extract(pSource,1,9)="constant:")&&($Length(pSource)'>265) Return "string"
    If $Length(pSource)>256 Return ""
    If $Length(pSource,".")'=2 Return ""
    Set root=$Piece(pSource,".",1),name=$Piece(pSource,".",2)
    If '..Identifier(name) Return ""
    If root="request" Return ..PropertyType(pRequestClass,name)
    If (root="context")&&((name="Action")!(name="Reason")) Return "string"
    Return ""
}

ClassMethod Validate(pRequestClass As %String, pBinding As %DynamicObject, Output pIssues As %DynamicArray) As %Status
{
    Set pIssues=[]
    If '##class(%Dictionary.CompiledClass).%ExistsId(pRequestClass) {
        Do pIssues.%Push("REQUEST_CLASS_NOT_FOUND")
        Return $$$ERROR($$$GeneralError,"MAPPING_INVALID")
    }
    Try {
        If '$IsObject(pBinding) Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"BINDING_OBJECT_REQUIRED"))
        Set inputs=pBinding.%Get("inputs")
        If '$IsObject(inputs) Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"INPUTS_ARRAY_REQUIRED"))
        If 'inputs.%IsA("%DynamicArray") Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"INPUTS_ARRAY_REQUIRED"))
        If (inputs.%Size()<1)!(inputs.%Size()>40) Do pIssues.%Push("INPUT_COUNT_INVALID")
        For i=0:1:inputs.%Size()-1 {
            Set item=inputs.%Get(i)
            If '$IsObject(item) {
                Do pIssues.%Push("INPUT_OBJECT_REQUIRED")
                Continue
            }
            If 'item.%IsA("%DynamicObject") {
                Do pIssues.%Push("INPUT_OBJECT_REQUIRED")
                Continue
            }
            If (item.%GetTypeOf("source")'="string")!(item.%GetTypeOf("target")'="string")!(item.%GetTypeOf("required")'="boolean") {
                Do pIssues.%Push("INPUT_CONTRACT_INVALID")
                Continue
            }
            If item.%Size()'=3 Do pIssues.%Push("INPUT_UNKNOWN_FIELD")
            If ..SourceType(pRequestClass,item.source)="" Do pIssues.%Push("SOURCE_NOT_SUPPORTED")
            If '..Identifier(item.target) {
                Do pIssues.%Push("TARGET_NOT_SUPPORTED")
            } Else {
                If $Data(seen(item.target)) Do pIssues.%Push("DUPLICATE_TARGET")
                Set seen(item.target)=1
            }
        }
        Set outputs=pBinding.%Get("outputs")
        If '$IsObject(outputs) Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"OUTPUTS_OBJECT_REQUIRED"))
        If 'outputs.%IsA("%DynamicObject") Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"OUTPUTS_OBJECT_REQUIRED"))
        If (outputs.%GetTypeOf("action")'="string") Do pIssues.%Push("OUTPUT_ACTION_REQUIRED")
        Set iterator=outputs.%GetIterator()
        While iterator.%GetNext(.name,.path) {
            If outputs.%GetTypeOf(name)'="string" {
                Do pIssues.%Push("OUTPUT_PATH_STRING_REQUIRED")
                Continue
            }
            If (name="action")&&((path="context.Action")!(path="response.Action")) Continue
            If (name="reason")&&((path="context.Reason")!(path="response.Reason")) Continue
            Do pIssues.%Push("OUTPUT_NOT_SUPPORTED")
        }
    } Catch ex {
        Do pIssues.%Push("MAPPING_CONTRACT_INVALID")
    }
    If pIssues.%Size()>0 Return $$$ERROR($$$GeneralError,"MAPPING_INVALID")
    Return $$$OK
}

ClassMethod Map(pRequest As %RegisteredObject, pContextJson As %String, pBinding As %DynamicObject, Output pInput As %DynamicObject, pRedact As %Boolean = 0) As %Status
{
    Set pInput={}
    If '$IsObject(pRequest) Return $$$ERROR($$$GeneralError,"REQUEST_OBJECT_REQUIRED")
    Set requestClass=pRequest.%ClassName(1)
    Set sc=..Validate(requestClass,pBinding,.issues)
    If $$$ISERR(sc) Return sc
    Set mapped={}
    Try {
        If $Length(pContextJson)>16384 Return $$$ERROR($$$GeneralError,"CONTEXT_TOO_LARGE")
        Set context=##class(%DynamicObject).%FromJSON($Select(pContextJson="":"{}",1:pContextJson))
        If 'context.%IsA("%DynamicObject") Return $$$ERROR($$$GeneralError,"CONTEXT_OBJECT_REQUIRED")
        For i=0:1:pBinding.inputs.%Size()-1 {
            Set item=pBinding.inputs.%Get(i),source=item.source,kind=..SourceType(requestClass,source),missing=0
            If $Extract(source,1,9)="constant:" {
                Set value=$Extract(source,10,*)
            } Else {
                Set root=$Piece(source,".",1),name=$Piece(source,".",2)
                If root="request" {
                    // The compiled Dictionary and the strict path grammar were checked above.
                    Set value=$Property(pRequest,name)
                    If value="" Set missing=1
                } Else {
                    If 'context.%IsDefined(name) {
                        Set missing=1,value=""
                    } Else {
                        If context.%GetTypeOf(name)'="string" Return $$$ERROR($$$GeneralError,"INPUT_TYPE_MISMATCH")
                        Set value=context.%Get(name)
                        If value="" Set missing=1
                    }
                }
            }
            If missing {
                If item.required Return $$$ERROR($$$GeneralError,"REQUIRED_INPUT_MISSING")
                Continue
            }
            If $IsObject(value) Return $$$ERROR($$$GeneralError,"INPUT_SCALAR_REQUIRED")
            If $Length(value)>16384 Return $$$ERROR($$$GeneralError,"INPUT_VALUE_TOO_LARGE")
            If kind="boolean",(value'=0)&&(value'=1) Return $$$ERROR($$$GeneralError,"INPUT_TYPE_MISMATCH")
            If kind="integer",(value'=+value)!(value\1'=value) Return $$$ERROR($$$GeneralError,"INPUT_TYPE_MISMATCH")
            If kind="number",value'=+value Return $$$ERROR($$$GeneralError,"INPUT_TYPE_MISMATCH")
            If pRedact {
                Do mapped.%Set(item.target,"[REDACTED]")
            } Else {
                If kind="boolean" {
                    Do mapped.%Set(item.target,value,"boolean")
                } ElseIf (kind="number")!(kind="integer") {
                    Do mapped.%Set(item.target,value,"number")
                } Else {
                    Do mapped.%Set(item.target,value,"string")
                }
            }
        }
        If $Length(mapped.%ToJSON())>32768 Return $$$ERROR($$$GeneralError,"MAPPED_INPUT_TOO_LARGE")
    } Catch ex {
        Set pInput={}
        Return $$$ERROR($$$GeneralError,"INPUT_MAPPING_FAILED")
    }
    Set pInput=mapped
    Return $$$OK
}

/// BPL expression helper. Failure is a native status exception, never executable input.
ClassMethod MapJson(pRequest As %RegisteredObject, pBindingJson As %String, pContextJson As %String = "{}") As %String
{
    If $Length(pBindingJson)>32768 Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"BINDING_TOO_LARGE"))
    Set binding=##class(%DynamicObject).%FromJSON(pBindingJson)
    Set sc=..Map(pRequest,pContextJson,binding,.input)
    If $$$ISERR(sc) Throw ##class(%Exception.StatusException).CreateFromStatus(sc)
    Return input.%ToJSON()
}

/// Administrative preview for a trusted workflow's request class. Every value is redacted.
ClassMethod Preview(pRequestClass As %String, pExampleJson As %String, pBindingJson As %String) As %String
{
    Set result={"ok":false,"data":{"input":{},"issues":[]}}
    Try {
        If ($Length(pExampleJson)>32768)!($Length(pBindingJson)>32768) Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"PREVIEW_TOO_LARGE"))
        Set example=##class(%DynamicObject).%FromJSON(pExampleJson),binding=##class(%DynamicObject).%FromJSON(pBindingJson)
        Set sc=..Validate(pRequestClass,binding,.issues)
        Do result.data.%Set("issues",issues)
        If $$$ISERR(sc) Return result.%ToJSON()
        If 'example.%IsA("%DynamicObject") Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"PREVIEW_OBJECT_REQUIRED"))
        If example.%Size()>40 Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"PREVIEW_TOO_MANY_FIELDS"))
        Set request=$ClassMethod(pRequestClass,"%New")
        Set iterator=example.%GetIterator()
        While iterator.%GetNext(.name,.value) {
            Set kind=..PropertyType(pRequestClass,name),jsonType=example.%GetTypeOf(name)
            If kind="" Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"PREVIEW_UNKNOWN_FIELD"))
            If (kind="string")&&(jsonType'="string") Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"PREVIEW_TYPE_MISMATCH"))
            If (kind="boolean")&&(jsonType'="boolean") Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"PREVIEW_TYPE_MISMATCH"))
            If ((kind="integer")!(kind="number"))&&(jsonType'="number") Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"PREVIEW_TYPE_MISMATCH"))
            Set $Property(request,name)=value
        }
        Set sc=..Map(request,"{}",binding,.input,1)
        If $$$ISERR(sc) {
            Do result.data.issues.%Push("PREVIEW_INPUT_INVALID")
            Return result.%ToJSON()
        }
        Do result.%Set("ok",1,"boolean"),result.data.%Set("input",input)
    } Catch ex {
        Do result.data.issues.%Push("PREVIEW_INVALID")
    }
    Return result.%ToJSON()
}
}
