# Validação de acesso EAP e telas — 25/10/2026

## Caminho oficial

[Portal EAP AI Hub](https://evaluation.intersystems.com/Eval/early-access/AIHub),
indicado pelo [concurso](https://community.intersystems.com/post/intersystems-programming-contest-ai-agents-interoperability-workflows).

Arquivo x64: `iris-community-2026.3.0AI.154.0-docker.tar.gz`.
Alternativa IRIS for Health: `irishealth-community-2026.3.0AI.154.0-docker.tar.gz`.
A página informa distribuição pelo EAP, sem imagem específica do concurso no Docker Hub.

Navegador confirmou redirecionamento do portal para InterSystems Login, campo
Username. Download ainda não acessível nesta sessão. Nenhuma credencial foi
solicitada em texto ou preenchida. Aba do portal preservada para login pelo usuário.

Pesquisa de nomes de arquivos no perfil `C:/Users/Massaru` com padrões
`*iris*.tar*`, `*iris*.tgz`, `*iris*.zip` não retornou arquivos. Erros de leitura
foram omitidos pelo comando: isso não prova ausência em diretórios inacessíveis,
outros usuários, discos ou arquivos com nomes diferentes.

## Inspeção das quatro telas

Navegador real, servidor Flask local, viewport desktop de 1280x720.
Navegação sequencial por links, inspeção da árvore de acessibilidade e screenshots.

| Tela | Renderização / navegação | Aceite funcional SPEC |
|---|---|---|
| Explorer | PASSOU | FALHOU: catálogo/seleção de Production/BPL inexistentes |
| Designer | PASSOU | FALHOU: cinco nomes em texto; sem abas interativas, canvas ou formulário |
| Test & Trace | PASSOU | FALHOU: sem input, execução, timeline ou correlação |
| Publisher | PASSOU | FALHOU: sem diff, validação, compilação ou release |

Alertas de indisponibilidade visíveis. Nenhuma tela afirma execução/publicação
bem-sucedida. Não há funcionalidade nativa a testar nesta versão. O concurso exige
workflow funcional; as quatro telas e seus detalhes são requisitos do SPEC local.

## Correções realizadas

- Links gerados com `url_for`: preservam o prefixo WSGI `/studio`.
- Título específico por página; navegação identificada e `aria-current`.
- Foco de teclado visível e regra CSS para telas estreitas.
- Testes das quatro páginas na raiz e sob prefixo; CSS servido corretamente.
- 64 testes passaram. Responsividade tem regra CSS, mas não foi validada em
  viewport móvel nesta rodada. Nenhuma certificação completa de acessibilidade.

Evidência após correção: `validation/screenshots/publisher.png`.
Servidor de inspeção: `http://127.0.0.1:5057` (desenvolvimento local).

## Resultado

Portal correto identificado. Download bloqueado por autenticação do usuário.
Telas aprovadas somente como shells navegáveis; reprovadas no aceite funcional.
G0/G1 permanecem pendentes de imagem 154 e execução nativa.
