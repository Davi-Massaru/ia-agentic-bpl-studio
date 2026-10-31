# CONTRATOS PYTHON — FLASK / EMBEDDED PYTHON / IRIS GATEWAY

**STATUS:** interfaces do backend propostas, não implementadas no scaffold; endpoints associados em `contracts/openapi.yaml`.

## 1. Aplicação WSGI

```python
# backend/studio/__init__.py — existe no scaffold
from flask import Flask

def create_app(config: dict | None = None) -> Flask: ...

# backend/wsgi.py — existe no scaffold
application = create_app()
```

O callable Flask cumpre WSGI por expor `application(environ, start_response)` internamente. A Web Application IRIS só deve apontar para esse arquivo após habilitar Web Gateway/Wsgi no build154. Configurar auth + namespace e não permitir qualquer namespace arbitrária por parâmetro HTTP.

## 2. Adapter Python → IRIS (interface existente no scaffold)

```python
# backend/studio/services/gateway.py
from typing import Any, Protocol

class IrisGateway(Protocol):
    def detect_capabilities(self) -> dict[str, Any]: ...
    def list_productions(self) -> list[dict[str, Any]]: ...
    def list_workflows(self, production: str) -> list[dict[str, Any]]: ...
    def get_workflow(self, workflow_id: str) -> dict[str, Any]: ...
    def list_toolsets(self) -> list[dict[str, Any]]: ...
    def validate_workflow(self, workflow_id: str) -> dict[str, Any]: ...
    def preview_publish(self, workflow_id: str) -> dict[str, Any]: ...
    def publish_workflow(self, workflow_id: str, base_hash: str,
                         revision: int, approval_ref: str) -> dict[str, Any]: ...
    def submit_test_message(self, release_id: str,
                            payload: dict[str, Any]) -> str: ...
    def get_run(self, execution_id: str) -> dict[str, Any]: ...
```

**Novo arquivo futuro:** `services/iris_embedded.py` implementará esse protocolo usando `import iris` em Embedded Python. Confirmar `iris.cls("Studio.Admin.X").Method(...)` no runtime da instalação. NUNCA montar ObjectScript com concatenação a partir de entrada HTTP. A sessão WSGI roda num contexto IRIS; propagar usuário/roles do IRIS, não aceitar cabeçalho `X-User` não confiável.

**Fallback futuro:** `services/iris_remote.py` chamará API autenticada ou Native SDK quando Flask precisar rodar em container separado. O retorno e os contratos de serviço serão os mesmos.

## 3. Serviços de aplicação a implementar (ASSINATURAS PROPOSTAS)

```python
class WorkflowCatalogService:
    def __init__(self, gateway: IrisGateway): ...
    def get_capabilities(self, principal: str) -> dict: ...
    def list_productions(self, principal: str) -> list[dict]: ...
    def list_workflows(self, production: str, principal: str) -> list[dict]: ...
    def get_workflow(self, workflow_id: str, principal: str) -> dict: ...
    def create_managed_workflow(self, template_id: str, production: str,
                                principal: str) -> dict: ...

class AgentConfigurationService:
    def __init__(self, gateway: IrisGateway): ...
    def list_agents(self, principal: str) -> list[dict]: ...
    def save_agent_revision(self, agent_id: str, definition: dict,
                            base_revision: int, principal: str) -> dict: ...
    def list_toolsets(self, principal: str) -> list[dict]: ...

class DecisionBindingService:
    def __init__(self, gateway: IrisGateway): ...
    def get_binding(self, binding_id: str, principal: str) -> dict: ...
    def save_binding(self, binding_id: str, payload: dict,
                     expected_revision: int, principal: str) -> dict: ...
    def validate_binding(self, binding_id: str, principal: str) -> dict: ...
    def preview_input(self, binding_id: str, example: dict,
                      principal: str) -> dict: ...

class WorkflowPublishService:
    def __init__(self, gateway: IrisGateway): ...
    def validate(self, workflow_id: str, principal: str) -> dict: ...
    def preview(self, workflow_id: str, principal: str) -> dict: ...
    def publish(self, workflow_id: str, revision: int,
                base_hash: str, idempotency_key: str,
                approval_ref: str, principal: str) -> dict: ...
    def list_releases(self, workflow_id: str, principal: str) -> list[dict]: ...

class WorkflowTraceService:
    def __init__(self, gateway: IrisGateway): ...
    def execute_live(self, release_id: str, payload: dict,
                     principal: str) -> dict: ...
    def get_execution(self, execution_id: str, principal: str) -> dict: ...
```

**Nota:** as classes acima são serviços Python próprios do Studio, não SDK InterSystems. `principal` só pode vir do subsistema de autenticação configurado, nunca diretamente do JSON enviado.

## 4. Regras HTTP por tela

| Tela | GET/POST/PUT | Resposta / situações de erro |
|---|---|---|
| Explorer | `GET capabilities`, `GET productions`, `GET workflows`, `POST workflows` | `200/201`; `403` ACL; `404` workflow; `501` gateway não conectado |
| Designer | `GET agents`, `PUT agents/{id}`, `GET toolsets`, `PUT bindings/{id}` | `200`; `409` version conflict; `422` contrato inválido |
| Test & Trace | `POST test-runs`, `GET runs/{id}` | `202`; `403` live não permitido; `404` id; `502/503` falha do host |
| Publisher | `POST validate/preview/publish`, `GET releases` | `200/201`; `409` ETag; `422` compile; `403` publisher policy |

**Estrutura de erro padronizada:**

```json
{
  "errorCode": "BPL_SOURCE_CONFLICT",
  "message": "A definição do BPL mudou desde a abertura do rascunho.",
  "correlationId": "req-101",
  "details": []
}
```

Erros 500 não devem expor stack trace, prompt, SQL, credenciais ou dados pessoais. Console de Developer só exibe dados redigidos. `Publish` só retorna 201 após confirmação do IRIS (compilação/ativação declarada conforme escopo).

## 5. Mapas de módulos Python propostos

```text
backend/studio/api/
  explorer.py            # GET environment, productions, workflows; POST managed
  designer.py            # GET/PUT AgentDefinition/DecisionBinding/Toolsets
  test_trace.py          # POST live test, GET correlated runs
  publisher.py           # validate, preview, publish, releases
backend/studio/services/
  gateway.py             # port IrisGateway (já presente)
  iris_embedded.py       # adapter EmbeddedPython (novo)
  iris_remote.py         # opcional fallback remoto (novo)
  workflows.py           # WorkflowCatalogService (novo)
  agents.py              # AgentConfigurationService (novo)
  bindings.py            # DecisionBindingService (novo)
  publisher.py           # WorkflowPublishService (novo)
  traces.py              # WorkflowTraceService (novo)
backend/studio/domain/
  dtos.py                # DTO tipados/JSON boundaries (novo)
  validation.py          # validação HTTP, não substitui validador IRIS
  permissions.py         # authz por escopo e papel
```

O scaffold atual concentra 14 endpoints em `api/routes.py` retornando **501 intencionalmente**. A divisão acima é a meta de implementação; migrar progressivamente após G0/G1.

## 6. Separação de validações

- **Python UI validation:** tamanho e formato JSON, propriedades obrigatórias, coerência básica de dados, informação de usuário autenticado.
- **IRIS Metadata validation:** classe e propriedade existem, BPL é editável, BO destino está na Production, ToolSet habilitada e policy permitida.
- **IRIS runtime validation:** o output real é schema/enum autorizado, com version pinned e fallback determinístico. Nunca confiar no JSON Schema do navegador como proteção única.

## 7. Estratégia de testes

- `pytest`: Flask test client, status/erro, validação de payload e conflito de ETag com fakes de `IrisGateway`.
- Testes `Ens.*`: BPL, BO, Request/Response, Message Map, guardas e estados de erro no IRIS.
- Testes reais AI Hub: sessão, tool invocations, resposta e correlação no build 154.
- Teste de integração WSGI: mesma UI por prefixo Management Portal/Web Gateway, validação do namespace e headers de autenticação.

**G0 e G1 precedem código Python real de publicação.**
