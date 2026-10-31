# SEQUÊNCIAS OPERACIONAIS — HTTP, PUBLISH E EXECUÇÃO

## A. Edição de AI Decision (sem efeito runtime)

```mermaid
sequenceDiagram
  actor User as Developer
  participant UI as BPL Designer
  participant F as Flask
  participant DI as Studio.Admin.Metadata
  participant DB as Studio.Model
  User->>UI: Abrir workflow gerenciado
  UI->>F: GET /workflows/{id}
  F->>DI: BPL Reader + schema introspection
  DI-->>F: AST reconhecida + baseHash
  F-->>UI: Graph + slots AI Decision
  User->>UI: Inputs, Agent, Tools, Outputs, Runtime
  UI->>F: PUT /bindings/{id} + revision
  F->>DI: Validar classes, types e policies
  DI->>DB: Salvar DecisionBinding draft
  DB-->>UI: revisão + erros/avisos
```

## B. Publicação (não pode simular êxito)

```mermaid
sequenceDiagram
  actor User as Publisher
  participant UI as Publish Center
  participant F as Flask API
  participant P as Studio.Admin.BPLPublisher
  participant D as Dictionary/BPL Source
  participant C as IRIS Compiler
  participant R as Release Registry
  User->>UI: Preview
  UI->>F: POST /preview
  F->>P: Preview(draft)
  P->>D: Compare baseHash + safe slot
  D-->>P: diff + dependencies
  P-->>UI: Validation + diff
  User->>UI: Confirm Publish Workflow
  UI->>F: POST /publish + If-Match + idempotency
  F->>P: Stage draft and snapshot
  P->>C: Compile managed artifact
  alt compile succeeded + permissions valid
    C-->>P: Success
    P->>R: Publish release snapshot
    P-->>UI: releaseId + trace of changes
  else conflict or compile fail
    C-->>P: Failure details
    P-->>UI: Error / no publish
  end
```

## C. Produção real — evento a operação (requisito do concurso)

```mermaid
sequenceDiagram
  participant BS as Business Service
  participant BPL as BPL Business Process
  participant BO as AgentDecisionOperation
  participant AR as AgentRuntimeAdapter
  participant AI as %AI.Agent
  participant T as %AI.ToolSet
  participant V as DecisionValidator
  participant O as Destination BO
  BS->>BPL: Ens.Request
  BPL->>BO: Studio.Msg.DecisionRequest
  BO->>AR: Load published binding/agent
  AR->>AI: CreateSession + Chat (build154)
  AI->>T: authorized READ tool
  T-->>AI: evidence
  AI-->>AR: candidate content
  AR-->>BO: raw response and audit metadata
  BO->>V: schema/enum/permissions
  V-->>BO: validated action or fallback
  BO-->>BPL: Studio.Msg.DecisionResponse
  BPL->>BPL: assign callresponse→context
  BPL->>BPL: switch on status + action
  BPL->>O: request for allowed path
  O-->>BPL: operation response
```

**Regras:** a decisão não chama diretamente o BO de destino; o switch BPL tem targets estáticos publicados; status inválido ou timeout percorre fallback. Session de AI Hub não equivale à Interop session.

## D. Falhas e classificação

- FALHA HTTP: Flask retorna erro sem afetar mensagens em fila da Production.
- FALHA SDK/Provider: Bridge transforma a falha em status tipado + fallback; se a falha for de infraestrutura, tratamento de exceção BPL permanece obrigatório.
- FALHA Tool não autorizada: tool não executa, evento `DENIED`, fallback.
- FALHA Output malformado: validação retorna `INVALID`, nunca executar ação extraída de texto.
- FALHA Publish: nenhuma afirmação de release publicada; guardar logs e estado anterior.
- RETRY/redelivery: usar idempotency/correlation conforme BO de destino; não assumir exactly-once.
