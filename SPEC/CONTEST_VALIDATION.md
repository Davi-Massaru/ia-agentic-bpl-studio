# Validação do concurso — 25/10/2026

Fonte: [anúncio oficial](https://community.intersystems.com/post/intersystems-programming-contest-ai-agents-interoperability-workflows), consultado nesta rodada.

## Requisitos do anúncio

| Requisito | Evidência local | Resultado |
|---|---|---|
| Workflow Interoperability com decisão AI Hub | Adaptador ainda bloqueado; BPL/Production ausentes | NÃO ATENDE |
| Aplicação funcional e original | Fundação implementada; fluxo completo ausente | NÃO ATENDE funcionalidade; originalidade não avaliada |
| App novo ou melhoria significativa no Open Exchange | Nenhuma entrada informada | NÃO VERIFICADO |
| Open source publicado em GitHub/GitLab | Sem `.git`, remoto público ou licença no projeto | NÃO ATENDE no estado inspecionado |
| README inglês, instalação e demo/descrição | README inglês presente; demo real ausente | PARCIAL |
| Community AI Hub build 154 | Compose referencia a tag; runtime não inspecionado | NÃO VALIDADO |
| Até três submissões; perfis dos membros para equipe | Dados não informados | NÃO VERIFICADO |

Prazo de submissão anunciado: 08/11/2026, 23h59 EST. Aprovação final pertence aos organizadores.

## Implementação nesta rodada

- `scripts/validate_project.py`: executa pytest, valida Compose, verifica Docker Engine
  e imagem local; gera JSON e retorna erro quando verificações locais falham.
- O relatório mantém aceite do concurso como `NOT_VALIDATED`, mesmo quando todos
  os testes locais passam. Imagem/tag não comprova build ou execução nativa.
- `deploy/prepare-image.ps1`: carrega arquivo EAP fornecido e cria alias local,
  recusando sobrescrever uma tag que aponte para outra imagem. Não baixa nem
  redistribui EAP. Build real deve ser conferido via `$ZVERSION`.
- Testes do verificador: falha, timeout, ferramenta ausente, diagnóstico limitado
  e separação entre sucesso local e aceite nativo.

## Ordem de desbloqueio

```text
ENTRADA: Docker Engine saudável + arquivo Community EAP 154
   -> carregar imagem local
   -> namespace dedicado + compilar Studio.*
   -> capturar CapabilityProbe / assinaturas reais
   -> implementar Operation + BPL + Business Service + ToolSet
   -> mensagens reais + decisões distintas + fallback + trace
   -> drafts/release/publisher + quatro telas
   -> licença escolhida + repositório público + demo + Open Exchange
```

A sequência nativa segue os gates G0/G1 de `spec.md`. Não substituir esses gates
por testes com doubles nem liberar o adaptador sem conferir o SDK instalado.

## Reprodução

```powershell
.\.venv\Scripts\python.exe scripts/validate_project.py
```

Saída: `validation/local.json`. Código 0 significa apenas verificações locais
aprovadas; o campo `contestStatus` permanece independente. O script não consulta
credenciais nem altera containers. Reexecutar após disponibilizar o runtime.
