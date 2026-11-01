# Instalação

O procedimento fornecido utiliza PowerShell no Windows e Docker Desktop com
containers Linux. Obtenha a imagem Community AI Hub build 154 no
[portal EAP da InterSystems](https://evaluation.intersystems.com/Eval/early-access/AIHub).
A imagem licenciada é distribuída separadamente.

Execute na pasta do projeto:

```powershell
docker image load -i 'C:/caminho/iris-community-2026.3.0AI.154.0-docker.tar.gz'
docker image ls
# Use o nome exato informado pelo Docker caso seja diferente:
docker image tag docker.iscinternal.com/docker-intersystems/intersystems/iris-community:2026.3.0AI.154.0 iris-community:2026.3.0AI.154.0
.\scripts\bootstrap-iris.ps1
.\scripts\configure-web.ps1
.\scripts\generic-smoke.ps1
```

O bootstrap instala as dependências Python no volume persistente, compila
`Studio.*`, inicializa o workspace, restaura os hosts das releases conhecidas e
inicia `Studio.Demo.Production`. O script de configuração web cria a aplicação
WSGI autenticada e gera uma credencial local aleatória em
`.local/studio-auth.json` quando o arquivo ainda não existe. Nas próximas
execuções, reutiliza o arquivo. Consulte-o localmente para obter o usuário e a
senha de acesso; mantenha esse arquivo privado.

Abra o [Agentic BPL Studio](http://localhost:52773/csp/studio/) e autentique-se.
O usuário da instalação local é `studio`. Acesse
[Settings](http://localhost:52773/csp/studio/?settings=open) para configurar
provider, modelo e credencial de IA.

As portas 1972 e 52773 ficam vinculadas a `127.0.0.1`. Dados do IRIS, drafts e
releases persistem no volume Docker. Preserve o volume ao reiniciar:
`docker compose down -v` remove esses dados.


Execute os comandos na raiz do repositório.


## Provider e verificação de aceitação

Configuração LIVE registrada: OpenAI, `gpt-4.1-mini`. Informe sua chave em Settings; a aplicação não importa `OPENAI_API_KEY` ou `.env` automaticamente. A chave fica no Wallet. Salvar preferências não chama o modelo. Use provider/modelo iguais na revisão do agente e execute uma solicitação LIVE para validar. Anthropic é selecionável, mas não tem validação LIVE registrada.

Compose sozinho inicia a infraestrutura; `bootstrap-iris.ps1` inicializa a aplicação. Os scripts foram exercitados no ambiente local; a aceitação em máquina limpa permanece pendente. Mantenha imagens EAP privadas e distribua fontes/Compose, não a imagem EAP.

[Detalhes do provider](CONFIGURATION.md) · [Uso do BPL nativo](NATIVE_BPL_PT_BR.md) · [Aderência ao concurso](CONTEST_ALIGNMENT.md)
