# CONTRATOS DE CLASSES E ASSINATURAS — PROPOSTA, NÃO COMPILADA

**ALERTA DE COMPATIBILIDADE:** todas as assinaturas `Studio.*` são **interfaces que a equipe implementará**. Os nomes `Studio.*` NÃO constam da SDK oficial. Metodologia: verificar propriedades de `%Dictionary`, classes `Ens.*` e `%AI.*` instaladas no 154, então compilar incrementalmente. Os métodos `%AI.Agent.Chat`/`CreateSession`/`%Init` abaixo são padrões documentados no repositório EAP atual, não prova de existência idêntica no 154.

## 1. Studio.Msg.DecisionRequest.cls

```objectscript
Class Studio.Msg.DecisionRequest Extends Ens.Request
{
    Property SchemaVersion As %String;
    Property ReleaseId As %String;
    Property BindingId As %String;
    Property CorrelationId As %String;
    Property InputJson As %String(MAXLEN = "");
    Property RequestedAt As %TimeStamp;
}
```

**Obrigatórios server-side:** ReleaseId/BindingId têm de existir e apontar para configuração publicada; InputJson deve ser JSON bounded/sanitizado. Campos de auditoria não são prompts.

## 2. Studio.Msg.DecisionResponse.cls

```objectscript
Class Studio.Msg.DecisionResponse Extends Ens.Response
{
    Property SchemaVersion As %String;
    Property Status As %String;
    Property Action As %String;
    Property Reason As %String(MAXLEN = "");
    Property EvidenceJson As %String(MAXLEN = "");
    Property DecisionExecutionId As %String;
    Property ErrorCode As %String;
}
```

**Estados válidos:** `SUCCESS`, `INVALID`, `ERROR`, `TIMEOUT`, `DENIED`. LLM só fornece conteúdo candidato; Status final é decidido pelo validador.

## 3. Studio.Interop.AgentDecisionOperation.cls

```objectscript
Class Studio.Interop.AgentDecisionOperation Extends Ens.BusinessOperation
{
    Parameter INVOCATION = "Queue";

    Method HandleDecision(pRequest As Studio.Msg.DecisionRequest,
                          Output pResponse As Studio.Msg.DecisionResponse) As %Status
    {
        // TODO: resolver binding publicado, invocar adapter, validar, auditar,
        // criar resposta tipada. NÃO chamar ferramentas com side effects arbitrários.
    }

    XData MessageMap
    {
      <MapItems>
        <MapItem MessageType="Studio.Msg.DecisionRequest">
          <Method>HandleDecision</Method>
        </MapItem>
      </MapItems>
    }
}
```

A assinatura do handler `(pReq, Output pResp) As %Status` e `MessageMap` têm suporte na documentação IRIS; a implementação e o uso de configuração de runtime ainda não foram testados. Timeout de operação/BPL deve ser harmonizado.

## 4. Studio.AI.AgentRuntimeAdapter.cls

```objectscript
Class Studio.AI.AgentRuntimeAdapter Extends %RegisteredObject
{
    ClassMethod ValidateSDKCapabilities(Output pReport As %DynamicObject) As %Status
    ClassMethod Invoke(pAgent As Studio.Model.AgentDefinition,
                       pInput As %DynamicObject,
                       pDecisionExecutionId As %String,
                       Output pRawResponse As %String,
                       Output pAgentSessionId As %String,
                       Output pUsage As %DynamicObject) As %Status
    ClassMethod BuildPrompt(pAgent As Studio.Model.AgentDefinition,
                            pInput As %DynamicObject) As %String
}
```

**Protocolo de implementação:** confirmar capacidade build154; resolver provider por referência a store segura, criar agente, configurar modelo e tools **por API validada**; criar sessão isolada; executar Chat; coletar response.Content e estatísticas comprovadas; capturar erro/redaction. Todas as chamadas `%AI.*` ficam **somente neste arquivo**. Nenhuma API de build 162 poderá ser usada por analogia.

Referência EAP atual (NÃO assinatura confirmada build154):

```objectscript
// PSEUDOCÓDIGO INTEGRATIVO; comparar com class reference da imagem 154
Set agent = ##class(Studio.AI.ConfiguredAgent).%New()
Set sc = agent.%Init()
Set session = agent.CreateSession()
Set result = agent.Chat(session, prompt)
Set raw = result.Content
```

Estratégia A: gerar subclasse de `%AI.Agent` a partir de definição controlada, `PROVIDER`, `MODEL`, `TOOLSETS`, `XData INSTRUCTIONS`. Estratégia B: instanciar programaticamente com provider e ToolSet. Escolher **uma** após descoberta do build 154; não implementar simultaneamente por suposição.

## 5. Studio.AI.DecisionValidator.cls

```objectscript
Class Studio.AI.DecisionValidator Extends %RegisteredObject
{
    ClassMethod ParseCandidate(pRawResponse As %String,
                               Output pCandidate As %DynamicObject) As %Status
    ClassMethod Validate(pBinding As Studio.Model.DecisionBinding,
                         pRawResponse As %String,
                         Output pValidated As %DynamicObject) As %Status
    ClassMethod ResolveRoute(pBinding As Studio.Model.DecisionBinding,
                             pStatus As %String, pAction As %String,
                             Output pOperationName As %String) As %Status
}
```

**Regra de ouro:** não passar destino da resposta LLM para `SendRequest`/BPL; `ResolveRoute` utiliza exclusivamente mapa publicado. Status ≠ SUCCESS usa fallback.

## 6. Studio.Admin.Metadata.cls

```objectscript
Class Studio.Admin.Metadata Extends %RegisteredObject
{
    ClassMethod DetectCapabilities() As %DynamicObject
    ClassMethod ListProductions(pNamespace As %String) As %DynamicArray
    ClassMethod ListBPLProcesses(pProductionName As %String) As %DynamicArray
    ClassMethod ListToolSets() As %DynamicArray
    ClassMethod DescribeMessageClass(pClassName As %String) As %DynamicObject
    ClassMethod DescribeBPLContext(pBPLClass As %String) As %DynamicObject
}
```

**Nota de segurança:** métodos representam **fachada interna**, não endpoints HTTP livres. Validação de identidade, namespace, ACL e filtros deve ocorrer também no lado IRIS. Não alterar a namespace livremente com nome de usuário; validar permissões e usar contextos permitidos. Inspeção de ToolSets por `Extends %AI.ToolSet` só depois de confirmar herança efetiva.

## 7. Studio.Admin.BPLReader.cls

```objectscript
Class Studio.Admin.BPLReader Extends %RegisteredObject
{
    ClassMethod ReadDefinition(pClassName As %String,
                               Output pDefinition As %DynamicObject) As %Status
    ClassMethod DetectManagedSlots(pClassName As %String) As %DynamicArray
    ClassMethod ComputeSourceHash(pClassName As %String) As %String
    ClassMethod ValidateRoundTrip(pClassName As %String,
                                 pCandidate As %DynamicObject) As %Status
}
```

**Princípio:** Dictionary.Definition ≠ Dictionary.Compiled. XData não editado em leitura, fonte desconhecida preservada. O hash deve incidir sobre a versão fonte efetivamente usada, com canonicalização definida e documentada.

## 8. Studio.Admin.BindingService.cls

```objectscript
Class Studio.Admin.BindingService Extends %RegisteredObject
{
    ClassMethod CreateDraft(pDefinition As %DynamicObject,
                            Output pDraftId As %String) As %Status
    ClassMethod SaveAgentRevision(pAgent As %DynamicObject,
                                 Output pAgentRevision As %Integer) As %Status
    ClassMethod SaveBinding(pDraftId As %String,
                            pBinding As %DynamicObject,
                            pExpectedRevision As %Integer) As %Status
    ClassMethod ValidateDraft(pDraftId As %String,
                              Output pIssues As %DynamicArray) As %Status
}
```

**Regra:** escrita apenas em draft/metadata. Sem compile ou alteração de Production nesses métodos.

## 9. Studio.Admin.BPLPublisher.cls

```objectscript
Class Studio.Admin.BPLPublisher Extends %RegisteredObject
{
    ClassMethod Preview(pDraftId As %String,
                        Output pDiff As %DynamicObject) As %Status
    ClassMethod Stage(pDraftId As %String, pBaseHash As %String,
                      Output pArtifactId As %String) As %Status
    ClassMethod CompileStaged(pArtifactId As %String,
                              Output pBuildReport As %DynamicObject) As %Status
    ClassMethod PublishStaged(pArtifactId As %String,
                              pApprovalRef As %String,
                              Output pReleaseId As %String) As %Status
    ClassMethod Restore(pReleaseId As %String,
                        Output pRestoredReleaseId As %String) As %Status
}
```

**Crítico:** `Stage` não deve regravar BPL produtivo. `CompileStaged` deve usar classe gerenciada/staged e verificar namespace e dependências. `PublishStaged` deve testar conflitos e suportar estratégia de promoção documentada no ambiente. A implementação de alteração Production requer revisão humana porque um banco compilado não é transacionalmente revertido como uma única linha SQL. `Restore` cria nova revisão/instalação, não desfaz mensagens processadas.

## 10. Studio.Admin.TestHarness.cls

```objectscript
Class Studio.Admin.TestHarness Extends %RegisteredObject
{
    ClassMethod ExecuteTest(pReleaseId As %String,
                            pPayload As %DynamicObject,
                            Output pMessageId As %String) As %Status
    ClassMethod GetExecution(pDecisionExecutionId As %String,
                             Output pTrace As %DynamicObject) As %Status
}
```

**Aviso:** `ExecuteTest` deve usar Business Service de **sandbox** real, aprovado e allowlisted. Não chamar diretamente um BO para mascarar a ausência de BPL.

## 11. Modelos `%Persistent` e métodos de domínio

As classes `Studio.Model.WorkflowDraft`, `AgentDefinition`, `DecisionBinding`, `WorkflowRelease` e `ExecutionAudit` herdarão `%Persistent`. Propor índices únicos por `AgentId+Revision`, `BindingId+Revision`, `WorkflowId+Revision` e `ReleaseId`. Evitar getters de mutação ocultos. Se houver métodos:

```objectscript
Class Studio.Model.AgentDefinition Extends %Persistent
{
    Property AgentId As %String;
    Property Revision As %Integer;
    Property ProviderRef As %String;
    Property ModelName As %String;
    Property Prompt As %String(MAXLEN = "");
    Property ToolSetRefsJson As %String(MAXLEN = "");
    Property Status As %String;
}
```

Não definir `Property APIKey` nem persistir token secreto. Identificação de Provider aponta para mecanismo seguro disponível e autorizado.

## 12. ToolSet demonstrativo READ

```objectscript
Class Studio.Tools.EventReadTools Extends %AI.ToolSet
{
  XData Definition [ MimeType = application/xml ]
  {
    <ToolSet Name="EventReadTools">
      <Tool Name="ReadEventContext" Method="ReadEventContext" />
    </ToolSet>
  }

  ClassMethod ReadEventContext(pEventId As %String) As %String
  {
    // TODO: consulta determinística, parametrizada, allowlist e limite de linhas.
  }
}
```

**Status:** sintaxe geral XData documentada no EAP atual, disponibilidade exata no 154 dependente de execução. READ apenas. Usar dados sintéticos para demo.

## 13. API nativa verificada x pendência

| Membro | Origem | Situação |
|---|---|---|
| `Ens.BusinessOperation` + handler `(pReq, Output pResp) As %Status` | docs IRIS | formato documentado |
| `Ens.Request`, `Ens.Response`, `Ens.BusinessProcessBPL` | docs IRIS | classes documentadas |
| `%Dictionary.ClassDefinition`, `%Dictionary.CompiledClass`, `%Dictionary.XDataDefinition` | docs IRIS | classes documentadas |
| `%AI.Agent.%Init`, `CreateSession`, `Chat`, `response.Content` | GitHub AI Hub EAP atual | **verificar 154** |
| `%AI.Provider.Create`, `UseToolSet`, `GetStats` | GitHub AI Hub EAP atual | **verificar 154** |
| `%AI.Agent.Skill`, `%AI.RAG.*`, `SubAgent` | EAP avançado/build posterior | **NÃO requisito MVP** |
| `Studio.*` acima | proposta do produto | **a construir** |

### Protocolo de confirmação

No build 154: listar classe real, abrir Class Reference, capturar `FormalSpec`, `ReturnType`, members herdados/definidos e exemplo compilável. Registrar resultado em `VALIDACAO_BUILD_154.md`; somente então escrever métodos que invoquem essas APIs.
