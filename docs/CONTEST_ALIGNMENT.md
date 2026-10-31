# Contest alignment assessment

Reviewed **October 27, 2026** against the [contest announcement and organizer clarifications](https://community.intersystems.com/post/intersystems-programming-contest-ai-agents-interoperability-workflows). The [expert guidance](https://community.intersystems.com/post/what-experts-look-contest-entries) informs presentation priorities; it is not a formal scoring rubric.

**Assessment: core technical fit demonstrated locally; submission readiness incomplete.** This is an engineering assessment of repository evidence, not approval by InterSystems. No fresh provider invocation or clean-environment installation was performed for this documentation review.

## Requirement and evidence matrix

| Criterion | Assessment | Project evidence / remaining work |
|---|---|---|
| IRIS workflow + AI Hub decision | Demonstrated locally | [Native BPL](../src/iris/Studio/Examples/NativeAgentWorkflow.cls), [portable Operation](../src/iris/Studio/Interop/PortableAgentOperation.cls), [LIVE session 1039](../validation/native-free-agents.json): ReadStock → C, ReadEvent → ACCEPT, final SUCCESS/C |
| Functional, original application | Partially established; organizer review required | Configuration, publication and native execution are implemented. Domain-neutral LIVE and stock examples are recorded. No independent originality audit, production-scale acceptance or fresh-machine reproduction is claimed |
| New or significantly improved Open Exchange entry | Not verified | No package listing/submission URL is supplied in this workspace |
| Public open-source GitHub/GitLab project | Pending | No public repository URL or LICENSE file found in the workspace. The author must choose the license and publish the repository |
| English README with installation and usage/demo | Documented | [README](../README.md) contains product purpose, setup, both usage paths, screenshots, evidence and limitations; Portuguese is a companion |
| AI Hub Community build 154 | Recorded | Compose pins `iris-community:2026.3.0AI.154.0`; native evidence records the build and real AI execution. Other builds are not certified |
| Docker reproducibility | Partial | Load/retag and Compose/bootstrap commands are documented; initialized local runtime was exercised. Fresh-machine reproduction is pending. Compose starts infrastructure; initialization also needs the supplied scripts |
| Reviewer-owned provider credential | Supported, with documented deviation | OpenAI/gpt-4.1-mini is recorded. Settings saves a reviewer key to Wallet. Organizer guidance asks for an environment-variable key convention; this app has no automatic environment-key import. Resolve that difference before submission, either by implementation or clarification |
| Entrant/team eligibility and submission count | Not verified | The repository cannot establish participant eligibility, previous entries or team membership. Include Community profile links if submitting as a team |

The announced submission deadline is **November 8, 2026, 23:59 EST**. Optional strengthening material includes an article on implementation experience, model usage/cost and tracing. An idea link is optional. Refer to the linked announcement for current participation rules.

## Why this project fits the technical theme

The value proposition is the reusable path from an agent definition to an IRIS message-driven decision. The native runtime uses AI Hub agents and sessions, not merely an HTTP wrapper presented as an agent. Publication creates a Business Operation or a managed BPL release. Native BPL remains responsible for orchestration and routing; output validation bounds the model's candidate actions.

BloodDemo supplies an inspectable input/output scenario for that path. It is not the product category. The independent component API accepts a selected installed Production, agent revision, host name, allowed actions, fallback and installed policy. The native BPL example proves multiple decision calls without a managed release. Broader domains require suitable ToolSets, contracts and policies; the example alone does not prove arbitrary integrations work unchanged.

## Strongest evidence for a reviewer

1. **Creation and publication:** [native component walkthrough](NATIVE_BPL.md), independent agent creation and `POST /components`; generated Operations pin configuration and reject conflicting host names.
2. **Execution:** [latest receipt](../validation/native-free-agents.json), native session 1039 and AI sessions 14/15. The synthetic stock and event decisions are separate tasks inside one BPL.
3. **Observability:** [native trace screenshot](../validation/screens/native-live-trace.jpg), captured session 1026; [matching receipt](../validation/native-free-agents-1026.json). Do not label that screenshot as session 1039.
4. **Failure behavior:** [policy rejection evidence](../validation/blood-policy.json) and native deadline checks in [HTTP lifecycle evidence](../validation/http-generic.json). Invalid model responses have occurred; fallback is part of the implementation.
5. **Code checks:** 101 Python tests recorded as passing; the suite includes independent component validation and host preservation. These tests are not a substitute for deployment acceptance.

## Remaining submission work, in priority order

1. Select an open-source license; publish source to GitHub/GitLab and establish the Open Exchange entry.
2. Reproduce the README on a fresh environment using a new reviewer's credentials; retain the result and resolve the environment-key configuration difference.
3. Confirm participant/team details and complete the contest submission. No external publication or acceptance was performed during this review.
4. Optionally record a short product-first demonstration and write an implementation article. Report actual token usage; monetary cost is not currently calculated. Do not claim use of official IRIS Agentic Dev skills solely because local `agents/` guidance exists.

## Documentation positioning

The README leads with the general platform, practical impact, native BPL integration and how to use it. The READMEs embed the complete creation/configuration/publication walkthrough with existing screenshots, using BloodDemo as Hello World. Standalone tutorial copies remain available in [English](GETTING_STARTED.md) and [Português](GETTING_STARTED_PT_BR.md). This prevents a tutorial domain from obscuring the actual contribution.

**Resumo em português:** aderência técnica central demonstrada; prontidão de submissão ainda parcial. As pendências são publicação/licença/cadastro, reprodução em ambiente limpo, detalhes dos participantes e resolução da diferença entre configuração por Wallet e a orientação de chave por variável de ambiente.
