# Provider configuration

Open **Settings** on any Studio screen, or [open the panel directly](http://localhost:52773/csp/studio/?settings=open), using your authenticated local IRIS account.

1. Choose the provider. The UI exposes OpenAI and Anthropic; recorded LIVE validation uses **OpenAI**.
2. Enter a model identifier. **gpt-4.1-mini** is the model in the recorded generic LIVE evidence; no model is selected automatically.
3. Enter your own provider key and save. Use that provider/model in the agent revision you publish.
4. Execute a LIVE workflow to validate inference. Saving preferences does not invoke the model; SIMULATION does not test a provider.

Credentials are stored in the `StudioSecrets` IRIS Wallet collection. Config Store retains a `secret://` reference. GET responses return metadata and stored-credential presence, never the key. Leaving the credential field blank preserves an existing key for that provider. Keys are not part of prompts, bindings or agent definitions.

**Environment variables:** this application does not automatically import `OPENAI_API_KEY`, `ANTHROPIC_API_KEY` or `.env` provider secrets. Settings/Wallet is the implemented path. Do not set an environment variable and assume the agent has received it. The [contest assessment](CONTEST_ALIGNMENT.md) tracks this difference from organizer setup guidance.

Agent revisions pin provider/model settings. Changing a preference in Settings does not rewrite an already published revision. Publish another agent/component revision or managed workflow release to change its configuration.

Local login credentials are generated in `.local/studio-auth.json`, excluded by `.gitignore`. The local account has development/Production administration privileges; `StudioBPLEditor` grants `%Ens_Code:RW` for native BPL editing. Re-login after permission changes. Docker ports bind to `127.0.0.1`; this setup is for local development.

[Settings HTTP evidence](../validation/settings-http.json) records authentication, CSRF and invalid-provider checks. [LIVE evidence](../validation/live-ai.json) separately records successful OpenAI inference. Token usage is available in execution records; monetary cost is not calculated and provider calls may incur charges.
