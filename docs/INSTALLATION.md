# Install and open

The supplied setup targets Windows PowerShell with Docker Desktop running Linux
containers. Obtain the licensed Community AI Hub build 154 image through the
[InterSystems EAP portal](https://evaluation.intersystems.com/Eval/early-access/AIHub).
The image is supplied separately and is not redistributed by this repository.

From the repository root:

```powershell
docker image load -i 'C:/path/iris-community-2026.3.0AI.154.0-docker.tar.gz'
docker image ls
# Substitute the exact image name printed by Docker if it differs:
docker image tag docker.iscinternal.com/docker-intersystems/intersystems/iris-community:2026.3.0AI.154.0 iris-community:2026.3.0AI.154.0
.\scripts\bootstrap-iris.ps1
.\scripts\configure-web.ps1
.\scripts\generic-smoke.ps1
```

Bootstrap installs Python dependencies in the durable container volume, compiles
`Studio.*`, initializes the managed workspace, reconciles installed release hosts
and starts the generic `Studio.Demo.Production`. The web configuration script sets
up the native authenticated WSGI application and generates a random local account
credential in `.local/studio-auth.json` when that private file does not exist. It
reuses the existing file on subsequent runs. Open that file locally to read the
username and password, and enter them in the browser authentication prompt. Keep
the file private. Provider credentials are configured separately in Settings.

Open [Agentic BPL Studio](http://localhost:52773/csp/studio/) and authenticate with
the configured IRIS account. The existing local installation uses account
`studio`. Open [Settings directly](http://localhost:52773/csp/studio/?settings=open)
to choose a provider and enter your own model identifier and credential.

Compose binds ports 1972 and 52773 to `127.0.0.1`. IRIS data, drafts and releases
persist in the Docker volume; sources and contracts are mounted read-only. Keep
that volume when restarting. `docker compose down -v` removes it.


Run commands from the repository root.


## Provider and acceptance check

Recorded LIVE setup: OpenAI, `gpt-4.1-mini`. Enter your own key through Settings; this application does not import `OPENAI_API_KEY` or `.env` automatically. Wallet stores the key. Saving preferences makes no model call. Use the same provider/model in the agent revision, then execute a LIVE request to validate it. Anthropic is selectable but has no recorded LIVE validation.

Compose alone starts infrastructure; `bootstrap-iris.ps1` initializes the application. The supplied scripts were exercised in the local development environment; fresh-machine acceptance remains pending. Keep EAP images private and distribute source/Compose files, not the EAP image.

[Provider details](CONFIGURATION.md) · [Native BPL usage](NATIVE_BPL.md) · [Contest assessment](CONTEST_ALIGNMENT.md)
