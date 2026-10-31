# Implementation status — October 28, 2026

This file records implementation and observed evidence. The architecture documents
in `spec.md` and `SPEC/` also contain the original proposal and earlier scaffold
inventories; those inventories are not the current implementation status.

## Embedded Python validation — October 28

All 48 application classes compiled. Decision validation, route resolution and BloodDemo candidate/tool-evidence policy execute as Embedded Python. SDK orchestration and ToolSet callbacks remain ObjectScript: Python callbacks timed out in queued Production testing despite isolated calls succeeding. Experimental orchestration changes were removed; full Python conversion is not claimed. The callback root cause is unconfirmed.

126 Python tests and native DecisionValidator/InputMapper tests passed. LIVE session 1136 completed SUCCESS/C with AI Hub sessions 26/27. See `validation/embedded-python.json` and `validation/embedded-python-live.json`. The SDK appends an explicit output contract; BPL preserves correlation on timeout. Earlier evidence below is historical.

## Current reading guide

The product has two paths: independent AI Hub Operations composed in the native BPL editor, and template-based managed workflows. BloodDemo is only the Getting Started scenario. The earlier sections below retain implementation history; their single-slot descriptions apply to the managed Designer, not native BPL composition.

Previous code validation: **101 Python tests passed**, native two-agent LIVE session **1039** succeeded. The documentation/contest review made no new provider call and did not test installation on a clean machine. See [contest assessment](../docs/CONTEST_ALIGNMENT.md) for publication, license, reviewer credential configuration and submission gaps.

## Current result

The general Studio control plane is connected to a local InterSystems IRIS AI Hub
Community `2026.3.0AI.154.0` runtime. The four English screens and Settings are
served through authenticated native WSGI at `/csp/studio` on loopback port 52773.
The local `studio` account and web application have been configured with user
authorization. Native IRIS authentication is used directly.

The workspace discovers installed Productions and BPL hosts, creates versioned
managed workflows, supports the single recognized AI Decision slot, maps typed
inputs and static output routes, and stages/compiles/publishes immutable generated
BPL classes and versioned Production hosts. Restore from an earlier release creates
a fresh draft and requires validation and reviewed publication.

Six generic SIMULATION runs have traversed the actual native Service → BPL →
Decision Operation → destination Operation path. These runs demonstrate native
message execution and fallback, not external AI invocation. OpenAI/gpt-4.1-mini is configured through Wallet and Config Store. Two final LIVE runs passed (ACCEPT and REVIEW), each with an observed ReadEvent call and a real AI Hub session. Evidence: `validation/live-ai.json`.

## Gates and practical limits

| Gate | Observed state | Remaining condition |
|---|---|---|
| G0: runtime and interfaces | Build 154, Embedded Python, native WSGI authentication and inspected AI Hub signatures verified | Verify further SDK capabilities before enabling them |
| G1: native execution | Generic Service/BPL/Operation messages and deterministic failure cases verified in SIMULATION | Two LIVE decisions and observed READ tools passed; real provider-failure fallback remains unverified |
| G2: versioned configuration | IRIS-backed drafts, bindings, agent revisions, release snapshots and secure Settings implemented | Provider configuration and two LIVE success cases completed |
| G3: four screens and managed publishing | English UI, native discovery, typed mapping, generated BPL releases, versioned hosts and draft rollback implemented | Continue browser/runtime checks when extending templates |
| G4: complete demonstration | Reproducible local runtime and native evidence available | Public release/license and final submission verification |

The project is not yet a completed AI Hub or contest acceptance demonstration.

## Implementation details

### Native workspace and publication

- `Studio.Admin.Workspace` dispatches administration into Embedded Python with
  native authorization and a workspace write lock. The IRIS Dictionary and native
  Production configuration supply catalog metadata.
- The versioned `decision-routing-v1` template uses
  `Studio.Msg.WorkflowRequest` / `Studio.Msg.WorkflowResponse`, one managed AI
  Decision and bounded static routes to enabled installed Operations.
- A new workflow starts with an available managed slot. Insertion checks the
  expected draft revision, changes the recognized template and advances the draft.
- Input source fields come from native request/context metadata. Text constants
  use `constant:` mappings. Native preview validates the mapping and redacts
  sensitive values. The runtime mapper applies the pinned release binding.
- Shared agent revisions contain provider references, instructions, model names and
  authorized READ ToolSet references. Bindings independently pin a revision and
  specify inputs, output mapping, routes, fallback and timeout.
- Validation and reviewed BPL/binding diff precede publication. Source hashes,
  revisions, write locks and idempotency checks prevent silent concurrent changes.
- Generic publication compiles a staged BPL and a release-specific
  `Studio.Managed.*` class, installs a versioned Production host, and saves the
  immutable source/binding/agent release snapshot. Existing releases keep their
  class and host identities.
- A release installed into a stopped Production reports `activated:false`.
  Activation requires the intended Production to run and its configuration to be
  updated. Installation is not displayed as confirmed activation.
- Bootstrap reconciliation reinstalls known generated release hosts whose source
  hashes still match. Unrelated hosts and arbitrary BPL source are not rewritten.
- Restoring prior configuration creates a new draft. It does not silently publish
  or replace the historical release.

### Runtime and evidence

- Business Services submit native requests. BPL orchestrates the call to reusable
  `Studio.Interop.AgentDecisionOperation`, validates structured decisions and
  chooses a statically configured Operation or fallback.
- `SIMULATION` executes actual Interoperability messages while supplying
  deterministic decisions and injected failure conditions. It never invokes the
  provider. `LIVE` uses the native AI Hub adapter and requires configured access.
- Native agent/Provider/session SDK signatures were inspected on build 154. Two LIVE success cases now demonstrate actual provider invocation; simulated faults remain separately labeled.
- Trace data correlates releases, bindings, execution IDs, native request/response
  bodies, messages, Interoperability sessions, decisions and destinations. Audit
  input and response content are redacted.
- AI ToolSet call evidence is shown only when real instrumentation observes a call.
  Empty tool-call lists in SIMULATION do not demonstrate ToolSet execution.
- The supplied destination Operations produce local acknowledgements; the example
  does not transfer goods or invoke external domain systems.

### Web interface and Settings

- `backend/wsgi_iris.py` provides the authenticated IRIS WSGI application. Flask is
  the control plane; there is no second workflow engine or separate message runtime.
- All four screens use English labels, status messages, accessibility labels and
  placeholders. The Designer renders native activity metadata, actual connections,
  typed mappers and five Inspector tabs. Unknown source remains read-only.
- CSRF is required for mutations. Native authorization gates API access; authenticated
  responses are not cached. Browser storage contains only the selected workflow ID.
- Settings is available on each screen and via `?settings=open`. Saving a provider
  or model preference makes no model call. The model has no assumed default.
- Credentials are written to IRIS Wallet and referenced through Config Store. GET
  responses never return the key. Neither bindings nor prompts carry credentials.
- The optional blood-center Production remains a domain example. General workspace
  workflows and the four Studio screens do not depend on a domain-specific page.

## Recorded verification

| Evidence | What it proves | What it does not prove |
|---|---|---|
| `validation/generic-runtime.json` | Six native SIMULATION cases: ACCEPT, REVIEW, INVALID, TIMEOUT, ERROR and DENIED; generated release class/host and message identifiers | A provider call or observed AI ToolSet use |
| `validation/browser.json` | Four English screens, redacted Designer preview, browser-submitted native simulation, Publisher validation/diff and open blank Settings | A LIVE AI invocation |
| `validation/http-generic.json` | Authenticated create/slot/preview/publication/idempotency/rollback, native message trace, real one-second BPL timeout against two-second local delay | External inference or cancellation of an in-flight provider call |
| `validation/settings-http.json` | Authenticated native WSGI HTTP 200 for Settings/templates; CSRF rejection 403; invalid provider 422 without credential echo | Successful model authentication or inference |
| `validation/wsgi-embedded.json` | Flask/gateway checks inside an authenticated IRIS job | Browser authentication by itself |
| `validation/iris154.json` | Earlier native blood-center SIMULATION traces on build 154 | General workflow or LIVE AI acceptance |

The full Python suite passed 92 tests. Native WorkspaceTest passed 17 checks; generic runtime and authenticated HTTP lifecycle checks passed. JavaScript syntax checks passed. The UI/settings
subset passed 15 tests after English/accessibility and draft-restore changes.
Native generic-runtime evidence records `nativeRuntimeSuiteStatus:1` and
`providerInvoked:false`. Older `validation/local.json` retains an earlier failed
Docker-environment check and is historical, not the current native runtime result.

## Reproduction entry points

- `scripts/bootstrap-iris.ps1`: durable Docker runtime, dependency installation,
  native source compilation, workspace initialization and release reconciliation.
- `scripts/configure-web.ps1`: native authenticated WSGI application configuration;
  generates a private `.local/studio-auth.json` credential file if absent and reuses
  it on later runs. Read this file locally for the browser authentication prompt.
- `scripts/generic-smoke.ps1`: generic managed release and native deterministic
  message/failure smoke checks; creates synthetic sandbox drafts/releases and
  exercises rollback, with no external provider invocation.
- `scripts/http-smoke.py`: authenticated HTTP API checks using the private local
  credential file; creates a synthetic managed release and SIMULATION run.
- `scripts/native-smoke.ps1`: optional earlier blood-center message example.
- `python -m pytest -q`: Python contracts, validation, gateway and UI checks.
- `node --check backend/studio/static/studio.js` and the corresponding
  `settings.js` command: JavaScript syntax verification.

See [README](../README.md) for installation and the four-screen walkthrough.
The licensed EAP image stays local and must be obtained separately.

## LIVE evidence and documentation update

`validation/live-ai.json`: ACCEPT and REVIEW succeeded with AI sessions 3 and 4, native messages 923 and 930, one observed READ tool per execution. Initial long-reason failure is retained in `validation/live-ai-initial.json`; the BPL context limit was corrected before the final runs. Settings records verification only from a persisted successful native LIVE trace. Both README editions now include all five Inspector tabs, provider setup, versioning, native BPL flow and audit walkthrough. Python suite: 92 passed.

## Stock template MVP completed

The installed `blood-stock-v1` template creates typed stock workflows in `Studio.BloodDemo.Production`. UI agent creation, binding and publication use the existing control plane. Native AI Hub LIVE B/C/REVIEW decisions passed with observed ReadStock calls (`validation/blood-live.json`). Server policy rejects invalid stock candidates; three native simulated negative cases passed (`validation/blood-policy.json`). The managed workflow is a new published host alongside the legacy example, not an arbitrary BPL rewrite. Inventory and destination acknowledgements are synthetic.


## Native composition extension — October 27, 2026

Independent agent revision creation and `POST /components` publish pinned AI Hub Business Operations without managed releases. Native BPL Calls provide free composition; Studio does not patch EnsPortal. Two-agent LIVE execution passed in native session 1039 (AI sessions 14/15). Native editor, Operation settings and Visual Trace screenshots are linked in `docs/NATIVE_BPL.md`. Local `%Ens_Code:RW` is assigned through a dedicated role; namespace remains USER. Python suite: 101 passed. Managed Designer restrictions still apply to that screen only.
