# Plano de evolução visual do Agentic BPL Studio

Criado: 31/10/2026. Atualizado: 01/11/2026. Status: implementação entregue; validação LIVE nova bloqueada por autorização. Evidência e critérios atualizados na seção 14.

## 1. Objetivo e limites desta entrega

Evoluir o Designer existente para selecionar uma Production e um processo BPL, visualizar seus pontos de IA, trocar agentes por arrastar e soltar e editar prompts no painel lateral, preservando contratos, revisões e publicação controlada.

As seções 2–13 preservam o diagnóstico e planejamento originais. Após solicitação explícita de implementação, foram alterados os componentes descritos na seção 14. A validação usa a instância local e dados sintéticos; uma nova chamada LIVE foi bloqueada pela revisão automática de autorização e não foi executada.

Business Service é o componente de entrada; o processo BPL é um Business Process. A navegação principal será Production → processo BPL. Service será um filtro/contexto posterior quando suas relações forem identificáveis.

## 2. Evidência e verificação realizada

Foram examinados templates, JavaScript, rotas Flask, workspace Embedded Python, leitor BPL, testes e registros de validação. Os especialistas em `agents/` são instruções de engenharia, não agentes de runtime implantados.

Fontes principais:

- [Explorer](backend/studio/templates/explorer.html), [Designer](backend/studio/templates/designer.html) e [interações](backend/studio/static/studio.js).
- [API](backend/studio/api/routes.py), [workspace](backend/studio/native/workspace.py) e [validação de contratos](backend/studio/services/validation.py).
- [BPLReader](src/iris/Studio/Admin/BPLReader.cls), [ControlPlane](src/iris/Studio/Admin/ControlPlane.cls) e [Workspace nativo](src/iris/Studio/Admin/Workspace.cls).
- [Testes de UI](tests/test_ui.py), [API](tests/test_api.py) e [componentes independentes](tests/test_portable_components.py).
- [Estado de implementação](SPEC/IMPLEMENTATION_STATUS.md) e [evidência histórica de dois agentes](validation/native-free-agents.json).

O build registrado no projeto é `2026.3.0AI.154.0`; sua presença e configuração atuais não foram verificadas na instância nesta análise. O registro histórico mostra dois agentes em execução LIVE, mas não comprova disponibilidade atual.

A tentativa de executar `python -m pytest -q tests/test_ui.py tests/test_api.py tests/test_portable_components.py` não iniciou: o executável Python resolvido em WindowsApps estava inacessível. Os testes foram inspecionados, não executados com sucesso nesta revisão. Parte deles usa mocks e não substitui validação no IRIS ou no navegador.

Há documentação histórica divergente: `SPEC/README.md` ainda descreve integração não testada, enquanto `SPEC/IMPLEMENTATION_STATUS.md`, código e registros descrevem evolução posterior. A especificação mestre também preserva requisitos originais anteriores à publicação de Operations independentes. Na implementação futura, reconciliar esses textos; não tratar inventários históricos como estado atual.

## 3. Inventário do que já existe

| Capacidade | Evidência no código | Limite atual |
|---|---|---|
| Seleção de Production e BPL | Explorer; `list_workflows` no workspace | Não há navegação por Business Service na UI examinada |
| Catálogo de agentes e revisões | `GET /agents`; seletores no Explorer/Designer | Não é uma biblioteca visual arrastável |
| Edição de prompt, modelo e provider | Aba Agent; `PUT /agents/<id>` | Salvar revisão e salvar vínculo são etapas distintas |
| Troca do agente vinculado | Seletor e `PUT /bindings/<id>` | Aplicável ao fluxo gerenciado e vínculo único |
| Ferramentas autorizadas | Aba Tools e registro nativo | Configuração atual exige READ ToolSets autorizados |
| Entradas, saídas, rotas, timeout e fallback | Inspector e validação do workspace | Contratos limitados aos templates suportados |
| Visualização de atividades | `renderGraph` em `studio.js`; BPLReader | Cartões e lista de conexões; não é um canvas livre |
| Inserção de decisão | `/decision-slot` | Apenas um slot reconhecido por workflow gerenciado |
| Múltiplos agentes em BPL nativo | Operations independentes e registro LIVE histórico | Composição no editor nativo; não é edição multiponto no Designer |
| Versionamento e publicação | Revisões, snapshots, diff e hosts de release | Reutilizar, sem criar outro mecanismo de publicação |
| Controle de concorrência | `If-Match`, revisões, hashes e lock de workspace | Evoluir para novos contratos preservando proteções |
| Restauração | Rollback gera novo rascunho | Não equivale a desfazer/refazer edição local |
| Rastreamento | Test & Trace e consulta por Execution ID | Falta navegação consolidada do ponto visual ao histórico |

Não foram encontrados handlers de arrastar e soltar, histórico local de desfazer/refazer, análise visual consolidada dos consumidores de agentes ou modelo gerenciado com múltiplos bindings.

### Limitações adicionais verificadas

- O workspace armazena `binding` singular; a geração de BPL usa esse vínculo. Suporte multiponto exige mudança de contrato, persistência, geração e publicação, não apenas UI.
- O leitor BPL gera IDs `activity-N` pela ordem de leitura. Esses IDs não são estáveis após mudanças estruturais; não devem ser usados como identidade persistente de um ponto editável.
- O parser trata explicitamente sequência, switch, call e scope. Isso não demonstra representação completa de loops, paralelismo ou todas as construções BPL. Elementos sem interpretação completa devem ser apresentados como opacos/somente leitura, sem inventar conexões.
- A leitura de XData atualmente usa um limite de 100000 caracteres. Fluxos maiores precisam de tratamento explícito de tamanho/truncamento antes de ampliar a edição.
- A publicação de componentes independentes rejeita nome de host já existente. Não existe, nesse caminho, substituição automática de uma Operation instalada.
- Fonte gerenciada alterada externamente perde editabilidade por comparação de hash. Preservar esse comportamento.

## 4. Princípios arquiteturais

1. IRIS continua responsável pela mensageria e BPL; AI Hub executa agentes; Flask administra configuração.
2. Não alterar classes de sistema `Ens.*`, `EnsPortal` ou `%AI.*`.
3. Layout visual é separado da semântica de execução. Arrastar um cartão de posição não reordena atividades BPL.
4. Soltar um agente modifica o vínculo do rascunho, não publica nem ativa a alteração.
5. Revisões publicadas permanecem fixadas. Editar prompt cria nova revisão; outros consumidores não migram automaticamente.
6. Elementos desconhecidos e referências dinâmicas não resolvidas permanecem explícitos e protegidos contra edição.
7. Validação no navegador ajuda a interação; autorização e validação no servidor continuam obrigatórias.
8. Session de Interoperability e Session de AI Hub são identidades distintas, correlacionadas por evidência.
9. Restauração de configuração não desfaz efeitos externos de mensagens já processadas.
10. Preservar o namespace autorizado atual; seleção multinamespace não será introduzida sem necessidade e validação próprias.

## 5. Experiência proposta

```text
Production → Processo BPL → Identificação dos pontos editáveis

Catálogo de agentes     Fluxo                      Inspector
Agente A @ revisão     Service/contexto            Agente e revisão
Agente B @ revisão →   [Ponto de IA selecionado]   Prompt e ferramentas
Busca e filtros        Rotas e Operations         Entradas/saídas/fallback

Editar rascunho → Validar → Comparar → Publicar → Inspecionar execução
```

- Destinos compatíveis ficam destacados durante o arraste; destinos inválidos exibem motivo.
- Soltar sobre o ponto existente propõe substituir seu agente. Soltar sobre slot vazio usa a inserção reconhecida, com a política de persistência explicitada na UI.
- Selecionar um ponto abre o Inspector existente, mantendo suas cinco abas.
- Ações equivalentes por botão e teclado são obrigatórias.
- Exibir claramente: alterações locais, vínculo salvo, revisão publicada e estado de ativação conhecido.
- Se salvar a revisão do agente funcionar e salvar o vínculo falhar, informar que a revisão foi criada, mas ainda não está vinculada; permitir retomar sem duplicá-la.
- Desfazer/refazer inicial atua apenas nas alterações locais. Não remove revisões persistidas nem desfaz publicações.
- A interface atual é em inglês. Preservar o idioma no primeiro incremento; tradução é escopo separado.

## 6. Requisitos e critérios de aceite

| ID | Requisito | Aceite verificável |
|---|---|---|
| RF01 | Selecionar processo no contexto da Production | A seleção abre o processo correto e mantém sua identidade de host/classe |
| RF02 | Mostrar estrutura e limites de edição | BPL desconhecido permanece somente leitura com motivo visível |
| RF03 | Substituir agente por arraste ou teclado | Ambos produzem o mesmo rascunho; nenhuma publicação é disparada |
| RF04 | Editar prompt com revisão | Nova revisão é criada; releases anteriores mantêm a revisão original |
| RF05 | Validar compatibilidade | Entradas, saídas, ações, tools e políticas incompatíveis impedem salvamento/publicação conforme a regra aplicável |
| RF06 | Preservar concorrência | Revisão/hash desatualizado gera conflito explícito, sem sobrescrita silenciosa |
| RF07 | Isolar consumidores | Alterar o ponto A não muda o ponto B ou outro fluxo que compartilhe revisão/Operation |
| RF08 | Suportar múltiplos pontos na segunda etapa | Dois pontos no mesmo BPL usam agentes/revisões independentes e preservam seus mapeamentos |
| RF09 | Correlacionar execução | Inspeção identifica ponto, release e revisão executada quando a instrumentação fornece esses dados |
| RF10 | Preservar histórico local | Desfazer/refazer restaura o rascunho sem alterar o estado publicado |
| RF11 | Tratar dependências incompletas | Referências dinâmicas são marcadas como não resolvidas, sem alegar inventário completo |
| RF12 | Preservar dados e autorização | Nenhuma credencial é exposta no catálogo, prompt, diff ou trace; mutações continuam protegidas |

## 7. Modelo e contratos a evoluir

Nomes abaixo são conceitos propostos da aplicação, não novas APIs oficiais do IRIS.

| Conceito | Informação necessária | Decisão |
|---|---|---|
| Contexto do fluxo | Namespace autorizado, Production, host, classe, hash | Não usar apenas nome da classe como identidade do uso |
| Ponto de IA | Identidade estável, atividade de origem, binding e capacidade de edição | Definir estratégia antes do suporte multiponto |
| Binding | Agente/revisão, inputs, outputs, routes, fallback, timeout | Reutilizar contrato atual no primeiro incremento |
| Configuração do agente | ID, revisão, prompt, provider/model, ToolSets | Reutilizar revisão persistida existente |
| Rascunho visual | Alterações pendentes, revisão base e layout opcional | Layout não muda BPL; limites de undo explícitos |
| Dependência | Consumidor, Operation, agente/revisão e grau de resolução | Distinguir leitura estática de configuração observada |
| Publicação | Snapshot dos bindings e identidades implantadas | Manter releases anteriores legíveis e executáveis |

Primeiro incremento: reutilizar `/productions`, `/workflows`, `/agents`, `/toolsets`, `/bindings`, validação, preview e publicação existentes. Não criar endpoints duplicados para os mesmos comportamentos.

Segundo incremento: especificar versionamento do schema para coleção de bindings, identidade dos pontos e consulta de dependências. Desenhar migração compatível: o vínculo único atual torna-se um ponto na representação nova, sem reescrever releases históricos. Atualizar `contracts/openapi.yaml` e schemas somente na futura implementação.

Operations compartilhadas: a política proposta é preservar o host existente e publicar uma configuração isolada para o consumidor alterado, com mudança explícita da chamada somente em BPL editável. Não atualizar silenciosamente um host compartilhado. A estratégia exata de geração de classe/host deve ser validada antes dessa etapa.

## 8. Mapa de implementação por fases

### Fase 0 — Consolidar especificação e baseline

- T01: reconciliar requisitos antigos com o inventário deste plano.
- T02: verificar build, namespace, classes e permissões no ambiente destinado aos testes.
- T03: disponibilizar Python válido e executar a suíte existente; distinguir testes com mocks de testes nativos.
- T04: documentar matriz de construções BPL suportadas e limites do parser.

Saída: baseline reproduzível e decisões técnicas registradas. Dependência: nenhuma implementação visual antes de entender os contratos atuais.

### Fase 1 — Fatia visual sobre o vínculo único existente

- T05: acrescentar catálogo visual, seleção e destaque do ponto gerenciado.
- T06: implementar substituição por arrastar/soltar com alternativa por teclado.
- T07: conectar a seleção ao Inspector e reutilizar salvamento de revisão e binding.
- T08: apresentar estado pendente/salvo/publicado e erros parciais entre salvamentos.
- T09: adicionar desfazer/refazer local e proteção de navegação com alterações pendentes.
- T10: verificar rejeição de destinos inválidos e preservação de conflitos no servidor.

Arquivos previstos: templates Explorer/Designer, `studio.js`, `style.css` e testes de UI/interação. Separar módulos visuais se necessário, sem impor migração de framework.

Saída: RF01–RF06, RF10 e RF12 demonstrados no fluxo gerenciado atual. Não requer geração de BPL arbitrário nem múltiplos bindings.

### Fase 2 — Identidade, dependências e múltiplos pontos

- T11: definir IDs estáveis e vínculo inequívoco entre atividade, host e configuração.
- T12: especificar e implementar coleção versionada de bindings com compatibilidade de leitura.
- T13: ampliar introspecção de Operations e consumidores, marcando referências não resolvidas.
- T14: ampliar gerador e validação apenas para as estruturas BPL suportadas.
- T15: permitir escolha independente de agente, prompt e mapeamentos por ponto.
- T16: implementar política de isolamento de Operations compartilhadas e relatório de impacto.

Arquivos previstos: `BPLReader.cls`, `Workspace.cls`, `workspace.py`, contratos/schemas, validação, gateway, rotas e interface. Revisar o runtime que hoje recebe o binding fixado na release.

Saída: RF07, RF08 e RF11; dois pontos independentes e nenhum consumidor alterado por efeito colateral. Pré-condição: fase 1 aceita e contratos multiponto revisados.

### Fase 3 — Publicação e observabilidade multiponto

- T17: ampliar diff e manifest de release para apresentar todos os pontos e impactos.
- T18: preservar hashes, revisões, locks, idempotência e tratamento de falhas parciais na publicação.
- T19: correlacionar ponto visual com execução, revisão e sessões efetivamente observadas.
- T20: verificar recuperação por novo rascunho e comportamento de mensagens já em andamento.
- T21: atualizar documentação e roteiro de operação.

Arquivos previstos: Publisher, Test & Trace, `trace-view.js`, workspace e classes de trace/runtime conforme necessidade demonstrada.

Saída: RF09 e publicação multiponto verificável, sem alterar semântica de releases existentes.

### Evoluções posteriores

- Navegação Service → processos quando referências forem resolvíveis.
- Biblioteca de agentes com filtros de uso e histórico agregado.
- Ampliação de construções BPL editáveis após testes de preservação semântica.

Fora do primeiro escopo: editor BPL universal, edição livre de qualquer XML, substituição do editor nativo, multinamespace, novos provedores, RAG, Vector Search e IntegratedML.

## 9. Responsabilidades dos especialistas

| Referência | Responsabilidade futura |
|---|---|
| [iInteroperability](agents/iInteroperability.agent.md) | Contratos de mensagens, BPL, hosts, publicação, timeout e impacto em consumidores |
| [IA_HUB](agents/IA_HUB.agent.md) | Revisões, prompts, ToolSets, validação determinística e evidências de execução |
| [iris.Dictionary](agents/iris.Dictionary.agent.md) | Introspecção, identidade de atividades, XData, limites do parser e referências não resolvidas |
| [iEmbeddedPython](agents/iEmbeddedPython.agent.md) | API, workspace, serialização, concorrência e compatibilidade Python–IRIS |
| [docker.iris](agents/docker.iris.agent.md) | Baseline de build e ambiente de testes quando essa etapa for executada |

Essas responsabilidades constituem o mapa de revisão; não significam que especialistas foram executados em paralelo nesta entrega.

## 10. Organização no estilo Spec Kit

Este plano aplica desenvolvimento orientado a especificações. Não foi identificado diretório `.specify` na inspeção anterior e o toolkit não foi instalado ou executado. Não presumir comandos disponíveis.

| Etapa de engenharia | Entrega futura | Gate |
|---|---|---|
| Princípios | Constituição ou seção equivalente alinhada à especificação existente | Limites de edição e runtime definidos |
| Especificação | Histórias, RFs e critérios deste plano refinados em `spec.md` da feature | Necessidades separadas de decisões técnicas |
| Esclarecimento | Registro de decisões e questões pendentes | Nenhuma ambiguidade bloqueante na fase a iniciar |
| Planejamento | `research.md`, `plan.md`, `data-model.md` e contratos da feature | Compatibilidade e migração descritas |
| Tarefas | `tasks.md` com RFs, dependências e evidência esperada | Cada tarefa verificável e com escopo limitado |
| Análise de consistência | Checklist requisito → contrato → tarefa → teste | Sem lacunas críticas |

Preservar `spec.md` mestre e `SPEC/` existentes; escolher um diretório de feature sem sobrescrever documentos históricos. A criação desses artefatos detalhados pertence à próxima etapa documental, não foi realizada neste arquivo.

Referência metodológica: [GitHub Spec Kit](https://github.com/github/spec-kit). Referências técnicas gerais: [editor BPL](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=EBPL_editor) e [AI Hub SDK](https://github.com/intersystems-community/ai-hub-eap/blob/master/ObjectScript_SDK_Guide.md). Documentação móvel não comprova compatibilidade com o build instalado.

## 11. Plano de verificação futura

| Nível | Cenários | Evidência exigida |
|---|---|---|
| UI/browser | Arraste válido/inválido, teclado, prompt, undo, troca de processo | Resultado do rascunho e ausência de publicação automática |
| API | Schema, autorização, CSRF, revisão desatualizada, falha parcial | Respostas corretas e nenhum estado sobrescrito indevidamente |
| Parser | Switch, calls, conteúdo opaco, fonte grande e referências dinâmicas | Estrutura conhecida correta; limites explicitamente sinalizados |
| Persistência | Binding único legado, multiponto, revisões compartilhadas | Compatibilidade e isolamento entre consumidores |
| IRIS | Compilação, instalação, execução SIMULATION e fallback | Mensagens e releases correlacionados |
| AI Hub LIVE | Duas revisões/pontos e ToolSets instrumentados | Sessões, revisão usada e chamadas realmente observadas |
| Publicação | Alteração externa, conflito, repetição idempotente, Production parada | Nenhum sucesso/ativação declarado sem confirmação |

SIMULATION valida a integração com decisões determinísticas; não comprova chamada ao modelo. Testes LIVE exigem ambiente e credenciais configurados e não devem ser disparados ao salvar prompts.

## 12. Riscos e decisões antes de cada incremento

| Risco | Tratamento planejado |
|---|---|
| Canvas sugerir semântica BPL incorreta | Limitar renderização semântica e explicitar elementos opacos |
| IDs mudarem após edição | Definir identidade estável antes de persistir múltiplos pontos |
| Troca afetar Operation compartilhada | Preservar host; isolar configuração e mostrar consumidores |
| Migração quebrar releases | Leitura compatível e snapshots históricos preservados |
| Fonte truncada/complexa | Detectar limite e bloquear edição até leitura íntegra |
| Timeout aparentar cancelar o provedor | Não prometer cancelamento; verificar comportamento real do runtime |
| Estado publicado divergir do rascunho | Mostrar revisões e revalidar hashes na publicação |

Escolha de biblioteca gráfica: pendente de avaliação de acessibilidade, integração com JavaScript existente, licença, tamanho e manutenção; não há dependência escolhida neste plano.

Desempenho: medir tamanho real dos fluxos e estabelecer metas de carregamento/interação antes da escolha da biblioteca. Não assumir que o canvas suporta qualquer volume.

## 13. Definição de conclusão

O primeiro incremento estará concluído quando o usuário puder escolher um fluxo gerenciado, trocar o agente por arraste ou teclado, editar o prompt em nova revisão, salvar o vínculo, revisar e publicar pelo mecanismo existente, com testes de conflito e preservação das releases anteriores.

A evolução completa estará concluída quando múltiplos pontos forem editáveis com identidade estável, isolamento de consumidores, publicação consistente e rastreabilidade por ponto, sem remover o modo somente leitura de estruturas não suportadas.

Situação na criação original deste plano: somente documentação. A execução posterior está registrada abaixo.

## 14. Implementação e verificação realizada

### Decisões consolidadas

- Blocos encaixáveis tipo LEGO: catálogo arrastável, portas IN/OUT, substituição no ponto e encaixe `+` para acrescentar decisões. O mesmo fluxo é acessível por botões e teclado. A posição visual não reordena execução.
- Reutilização de JavaScript, HTML/CSS e Inspector existentes; nenhuma biblioteca gráfica adicional. Máximo de oito decisões ordenadas por rascunho. Cada decisão executa sua rota; a próxima roda somente após sucesso. Falha usa fallback e encerra a sequência.
- Inspector lateral com prompt, tools e mapeamentos por ponto. Histórico local com até 50 estados. Salvar revisões não chama o modelo; publicação continua no Publisher.
- `bindingId` identifica persistentemente cada ponto, independentemente dos IDs transitórios da projeção XML. Novos pontos usam ID único dentro do workflow.
- Schema de workflow 2: coleção `bindings`, alias legado `binding` e snapshot `agents` por ponto. Leitura de releases anteriores preservada; nenhuma migração destrutiva.
- Isolamento pelo manifest imutável e pelo host BPL específico da release. A Operation compartilhada `AgentDecision` resolve o binding pelo ReleaseId/BindingId; sua configuração não é substituída. Operations independentes e BPLs arbitrários continuam no caminho nativo, somente leitura no Designer.
- API `PUT /workflows/{workflowId}/bindings` salva a coleção inteira sob o lock existente, com revisão esperada, autorização, CSRF, validação de contrato, tools, mapeamentos e destinos. ID de outro workflow, duplicidade e excesso de pontos são recusados.
- Catálogo corrigido para retornar todas as revisões, incluindo a revisão mais recente conhecida para criação de uma nova versão. O estado de publicação nunca muda apenas por selecionar um bloco.
- Salvamento parcial é recuperável: se a revisão do agente persistir e o binding falhar, a referência local é mantida para retry sem criar revisão duplicada. Controles ficam bloqueados durante o salvamento.
- Contexto anterior (`Action`/`Reason`) é passado ao próximo ponto pelo Envelope. Preview usa valores de exemplo explicitamente identificados como validação de schema, não evidência de execução.
- Introspecção distingue referências estáticas instaladas, consumidores registrados e alvos dinâmicos/não resolvidos. Não afirma inventário completo de consumidores externos.
- Leitor BPL protege tamanho (1.000.000 caracteres), profundidade (64) e quantidade de elementos (10.000). Atividades desconhecidas são opacas, sem inferir corpo ou conexões internas.

### Matriz de implementação

| Tarefas | Estado | Evidência/decisão |
|---|---|---|
| T01 | Concluída | `spec.md`, `SPEC/README.md` e status reconciliados; histórico preservado |
| T02 | Concluída | IRIS 2026.3.0AI Build 154U, namespace USER; acesso nativo e web autenticado verificados |
| T03 | Concluída | Python `.venv` 3.12.14; baseline 139 e suíte final 150 testes aprovados |
| T04 | Concluída | Parser testável em `native/bpl.py`; limites e atividades opacas cobertos |
| T05–T07 | Concluídas | Catálogo, encaixes, drag, teclado e Inspector por ponto |
| T08–T10 | Concluídas | Estado salvo/pendente, histórico local, conflito e retry parcial verificados |
| T11–T12 | Concluídas | IDs estáveis, coleção versionada, snapshots e compatibilidade com vínculo único |
| T13 | Concluída no escopo limitado | Consumidores registrados e referências estáticas; lacunas dinâmicas explícitas |
| T14–T16 | Concluídas | BPL multiponto compilado, mapeamento de contexto, revisões independentes e hosts preservados |
| T17–T18 | Concluídas | Diff/manifest multiponto; hashes, revisão, lock, idempotência e recuperação existentes mantidos |
| T19 | Implementada; LIVE pendente | Trace por ponto verificado em SIMULATION e no navegador; sessão/tool LIVE nova não verificada |
| T20 | Concluída em SIMULATION | Rollback cria rascunho; resposta tardia não muda TIMEOUT final |
| T21 | Concluída | Guia operacional abaixo, README e status atualizados |

### Critérios funcionais

| Critério | Verificação |
|---|---|
| RF01 | Production/processo no Designer; hosts não gerenciados usam identidade contextual `host:Production|Host` |
| RF02 | UI somente leitura e parser opaco; proteção repetida no servidor |
| RF03 | Drag real por ponteiro e conexão por teclado; nenhuma release criada ao salvar |
| RF04 | Nova revisão persistida; referências dos outros pontos preservadas |
| RF05 | Schema e validações nativas; ToolSets READ, rotas, fallback, inputs e outputs |
| RF06 | Conflito de binding e hash de fonte testados, sem sobrescrita |
| RF07–RF08 | Dois pontos executam revisões 1 e 2; edição não modifica snapshot anterior |
| RF09 | Tela Test & Trace mostra ID do ponto, revisão, release, observações e estado; ferramentas aparecem apenas quando capturadas |
| RF10 | Undo/redo de substituição e prompt no navegador; seleção sem edição mantém estado salvo |
| RF11 | Referências não resolvidas identificadas; `complete:false` explícito |
| RF12 | Autorização/CSRF existentes preservados; payloads de trace redigidos; nenhuma credencial em artefatos |

### Evidências executadas

- `python -m pytest -q` pela `.venv`: **150 passed**.
- `node --check backend/studio/static/studio.js` e teste `tests/test_trace_view.js`: aprovados.
- Classes modificadas compiladas no IRIS, com retorno de status verificado. Houve uma falha intermediária de sintaxe ObjectScript, corrigida antes da validação final.
- [Teste nativo multiponto](tests/iris/VisualDesignerTest.cls): duas revisões, contexto obrigatório entre pontos, rejeição de fonte/revisão obsoleta, idempotência, preservação de release e restauração.
- [Evidência nativa](validation/visual-designer-native.json): SUCCESS com dois pontos; erro simulado interrompe após o primeiro; timeout real de 1 segundo vence resposta sintética de 2 segundos. A resposta tardia aparece com status próprio e `workflowStatus:TIMEOUT`.
- Testes nativos legados: WorkspaceTest passou **17 checks**; InputMapperTest retornou sucesso. A release instalada em Production parada reportou `activated:false`, sem alegar ativação.
- [Teste de navegador](scripts/test-visual-designer.py): Edge real/Playwright, dados isolados, drag, teclado, undo/redo, prompt, falha parcial injetada e retry, revisão fixa, bloqueio read-only e trace de mensagem SIMULATION. [Resultado](validation/visual-designer-browser.json), [captura visual](validation/screens/visual-blocks.png).
- Carregamento observado de aproximadamente **0,85 s** para o fluxo de dois pontos no ambiente local. É uma amostra de teste, não benchmark geral. Biblioteca gráfica não adicionada; suporte permanece limitado aos oito blocos e aos limites de inspeção documentados.

### Operação e reprodução

1. Compilar as classes alteradas na instância autorizada; não recarregar a definição original da Production sobre hosts já instalados.
2. Recarregar os workers WSGI após mudanças de Python/templates. Nesta validação, o container local foi reiniciado para limpar caches. Isso deixa a Production sintética parada; ela foi iniciada explicitamente para testes de mensageria.
3. No Designer, escolher Production/processo; selecionar ou arrastar a revisão do agente; conferir prompt, inputs e rotas no Inspector.
4. Usar `Save all blocks`; depois validar e revisar no Publisher. Ativação só ocorre quando confirmada pelo IRIS na Production em execução.
5. Usar Execution ID em `Inspect selected block` para abrir o Test & Trace. Uma conclusão tardia do agente não revoga o timeout do workflow.
6. Para reproduzir UI: instalar Playwright somente no ambiente de testes e executar `scripts/test-visual-designer.py` com Edge disponível. O script usa a credencial local sem imprimi-la, cria agentes/draft sintéticos e, se houver receipt nativo, envia uma mensagem SIMULATION. Não publica nem chama o modelo.
7. Para reproduzir runtime: carregar `tests/iris/VisualDesignerTest.cls` e executar `Run(0)` com a Production sintética em execução. `Run(1)` requer autorização LIVE explícita; não foi executado nesta entrega.

### Bloqueio restante

A revisão automática rejeitou o teste LIVE por envolver envio a provedor, possível cobrança e execução de ferramentas sem autorização explícita para destino e payload. Não foi usado caminho alternativo para contornar essa decisão. O teste preparado usaria OpenAI/gpt-4.1-mini, evento sintético `E-OK`, descrição de regressão sintética e ToolSet READ `Studio.Tools.EventReadTools`, em duas revisões isoladas. Exige autorização antes de execução.

Portanto, a implementação e a validação local/sintética foram concluídas; a aceitação integral que exige nova execução LIVE permanece pendente. Evoluções explicitamente posteriores da seção 8 (navegação por Service, editor BPL universal, novos domínios) continuam fora deste incremento.
