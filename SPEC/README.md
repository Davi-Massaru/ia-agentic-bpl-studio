# SPEC — Arquitetura e contratos de implementação

A especificação mestre fica em [`../spec.md`](../spec.md), na raiz do projeto.

| Documento | Conteúdo |
|---|---|
| `SPEC_FUNCIONAL_MVP.md` | Requisitos completos das quatro telas e cinco abas do AI Hub Inspector |
| `SPEC_TECNICA_IMPLEMENTACAO.md` | Arquitetura, domínios, limites, deploy, gates de desenvolvimento, ADRs |
| `REPO_MAP.md` | Árvore de arquivos existentes/previstos e responsáveis |
| `OBJECTSCRIPT_INTERFACES.md` | Classes `Studio.*`, propriedades e assinaturas propostas |
| `PYTHON_INTERFACES.md` | Flask, serviços, protocolo IrisGateway e assinaturas Python |
| `SEQUENCE_FLOWS.md` | Sequências de edição, publicação e execução BPL → AI Hub → BPL |
| `VALIDACAO_BUILD_154.md` | Plano GO/NO-GO de compatibilidade com EAP 154 |

Os contratos de API e mensagens estão em [`../contracts/`](../contracts/): `openapi.yaml` e três JSON Schemas.
Os especialistas de engenharia estão em [`../agents/`](../agents/).

**Situação atual:** esta pasta preserva também propostas históricas. Consulte `IMPLEMENTATION_STATUS.md` e `../plano.md` para implementação e evidências atuais. O Designer inclui blocos arrastáveis, bindings multiponto e revisões independentes; compilação, mensagens SIMULATION e interação real no navegador foram verificadas. A nova validação LIVE permanece pendente de autorização do provedor.
