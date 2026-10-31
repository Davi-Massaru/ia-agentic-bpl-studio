# DPI-I-689 — rastreabilidade de pipelines GenAI no IRIS

## Objetivo e critério de aderência

Usar mensagens persistentes e Visual Trace do IRIS Interoperability como base para investigar um pipeline GenAI, acrescentando observações das etapas da aplicação. Aderência à ideia não significa equivalência funcional ou superioridade ao Langfuse. A alegação de liderança de mercado no texto da ideia não foi adotada como resultado desta avaliação.

## Fundamentos do Langfuse consultados

Fontes oficiais consultadas em 28/10/2026:

- [Visão geral de observabilidade](https://langfuse.com/docs/observability/overview): captura de entradas/saídas, consumo, latência e etapas; recursos adicionais de avaliação, métricas e gestão de prompts.
- [Modelo de dados](https://langfuse.com/docs/observability/data-model): observações relacionadas por hierarquia, agrupadas em traces; sessões podem agrupar vários traces. A instrumentação usa OpenTelemetry e exportação em lotes.

O conceito relevante para este produto é separar o transporte nativo das etapas internas da IA. Uma sessão AI Hub não é uma sessão de mensagens IRIS. Uma chamada completa a `agent.Chat` também não equivale necessariamente a uma única chamada ao modelo: pode executar várias interações e ferramentas. Estatísticas agregadas não permitem reconstruir essas interações individualmente.

## Plano de implementação orientado pelos especialistas

1. **IA_HUB / iEmbeddedPython:** persistir observações com identificador, pai, tipo, timestamps UTC, duração, estado e metadados permitidos; instrumentar as fronteiras reais das Operations, SDK e ferramentas. Preservar falhas e redigir payloads.
2. **iInteroperability:** manter IDs de execução, correlação e sessão nativa separados; conservar mensagens e Visual Trace como evidência do transporte. Não fabricar IDs ou concluir que uma chamada enviada foi concluída.
3. **iris.VectorSearch:** acrescentar ferramenta READ de recuperação vetorial com SQL parametrizado, documentos identificáveis e scores observados. Validar no build instalado; usar fixture vetorial explicitamente sintética para testes determinísticos.
4. **iEmbeddedPython / interface:** recuperar observações pela API autenticada existente e exibir hierarquia, estado e duração em Test & Trace, mantendo compatibilidade com traces antigos.
5. **Validação:** testes Python de contratos, isolamento, redaction e falhas; compilação nativa; execução de Vector Search real com fixture; evidências salvas sem credenciais.

## Limites de comparação

O benefício arquitetural a avaliar é a investigação no mesmo ambiente que executa a integração e consulta os vetores. Isso pode reduzir a necessidade de correlacionar sistemas externos, mas não comprova menor custo, maior desempenho ou melhor experiência que Langfuse.

Não fazem parte desta entrega: compatibilidade de ingestão OTLP, substituição geral do Langfuse, avaliação automática de qualidade, datasets/experimentos, alertas, estimativa de custo por tabela de preços, dashboard agregado e captura de cada interação interna do provider. A captura de prompts e respostas completos exige política própria; a auditoria redigida não é uma cópia integral da conversa.

Vetores de fixture não demonstram qualidade de embeddings nem qualidade de respostas RAG. Uma aceitação semântica exige corpus representativo, modelo de embeddings identificado, perguntas de referência e avaliação dos documentos/respostas recuperados.


## Resultado implementado e verificado

- `Studio.Trace.Recorder` persiste observações limitadas a 64 por execução em `^StudioAudit`. A gravação é best-effort e não muda o resultado de negócio; não é uma garantia de entrega de telemetria. O desenho atual pressupõe um escritor por execução; não é coletor distribuído concorrente.
- Operations gerenciadas/portáteis e a chamada AI Hub possuem observações relacionadas. O SDK é registrado como `agent`, sem inventar spans de chamadas individuais ao LLM. Ferramentas de exemplo e recuperação possuem instrumentação própria.
- A API existente de consulta de execução inclui observações com a mesma autorização. Test & Trace exibe hierarquia, duração, estado e metadados usando texto seguro; registros anteriores continuam legíveis.
- `Studio.Tools.VectorReadTools.SearchFixtureVectors` executa SQL vetorial parametrizado sobre uma coleção sintética 3D. Registra coleção, métrica, dimensão, IDs retornados e scores, sem texto de documentos ou prompt.
- Compilação no IRIS AI build 154 concluída. Teste nativo executou `VECTOR_COSINE`, verificou ranking e persistência pai/filho. Evidência: [dpi-i-689.json](../validation/dpi-i-689.json). Esse teste não invocou provider.
- Suíte Python: 139 testes aprovados. Teste JavaScript: hierarquia, ciclos, valores ausentes e renderização segura aprovados.

### Reproduzir a aceitação vetorial

Carregue `tests/iris/TraceAcceptance.cls` no namespace USER e execute `Studio.Tests.TraceAcceptance.Run()`. O teste cria, se ausente, a tabela dedicada `StudioVector.TraceFixture` e insere dois registros sintéticos identificados por `dpi689-*`; não remove tabelas. O fixture deve ser instalado antes de autorizar esse ToolSet em um agente. A ferramenta não permite escolher tabela ou fornecer SQL.

### Parecer de aderência

A implementação cobre o núcleo de rastreabilidade nativa com observações internas e comprova uma recuperação vetorial real. Permanece **parcial** como alternativa geral ao Langfuse: falta validar um pipeline completo com provider e corpus semântico real, além das capacidades listadas em Limites de comparação. Não há benchmark que sustente superioridade. Mensagens nativas continuam submetidas às permissões/retenção do IRIS; a nova coleção de auditoria exige política operacional de retenção própria.

### Falha de regressão ainda aberta

O comando `scripts/native-smoke.ps1` foi executado e retornou `NATIVE_TEST_FAILED`, sem runs, na Production `Studio.BloodDemo.Production`, com release legado ativo. Resultado salvo em `validation/iris154.json`. A causa não foi isolada; não é possível atribuí-la à configuração ou à instrumentação. A aceitação completa do fluxo BPL permanece pendente.


## Revalidação completa em 28/10/2026

Consulte `validation/e2e-2026-10-28.json`. O ciclo HTTP em simulação passou depois da recuperação da Production e da instalação dos destinos locais exigidos. LIVE genérico e tutorial falharam; o log do container registrou `signal 11` em dois workers AgentDecision. A repetição de política também falhou. Portanto, a aceitação integral continua reprovada.

### Correção proposta, ainda não aplicada

Hipótese: inicializar Embedded Python pelo Recorder antes da chamada ao SDK pode participar do crash observado; ainda não há isolamento causal. Proposta revisável: substituir somente Start/Finish do Recorder por implementação ObjectScript equivalente, preservando assinatura, campos, limite de 64 observações e comportamento best-effort; manter Python para testes/recuperação vetorial. Primeiro compilar e testar contratos em processo isolado, depois atualizar o host de sandbox e executar uma única mensagem LIVE controlada. Se passar, repetir os cenários completos. Não limpar filas nem apagar mensagens suspensas.

A revisão automática bloqueou a alteração do núcleo de rastreamento combinada com atualização da Production e novo teste LIVE, por risco de interrupção após SIGSEGVs. Nenhuma dessas alterações propostas foi aplicada. A continuação dessa etapa depende de autorização do usuário para a intervenção na sandbox.


## Correção autorizada e reteste posterior

Recorder Start/Finish convertidos para ObjectScript. Passaram: HTTP, LIVE genérico (30/31), estoque (32/33/34), políticas, portáteis (sessão nativa 1257), BPL legado, Recorder nativo, 139 testes Python e JavaScript. Este resultado substitui a falha histórica acima. A causa interna do SIGSEGV não foi provada; os cenários reexecutados passaram após remover a inicialização de Python pelo Recorder antes do SDK. Ver relatório consolidado atualizado.
