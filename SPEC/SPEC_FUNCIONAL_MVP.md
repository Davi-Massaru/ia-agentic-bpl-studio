# AGENTIC BPL STUDIO — ESPECIFICAÇÃO FUNCIONAL DO MVP

**Documento:** SPEC-FUNC-ABS-001  
**Revisão:** 1.0 — 25/10/2026  
**Estado:** PROPOSTA DE IMPLEMENTAÇÃO — NÃO EXECUTADA  
**Missão operacional:** Evoluir visualmente o BPL nativo para incorporar decisões de agentes nativos do InterSystems IRIS AI Hub em workflows de interoperabilidade.  
**Posicionamento:** *The Visual Evolution of InterSystems BPL for Agentic Interoperability.*

> **ORDEM CENTRAL:** O artefato publicado DEVE ser um **workflow BPL executável na InterSystems Interoperability**. O AI Hub DEVE decidir. O BPL DEVE orquestrar, validar e encaminhar. O Flask NÃO DEVE executar um workflow paralelo.

---

## 1. SITUAÇÃO

### 1.1. Capacidades já existentes

O editor visual BPL da InterSystems já permite criar/abrir processos, editar atividades e suas propriedades no Inspector, definir `request`, `response` e variáveis `context`, adicionar conexões, salvar e compilar. O engine já oferece `call`, `assign`, `switch`, chamadas síncronas/assíncronas, transformações, tratamento de erros, Business Rules e rastreio via Interoperability.

### 1.2. Lacuna operacional

O usuário precisa implementar manualmente a integração entre uma atividade BPL, o agente `%AI.Agent`, suas ferramentas, os campos de entrada, a resposta estruturada e o desvio posterior do processo. Não se pressupõe que o editor oficial tenha uma API pública de plugins para inserir novas atividades personalizadas.

### 1.3. Problema a resolver

**Transformar uma chamada agêntica num componente visual reutilizável**, permitindo que o desenvolvedor configure tudo o que atravessa a fronteira **BPL → AI Hub → BPL** sem programar uma ponte ObjectScript específica para cada workflow.

### 1.4. Condições de contorno

- Alvo do concurso: imagem AI Hub Community `2026.3.0AI.154.0`.
- A interface será um editor complementar próprio, não uma alteração no código do Management Portal.
- API e assinaturas do AI Hub DEVEM ser verificadas no build 154. O conteúdo de `master` do repositório EAP NÃO é prova de compatibilidade.
- O mecanismo de instalação HTTP/WSGI e as dependências do Flask DEVEM ser verificados no ambiente EAP.

## 2. MISSÃO

**M-01 — PROPÓSITO.** Construir um MVP que permita **selecionar ou criar um BPL gerenciado**, incluir uma **AI Decision**, configurar Inputs, agente, ToolSets, Outputs, rotas e falhas, **testar uma execução real** e **publicar o workflow** na Production.

**M-02 — RESULTADO OPERACIONAL.** Um evento entra em Business Service; um Business Process BPL chama o agente AI Hub via Business Host reutilizável; a decisão tipada retorna ao BPL; o BPL valida, escolhe rota e chama uma Business Operation; o operador observa a cadeia no Test & Trace.

**M-03 — REGRA DE VALOR.** Não desenvolver outro motor BPL, outro runtime de IA, um chatbot genérico ou um editor completo de Productions.

## 3. EXECUÇÃO — ESTRUTURA DE TELAS

### 3.1. Quatro telas indispensáveis

| ID | Tela | Missão da tela | Saída concreta |
|---|---|---|---|
| T-01 | **Workflow Explorer** | Descobrir o contexto de produção e escolher BPL | Workflow carregado ou criado como rascunho |
| T-02 | **Agentic BPL Designer** | Vincular AI Hub a uma atividade BPL; configurar Inputs, Agent, Tools, Outputs e Runtime | `DecisionBinding` válido, BPL modificado em draft |
| T-03 | **Workflow Test & Trace** | Injetar mensagens e observar decisões reais | Evidência correlacionada de execução ponta a ponta |
| T-04 | **Workflow Publisher** | Validar, versionar, compilar e disponibilizar BPL e dependências | Revisão publicada e verificável na Production |

**DIRETRIZ:** Agent Builder, Tool Registry, Input Mapper e Output Mapper NÃO serão telas independentes. Serão abas do Inspector da T-02. Settings técnico será um painel/modal administrativo discreto.

### 3.2. Navegação operacional

`Explorer → Designer → Test & Trace → Publisher → Explorer`  
Do Designer será possível abrir Test & Trace; o Publisher recusará rascunhos sem validação. Da execução será possível retornar ao binding em modo edição, criando nova revisão.

---

## 4. TELA T-01 — WORKFLOW EXPLORER

**FINALIDADE:** Abrir o BPL correto, sem redigitar os recursos existentes no IRIS.

### 4.1. Estrutura da interface

- **Cabeçalho:** instância/conexão, namespace selecionada, Production, estado da conexão e build detectado.
- **Painel esquerdo:** lista de Productions e seus Business Processes BPL; pesquisa por classe/nome.
- **Painel central:** processos existentes, com classe, Production, modo de edição suportado, quantidade de AI Decisions e revisão.
- **Comandos:** `Open`, `Create Managed Workflow`, `Refresh`.

### 4.2. Comportamentos vinculantes

- **EX-01:** Ao selecionar namespace, carregar apenas Productions/classes autorizadas no contexto.
- **EX-02:** Ao escolher Production, identificar Business Processes BPL existentes e Business Operations relacionadas.
- **EX-03:** Ao abrir um BPL **gerenciado e reconhecido**, carregar a estrutura e habilitar as alterações permitidas.
- **EX-04:** Ao abrir BPL não gerenciado ou com construção desconhecida, usar **somente leitura**; nunca reescrever XML/XData arbitrariamente.
- **EX-05:** `Create Managed Workflow` inicia processo baseado em template conhecido (Business Service → BPL → AI Decision → decisão → Business Operations).
- **EX-06:** Falha de permissão ou conexão deve produzir diagnóstico claro e bloquear escrita.

### 4.3. Proibições

NÃO oferecer gerenciamento completo de Productions, instalação dinâmica de adapters ou edição universal de BPL nesta tela.

**ACEITE T-01:** usuário seleciona namespace/Production, abre um processo compatível e vê o mesmo conjunto de hosts que está configurado no IRIS.

---

## 5. TELA T-02 — AGENTIC BPL DESIGNER

**FINALIDADE:** Editar o **ponto de decisão agêntico** do processo.

### 5.1. Disposição física

- **Barra superior:** nome da classe BPL, revisão draft, `Save Draft`, `Validate`, `Test`, `Publish Workflow` (este último pode abrir T-04).
- **Coluna esquerda:** árvore das atividades, paleta restrita (`AI Decision` e atividades nativas reconhecidas).
- **Centro:** canvas com nós e conexões do BPL.
- **Direita — Inspector:** abas `Inputs | Agent | Tools | Outputs | Runtime` para nó AI Decision selecionado.
- **Painel inferior:** mensagens de validação, preview da chamada e alertas de compatibilidade.

**REGRA VISUAL:** O nó `AI Decision` é um **macrocomponente do Studio**, NÃO uma instrução nova da linguagem BPL. Sua tradução mínima é `call` a um Business Host dedicado + mapeamento/validação + `switch` nativo.

### 5.2. Ação de inserir AI Decision

**DE-01:** Usuário seleciona uma posição permitida no processo; o Studio insere um `AI Decision` visual.  
**DE-02:** O nó recebe `bindingId` estável, referência ao processo, identificador de atividade, revisão e estado `INCOMPLETE`.  
**DE-03:** O sistema abre automaticamente a aba Inputs do Inspector.  
**DE-04:** O nó só passa a `VALID` quando Inputs, agente, ferramentas, Outputs, rotas e fallback forem consistentes.  
**DE-05:** A exclusão de um nó gerenciado remove apenas os artefatos controlados pelo Studio, mediante confirmação e prévia de diferenças.

### 5.3. Inspector: ABA A — INPUTS

**PROPÓSITO:** Definir **o que o BPL envia** à execução do AI Hub.

**Campos e controles:**
- `Input source`: árvore tipada de `request`, `context`, valores constantes e campos disponibilizados por atividades anteriores.
- `Destination`: propriedades permitidas no envelope `DecisionRequest`/contexto do agente.
- `Required`, default/fallback para campo ausente e transformação simples validada.
- `Payload preview` com exemplo, tipos e campos redigidos por política.

**REGRAS:**
- **IN-01:** Atributos DEVEM ser selecionados a partir de metadados reais de classe (`%Dictionary`) ou do contexto BPL conhecido.
- **IN-02:** O usuário DEVE mapear explicitamente os dados enviados ao agente; NÃO transferir automaticamente o request completo.
- **IN-03:** Mapeamento com tipo incompatível, campo inexistente ou requerido não resolvido DEVE impedir publicação.
- **IN-04:** Campos sensíveis DEVEM permanecer excluídos por padrão, salvo autorização explícita na aplicação.
- **IN-05:** Preview NÃO é execução do LLM.

**EXEMPLO:** `request.EventId → input.eventId`; `request.Description → input.description`; `context.SourceSystem → input.sourceSystem`.

### 5.4. Inspector: ABA B — AGENT

**PROPÓSITO:** Configurar o **agente nativo** que tomará a decisão no ponto BPL.

**Controles:** selecionar agente existente ou criar configuração gerenciada; nome e descrição; seleção de Provider/Model previamente permitido; instruções do agente; parâmetros suportados; modelo de sessão por execução; referência da versão.

**REGRAS:**
- **AG-01:** O agente selecionado DEVE executar pelo SDK nativo `%AI.Agent` efetivamente disponível no build alvo.
- **AG-02:** A interface PODE salvar definição declarativa e traduzi-la para APIs compatíveis; campos visuais não implicam propriedades nativas de `%AI.Agent`.
- **AG-03:** O editor de instruções DEVE aceitar variáveis definidas nos Inputs e rejeitar referências inexistentes.
- **AG-04:** Provider e credenciais DEVEM ser configurados por meio seguro; NUNCA gravar chave em prompt, BPL ou repositório Git.
- **AG-05:** O agente reutilizável NÃO DEVE ser alterado silenciosamente em todos os workflows. Edição de definição compartilhada gera nova revisão/versão.

### 5.5. Inspector: ABA C — TOOLS

**PROPÓSITO:** Vincular **ToolSets autorizadas** ao agente.

**Controles:** descoberta de ToolSets suportadas no build; lista de ferramentas, parâmetros, schema de input/output, permissões, efeito `READ/WRITE`, timeout, habilitação por binding e explicação do impacto.

**REGRAS:**
- **TL-01:** MVP DEVE permitir **associar ToolSets já implementadas** e testadas; não exigir gerador arbitrário de código.
- **TL-02:** Por padrão, usar ferramentas de **leitura**; ferramentas com efeitos externos de escrita NÃO estarão disponíveis no MVP sem implementação explícita e governança adicional.
- **TL-03:** Policies e permissões DEVEM ser validadas no servidor; o prompt não concede privilégios.
- **TL-04:** Tool inexistente ou indisponível no build DEVE bloquear publicação.
- **TL-05:** A tela DEVE mostrar o que cada ferramenta consulta e quais dados podem retornar.

**MVP mínimo:** pelo menos uma ToolSet real de leitura invocada durante a demonstração.

### 5.6. Inspector: ABA D — OUTPUTS & BPL ROUTES

**PROPÓSITO:** Fazer a resposta estruturada do agente controlar **o BPL**, sem permitir execução livre de efeitos externos.

**Controles:** enum de ações aceitas, schema do retorno, mapeamento das propriedades para `context`/`response`, lista de Business Operations existentes, tabela de roteamento ação → destino, fallback obrigatório.

**Contrato de decisão mínimo proposto (não é schema nativo do AI Hub):**

```json
{
  "action": "REVIEW",
  "reason": "Insufficient evidence",
  "evidenceRefs": ["policy-17"]
}
```

**Envelope de resposta do adaptador (proposto):**

```json
{
  "executionStatus": "SUCCESS",
  "action": "REVIEW",
  "reason": "Insufficient evidence",
  "evidenceRefs": ["policy-17"],
  "correlationId": "evt-1042",
  "agentExecutionId": "run-1042"
}
```

**Mapeamento conceitual:** `callresponse.Action → context.AIDecision`; `callresponse.ExecutionStatus → context.AIStatus`; `callresponse.Reason → context.AIReason`.

**REGRAS:**
- **OUT-01:** O retorno do LLM DEVE ser validado no servidor por schema/enum/tipos e regras de autorização.
- **OUT-02:** O adaptador DEVE diferenciar **ação proposta** de **status de execução**. Um erro não é uma ação de negócio válida.
- **OUT-03:** TODAS as ações possíveis DEVEM ter uma rota explícita ou um fallback seguro.
- **OUT-04:** O `switch` do BPL DEVE decidir o destino final, não o LLM por acesso arbitrário à Production.
- **OUT-05:** Saídas inválidas, desconhecidas ou incompletas DEVEM seguir a rota `REVIEW/FALLBACK` e ser registradas.
- **OUT-06:** Regras que avaliam score do LLM NÃO DEVEM tratá-lo como probabilidade calibrada.

**ROTEAMENTO DEMONSTRATIVO:** `PROCESS → ProcessOperation`; `REVIEW → ReviewOperation`; `REJECT → RejectOperation`; `INVALID/TIMEOUT/ERROR → FallbackOperation`.

### 5.7. Inspector: ABA E — RUNTIME & FAILURE

**PROPÓSITO:** Definir limites e recuperação de erros.

**Controles:** timeout da invocação, limite de iterações/tool calls quando suportado, modo da sessão por mensagem, fallback, logging/correlação, política de retry segura quando cabível.

**REGRAS:**
- **RT-01:** Sessão isolada por mensagem como padrão para impedir contaminação de contexto.
- **RT-02:** Timeout e falha do Provider DEVEM terminar em caminho determinístico.
- **RT-03:** Repetição da mesma mensagem NÃO DEVE duplicar efeitos externos sem controle de idempotência.
- **RT-04:** Chamadas síncronas longas DEVEM considerar pool de jobs e limites do Business Host.
- **RT-05:** Alterações de runtime criam nova revisão; jamais modificar mensagens já em processamento.

**ACEITE T-02:** um usuário configura um `AI Decision` sem escrever código para o binding, e o Studio consegue gerar uma versão compilável do trecho BPL gerenciado com Inputs, ToolSet e Outputs válidos.

---

## 6. TELA T-03 — WORKFLOW TEST & TRACE

**FINALIDADE:** Evidenciar o comportamento real do workflow de interoperabilidade.

### 6.1. Áreas

- **Test Input:** formulário/JSON derivado do Request Class; escolha do cenário e botão `Execute Live`.
- **Execution Timeline:** Business Service → BPL Input Mapping → AI Hub Agent → Tool Calls → Decision Validation → BPL Route → Business Operation.
- **Details:** payload redigido, decisão, justificativa, evidências, IDs, erro/fallback, latência, versão publicada e custo/tokens quando disponibilizados.

### 6.2. Comportamentos vinculantes

- **TS-01:** O botão `Execute Live` DEVE acionar **um Business Service real da Production** em ambiente de teste.
- **TS-02:** O sistema DEVE diferenciar visualmente resultados **LIVE** dos simulados ou replay.
- **TS-03:** A UI DEVE correlacionar `messageId`, session/correlation ID da Interoperability, `decisionBindingId` e identificador da invocação agêntica.
- **TS-04:** Tool calls internas só aparecerão se o adaptador/AI Hub fornecer dados capturados; NÃO presumir que o Visual Trace as registra automaticamente.
- **TS-05:** O usuário DEVE conseguir abrir o Visual Trace nativo para investigação complementar, quando disponível.
- **TS-06:** Testes de erro DEVEM mostrar de forma explícita se o BPL acionou a rota de fallback.

### 6.3. Testes mínimos

`TC-01` decisão válida `PROCESS`; `TC-02` decisão válida `REVIEW`; `TC-03` resposta fora do enum; `TC-04` Provider indisponível; `TC-05` Tool não autorizada; `TC-06` campo obrigatório ausente; `TC-07` mensagem duplicada.

**ACEITE T-03:** ao menos dois eventos de entrada distintos geram decisões observavelmente distintas por execução real do `%AI.Agent`, com uma Tool real consultada e destinos BPL identificáveis.

---

## 7. TELA T-04 — WORKFLOW PUBLISHER

**FINALIDADE:** Publicar o **workflow**, não o agente isolado.

### 7.1. Painéis e etapas

- **Readiness:** build, namespace, Production, permissões, Provider/ToolSets disponíveis.
- **Dependency Review:** BPL class, Request/Response, Business Host AI Bridge, Agent Definition/Version, ToolSets, Business Operations.
- **Diff:** comparação da classe BPL e dos bindings gerenciados frente à revisão anterior.
- **Compile & Activate:** geração controlada, compilação, configuração autorizada dos hosts e verificação.
- **History & Rollback:** revisão publicada, data, autoria, resultado e caminho de retorno.

### 7.2. Comportamentos vinculantes

- **PB-01:** `Validate` DEVE falhar se existir Input incompatível, Tool ausente, Output sem rota ou configuração sem fallback.
- **PB-02:** `Publish Workflow` DEVE solicitar confirmação após apresentar diff e dependências.
- **PB-03:** O Publisher DEVE operar inicialmente apenas em **processos gerenciados** ou alterações que preservem comprovadamente estruturas existentes.
- **PB-04:** A publicação DEVE registrar versões de workflow, agent definition e binding.
- **PB-05:** O sistema DEVE capturar erros de compilação sem alegar publicação bem-sucedida.
- **PB-06:** Atualização de Production ativa DEVE ser controlada e exigir aprovação administrativa quando necessário.
- **PB-07:** Rollback significa restauração de configuração/artefato compatível; NÃO desfaz efeitos externos já realizados.

**ACEITE T-04:** uma revisão validada é compilada e instalada em ambiente de demonstração, produzindo execução real rastreável.

---

## 8. CONTRATOS E REUTILIZAÇÃO

### 8.1. Entidades propostas da plataforma

| Entidade | Responsabilidade |
|---|---|
| `AgentDefinition` | Configuração versionada do agente AI Hub reutilizável |
| `ToolBinding` | ToolSets autorizadas na configuração do agente |
| `DecisionBinding` | Liga atividade de um BPL a um agente, Input/Output maps e políticas |
| `WorkflowRevision` | Snapshot da estrutura BPL e dependências gerenciadas |
| `ExecutionAudit` | Correlação de mensagem, agente, ferramentas, decisão e destino |
| `Publication` | Estado, verificação, diff e versão implantada |

**NOTA:** São modelos do Studio, NÃO classes oficiais de `%AI.*` ou `Ens.*`.

### 8.2. Reuso obrigatório

- O mesmo `AgentDefinition` PODE ser referenciado por múltiplos `DecisionBinding`.
- Cada BPL DEVE poder definir seus Inputs, Outputs e destinos de forma independente.
- O mesmo Business Host adaptador DEVE suportar vários bindings, sem exigir classe ObjectScript exclusiva por agente.
- Não alterar automaticamente referências já publicadas quando o agente receber nova versão.

### 8.3. Fronteira técnica do adaptador

**Business Process BPL** → `Studio.Msg.AgentDecisionRequest` (`Ens.Request`) → **Business Host reutilizável** → `%AI.Agent` com ToolSets → validação → `Studio.Msg.AgentDecisionResponse` (`Ens.Response`) → **BPL context + switch** → **Business Operations**.

Classes `Studio.*` são nomes **propostos**. Os pontos reais de invocação do SDK devem ser conferidos no build 154.

---

## 9. ADMINISTRAÇÃO E LOGÍSTICA — TECNOLOGIA

### 9.1. Arquitetura

**CONTROL PLANE:** Flask + templates/JavaScript canvas → WSGI em Embedded Python IRIS → serviços administrativos e `%Dictionary`/SQL.  
**EXECUTION PLANE:** Production `Ens.*` → BPL → Business Host AI Bridge → AI Hub nativo → BPL → Business Operation.

**RESTRIÇÃO:** O Flask NÃO DEVE executar workflow operacional, chamar LLM em substituição ao `%AI.Agent` ou simular encaminhamento de mensagens fora da Interoperability.

### 9.2. Hospedagem prioritária

Hospedar Flask pelo WSGI do IRIS se, **e somente se**, a imagem build 154 suportar e estiver configurada com Web Gateway e dependências do Python. Se falhar, hospedar Flask separadamente e preservar os mesmos contratos administrativos; o runtime continuará no IRIS.

### 9.3. Front-end

O canvas deve **visualizar estruturas reconhecidas** e suportar a inserção controlada de um macrocomponente AI Decision. NÃO implementar editor BPL universal. JavaScript especializado em grafos é permitido; Flask fornece HTML/API e persiste definições.

### 9.4. Segurança

- Autenticação e controle de acesso por namespace, Production, classe, ToolSet e papel.
- Credenciais de Provider por configuração segura, nunca em fonte, BPL ou log.
- Política padrão de acesso somente leitura às Tools.
- Validação de todas as entradas HTTP e das respostas do agente.
- Logs com redaction, timeout e limites de corpo/payload.
- Separar visualização, edição, publicação e administração por autorização.

---

## 10. COMANDO E CONTROLE — CRITÉRIOS GO/NO-GO

### 10.1. Dependências críticas

**GATE-00 — COMPATIBILIDADE:** confirmar SDK `%AI.*`, ToolSets, WSGI/Flask, Web Gateway e classes BPL do build 154.  
**GATE-01 — BRIDGE:** demonstrar `BPL → AI Hub Agent → BPL` com mensagem persistida e resposta real.  
**GATE-02 — INPUT/OUTPUT:** validar mappings e rotas para sucesso e erro.  
**GATE-03 — PUBLICAÇÃO:** compilar workflow gerenciado, ativar/usar na Production e rastrear mensagem.  
**GATE-04 — DEMO:** dois cenários vivos, mensagem→Tool→decisão→destino, reproduzíveis por terceiro.

**REGRA NO-GO:** Se o Gate 01 falhar, NÃO priorizar canvas ou estética. Corrigir a ponte AI Hub/Interop primeiro.

### 10.2. Critérios de aceitação globais

- **AC-01** Selecionar um BPL gerenciado real.
- **AC-02** Inserir e configurar um AI Decision no fluxo.
- **AC-03** Mapear pelo menos dois campos de entrada BPL para o agente.
- **AC-04** Selecionar Provider/Model e associar uma ToolSet nativa testada.
- **AC-05** Definir pelo menos duas decisões válidas e rota de fallback.
- **AC-06** Mapear ação/status para `context` e `switch` BPL.
- **AC-07** Validar e compilar os artefatos.
- **AC-08** Executar duas mensagens reais que sigam rotas distintas.
- **AC-09** Identificar no trace a mensagem, o agente, o uso de Tool e o destino.
- **AC-10** Reiniciar a aplicação e preservar configuração publicada.
- **AC-11** Reusar o mesmo agente em um segundo binding sem duplicar sua implementação.
- **AC-12** Bloquear publicação de Tool não autorizada e Output inválido.

### 10.3. Fora do MVP

**PROIBIDO COMO DEPENDÊNCIA DO PRAZO:** edição universal de BPL legado; alteração do editor nativo da InterSystems; designer completo de Production/DTL/Rules; novos adapters arbitrários; execução livre de ObjectScript/Python pelo LLM; multiagentes e Skills experimentais; editor RAG/AutoML; multi-tenant; marketplace; runtime de workflow em Flask.

### 10.4. Cronograma de ataque recomendado

- **Etapa I — Fundação:** build 154, uma Production, um BPL, Agent + ToolSet e ponte funcional.
- **Etapa II — Contratos:** Inputs, Outputs, binding versionado e fallback.
- **Etapa III — Telas:** Explorer; Designer + Inspector; Test & Trace; Publisher.
- **Etapa IV — Entrega:** compilação, smoke tests, Docker Compose, README em inglês, demonstração e roteiro de instalação.

**PRAZO:** submissão ao concurso até **08/11/2026, 23h59 EST**. Publicar repositório open source com código e documentação; a imagem EAP deve ser obtida pelo avaliador do portal autorizado, sem redistribuição pública da imagem ou derivações.

---

## 11. DISPOSIÇÕES FINAIS

**DEFINIÇÃO DE VITÓRIA:** Um avaliador abre um BPL no Studio, configura o bloco AI Decision e seus Inputs/Outputs, publica um workflow nativo e observa uma mensagem real cujo encaminhamento é determinado pela decisão de `%AI.Agent` após uso de ToolSet autorizada.

**FRASE DE PRODUTO:** *Extend BPL visually with native AI Hub decisions, without replacing InterSystems Interoperability.*

**FONTES:**
1. Concurso: https://community.intersystems.com/post/intersystems-programming-contest-ai-agents-interoperability-workflows
2. BPL Editor: https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=EBPL_editor
3. Interoperability: https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=EGDV
4. AI Hub EAP: https://github.com/intersystems-community/ai-hub-eap
5. AI Hub SDK: https://github.com/intersystems-community/ai-hub-eap/blob/master/ObjectScript_SDK_Guide.md
6. IRIS WSGI: https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=AWSGI

**CLASSIFICAÇÃO TÉCNICA:** Documento de requisitos e arquitetura proposta. Não constitui prova de compilação nem de compatibilidade do SDK com a imagem EAP 154 até validação em execução.
