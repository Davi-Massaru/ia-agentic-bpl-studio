# CHECKLIST DE INVESTIGAÇÃO — IRIS AI HUB BUILD 154

**Atualização 26/10/2026:** imagem carregada, runtime Build154U confirmado, classes
Studio compiladas e três mensagens SIMULATION rastreadas no IRIS. Embedded Python,
Flask e gateway administrativo passaram em teste dentro de job IRIS autenticado.
Web Application pública/local autenticada ainda aguarda autorização de acesso;
provider e decisões AI Hub reais ainda não configurados/testados.
Evidências: `../validation/iris154.json`, `../validation/wsgi-embedded.json` e
`IMPLEMENTATION_STATUS.md`. O restante deste arquivo preserva o roteiro de aceite.

## G0 — Estado do ambiente

| Item | Evidência a coletar | Aceite |
|---|---|---|
| Imagem | `docker image inspect` local e build real reportado pelo IRIS | 2026.3.0AI.154.0 |
| Python | `$SYSTEM.Python`/`%SYS.Python.GetPythonInfo` conforme ref da versão | biblioteca instalada e runtime funcional |
| Gateway | HTTP direto/externo, WSGI web application configurada e auth | `/health` Flask responde com autenticação |
| Namespace | DB, mappings e roles associados à Production | isolado e autorizado |
| BPL | `Ens.BusinessProcessBPL`, XData BPL e compilação do template | fonte BPL gerenciada compila |
| AI Hub | `%AI.Agent`, `%AI.Provider`, `%AI.Agent.Session`, ToolMgr/ToolSet presentes | surface introspectada |
| Agent | `%Init`, `CreateSession`, `Chat`, `.Content` disponíveis | executar probe com modelo e credencial real |
| Tool | XData `%AI.ToolSet`, assinatura de chamada e registro | tool READ real aparece em invocação |
| Error | timeout/exception/tool denied/candidate inválido | fallback BPL verificável |

## G1 — Primeiro teste vertical obrigatório

1. Carregar build 154 e uma Production sintética.
2. Compilar uma ToolSet READ mínima sobre dados locais sintéticos.
3. Invocar `%AI.Agent` diretamente do terminal usando apenas APIs conferidas no class reference.
4. Construir `Studio.Msg.DecisionRequest/Response`, `AgentDecisionOperation`, `DecisionValidator`.
5. Criar BPL gerenciado com `call` síncrona para AgentDecisionOperation, `assign` e `switch`.
6. Injetar duas mensagens por Business Service real da Production.
7. Verificar destinos e IDs no Visual Trace; registrar Agent Session e logs de ferramentas.
8. Testar fallback após retorno inválido ou indisponibilidade do Provider.

**Proibição:** pular G1 e escrever a UI como se a integração já estivesse validada.

## WSGI — Procedimento

- Confirmar web server/Web Gateway em topologia Docker real (imagem EAP não pressupõe PWS).
- Instalar Flask no runtime Python usado pelo IRIS, observando versões compatíveis e local de instalação.
- Configurar web application WSGI no Management Portal: namespace, aplicação/callable, directory, auth.
- Verificar `PATH_INFO`/`SCRIPT_NAME` quando app tiver prefixo; testar status 200/404/405 e payload limits.
- Confirmar que Flask recebe usuário real e que RBAC é revalidado no IRIS; não confiar em header arbitrário.
- Se WSGI não funcionar no 154 com gateway permitido, mover Flask a container externo, mantendo `IrisGateway`.

## AI SDK — métodos a inspecionar

| Classe | Símbolos alvo | Resultado (a preencher em execução) |
|---|---|---|
| `%AI.Provider` | Create, config, credenciais | NÃO VERIFICADO |
| `%AI.Agent` | `%New`, `%Init`, `Model`, `SystemPrompt`, `UseToolSet`, `CreateSession`, `Chat` | NÃO VERIFICADO |
| `%AI.Agent.Session` | Session ID, stats, lifecycle | NÃO VERIFICADO |
| `%AI.LLM.Response` | Content, erros, metadata | NÃO VERIFICADO |
| `%AI.ToolSet` | XData DSL, typed methods | NÃO VERIFICADO |
| `%AI.ToolMgr` | Policies e tool invocations | NÃO VERIFICADO |

## Docker e licenciamento

- README deve explicar como avaliador baixa a imagem Community EAP 154 da InterSystems, carrega `docker image load`, inspeciona tag e cria alias local.
- Compose usa **imagem local**, sem redistribuir tar, container derivado ou registry.
- Definir `gateway` explícito se não existir servidor web, sem presumir HTTP 52773.
- Startup idempotente não injeta chaves no Git e não escreve em namespace de sistema.

## Go / No-Go

- G0: SDK e HTTP identificados; fallback arquitetural pronto.
- G1: mensagem real entra por BS, passa por BPL, agente realmente usa ToolSet, retorna e BPL toma o desvio.
- G2: schemas, Reader, Binder e três operações administrativas estáveis.
- G3: publicação controlada com preview/diff, compile e rollback documentado.
- G4: usuário realiza fluxo completo pelas quatro telas e Visual Trace prova execução.

**Referências:**
- https://github.com/intersystems-community/ai-hub-eap/blob/master/ObjectScript_SDK_Guide.md
- https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=AWSGI
- https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=EBPL_editorintro
