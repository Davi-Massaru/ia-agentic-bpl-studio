# MAPA DE ARQUIVOS — AGENTIC BPL STUDIO

**Convenção:** `[M]` arquivo existente no pacote de arquitetura; `[P]` previsto para implementação; `[O]` opcional/fase posterior. **Um caminho previsto não significa classe compilada.**

```text
agentic-bpl-studio/
├── spec.md                                     [M] SPEC-mestra na raiz
├── README.md                                   [M] protocolo de desenvolvimento
├── requirements.txt                            [M] Flask para scaffold
├── SPEC/
│   ├── SPEC_FUNCIONAL_MVP.md                  [M] referência funcional aprovada
│   ├── SPEC_TECNICA_IMPLEMENTACAO.md          [M] arquitetura/Gates/ADR
│   ├── REPO_MAP.md                            [M] árvore e responsabilidades
│   ├── OBJECTSCRIPT_INTERFACES.md             [M] assinaturas propostas
│   ├── VALIDACAO_BUILD_154.md                [M] discovery antes do código
│   ├── PYTHON_INTERFACES.md                  [M] métodos de serviços Flask/WSGI
│   └── SEQUENCE_FLOWS.md                     [M] sequências de edição, publish, runtime
├── agents/                                     [M] sete especialistas de engenharia
│   ├── IA_HUB.agent.md
│   ├── iInteroperability.agent.md
│   ├── iEmbeddedPython.agent.md
│   ├── docker.iris.agent.md
│   ├── iris.Dictionary.agent.md
│   ├── iris.VectorSearch.agent.md
│   └── iris.IntegratedML-AutoML.agent.md
├── contracts/
│   ├── openapi.yaml                           [M] rotas HTTP propostas
│   └── schemas/
│       ├── decision-request.schema.json       [M] envelope Input
│       ├── decision-response.schema.json      [M] envelope Output
│       └── decision-binding.schema.json       [M] input/output/routes
├── backend/
│   ├── wsgi.py                                [M] callable para WSGI IRIS
│   └── studio/
│       ├── __init__.py                        [M] create_app()
│       ├── api/
│       │   ├── __init__.py                    [M]
│       │   └── routes.py                     [M] rotas 501 até ter IRIS
│       ├── services/
│       │   ├── __init__.py                    [M]
│       │   └── gateway.py                    [M] protocolo de acesso ao IRIS
│       ├── templates/
│       │   ├── base.html                     [M] shell UI mínima
│       │   ├── explorer.html                 [M] shell T-01
│       │   ├── designer.html                 [M] shell T-02
│       │   ├── test_trace.html               [M] shell T-03
│       │   └── publisher.html                [M] shell T-04
│       └── static/
│           └── style.css                     [M] aparência mínima
├── src/iris/Studio/
│   ├── Msg/
│   │   ├── DecisionRequest.cls               [P] Extends Ens.Request
│   │   └── DecisionResponse.cls              [P] Extends Ens.Response
│   ├── Interop/
│   │   └── AgentDecisionOperation.cls        [P] Extends Ens.BusinessOperation
│   ├── AI/
│   │   ├── AgentRuntimeAdapter.cls            [P] isolamento SDK 154
│   │   └── DecisionValidator.cls             [P] validação determinística
│   ├── Admin/
│   │   ├── Metadata.cls                      [P] enumeração Production/classes/tools
│   │   ├── BPLReader.cls                     [P] read-only XData/AST seguro
│   │   ├── BindingService.cls                [P] acesso/configuração draft
│   │   ├── BPLPublisher.cls                  [P] publish/versionamento
│   │   └── TestHarness.cls                   [P] acionar BS de teste
│   ├── Model/
│   │   ├── WorkflowDraft.cls                  [P] %Persistent
│   │   ├── AgentDefinition.cls                [P] %Persistent
│   │   ├── DecisionBinding.cls                [P] %Persistent
│   │   ├── WorkflowRelease.cls                [P] %Persistent
│   │   └── ExecutionAudit.cls                 [P] %Persistent
│   ├── Demo/
│   │   ├── EventRequest.cls                   [P] typed request demo
│   │   ├── EventRoutingBPL.cls                [P] BPL gerenciado demo
│   │   ├── TestService.cls                    [P] Enqueue BS demo
│   │   ├── ProcessOperation.cls               [P] BO de destino A
│   │   ├── ReviewOperation.cls                [P] BO de destino B/fallback
│   │   └── EventProduction.cls                [P] Production sintética
│   └── Tools/
│       ├── EventReadTools.cls                 [P] Extends %AI.ToolSet; READ
│       ├── VectorReadTools.cls                [O] retrieval semântico
│       └── PredictionTools.cls                [O] IntegratedML inferência
├── deploy/
│   ├── docker-compose.yaml                    [P] referência a imagem EAP local
│   ├── Dockerfile.iris                         [P] somente se build derivado local
│   ├── gateway/                               [P] config Web Gateway se necessário
│   ├── bootstrap/                             [P] namespace, classes, web app, hosts
│   └── module.xml                             [O] IPM após bootstrap comprovado
├── tests/
│   ├── test_scaffold.py                       [M] rotas de contrato
│   ├── test_mapping.py                        [P] schemas e tipos
│   ├── test_permissions.py                    [P] policy/allowlist
│   ├── test_publisher.py                      [P] diff/etag/compile fail
│   └── iris/                                  [P] testes IRIS nativos
└── .github/workflows/                         [O] build/lint/smoke
```

## Interfaces e donos de código

| Diretório | Proprietário | Dependências | Build/run |
|---|---|---|---|
| `backend/studio` | iEmbeddedPython | Flask, `IrisGateway` e HTML | runtime web, WSGI |
| `Studio/Admin` | iris.Dictionary + iInteroperability | `%Dictionary`, `Ens.*` | compile/administrativo |
| `Studio/Model` | iris.Dictionary + iInteroperability | `%Persistent` | compile/storage |
| `Studio/Msg`, `Studio/Interop` | iInteroperability + IA_HUB | `Ens.*`, Studio.AI | execução Production |
| `Studio/AI` | IA_HUB | `%AI.*`, policies/tool manager | execução Agent |
| `Studio/Tools` | IA_HUB; Vector/IntegratedML opcionais | `%AI.ToolSet` e SQL | compilação/tool runtime |
| `Studio/Demo` | iInteroperability | hosts, BPL, msgs e Tools | Production de teste |
| `deploy/` | docker.iris | gateway, IRIS image local, runtime | build/boot |
| `contracts/` | iInteroperability + IA_HUB | schemas, business contracts | validação |

## Método de versionamento de fonte

- Declarado `.cls`: fonte de repositório, nunca confundir com classe dinâmica ainda não exportada.
- `%Dictionary.ClassDefinition`: leitura/escrita da definição sob permissão explícita. `%Dictionary.CompiledClass`: introspecção da superfície efetiva, nunca edição direta.
- Manifest do Studio: configuração versionada distinta da fonte BPL; publicar requer manifesto e BPL compatíveis.
- `docker-compose.yaml` deve usar imagem EAP carregada localmente pelo avaliador, sem publicá-la em registry.
- Bootstrap não deve alterar classes já existentes sem backup, hash e aprovação.

## Interfaces Python → IRIS

1. `Flask route`: valida HTTP e identidade; **não** SQL cru interpolado.
2. `Studio service`: domínio administrativo, DTO, política geral.
3. `IrisGateway`: abstrai IRIS embedded vs conexão externa (futuro).
4. `Studio.Admin.*`: valida permissão e realiza metadados ou publicação.
5. `Studio.Model.*`: data store versionado.

**Invariantes:** a UI não conhece assinaturas `%AI.*`; somente o adaptador ObjectScript conhece o SDK EAP; agente não escolhe livremente destinos de BO.

**NOTA:** `SPEC/PYTHON_INTERFACES.md` relaciona os módulos Python futuros (páginas divididas em Blueprints) e os serviços propostos; `api/routes.py` permanece um scaffold concentrado, retornando HTTP 501.
