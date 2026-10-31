# Agentes especializados de engenharia

Estes sete arquivos são instruções para especialistas **de desenvolvimento** que devem orientar implementações e revisões. **Não** representam instâncias nativas `%AI.Agent` implantadas automaticamente no IRIS.

| Especialista | Foco no Agentic BPL Studio |
|---|---|
| `IA_HUB.agent.md` | SDK `%AI.Agent`, providers, sessões, ToolSets, validação de decisões e políticas |
| `iInteroperability.agent.md` | Productions, BPL, Requests/Responses, Business Hosts, Visual Trace |
| `iEmbeddedPython.agent.md` | Flask, Embedded Python, WSGI, API, compatibilidade Python ↔ IRIS |
| `docker.iris.agent.md` | Docker/Compose, build 154, gateway, bootstrap, IPM/ZPM, segurança e CI |
| `iris.Dictionary.agent.md` | Introspecção, XData BPL, classes, assinaturas, publicação segura |
| `iris.VectorSearch.agent.md` | Tools de busca semântica opcionais (fora da dependência central do MVP) |
| `iris.IntegratedML-AutoML.agent.md` | Tools de inferência opcionais (fora da dependência central do MVP) |

**Critério transversal:** validar a superfície real do build `2026.3.0AI.154.0` antes de implementar chamadas oficiais. Os arquivos `SPEC/OBJECTSCRIPT_INTERFACES.md` e `SPEC/PYTHON_INTERFACES.md` descrevem interfaces **propostas da aplicação**, não APIs oficiais já compiladas.
