# IRIS sources — current validation

Community 2026.3.0AI Build154U in USER was verified in the local project container.
Modified classes and generated multipoint BPL compiled successfully. Two pinned
agent revisions, previous-context mapping, fallback, immutable releases and a
real BPL deadline with a late synthetic reply passed in SIMULATION. Legacy
WorkspaceTest passed 17 checks; InputMapperTest returned success.
See [current status](../../SPEC/IMPLEMENTATION_STATUS.md),
[native evidence](../../validation/visual-designer-native.json) and
[implementation plan](../../plano.md). Earlier `iris154.json` is historical.

Run `scripts/bootstrap-iris.ps1` from the project root to compile/install the
allowlisted example, and `scripts/native-smoke.ps1` for deterministic native tests.
The scripts preserve a dedicated Docker volume and refuse unrelated Productions.

`Studio.AI.AgentRuntimeAdapter` uses Provider.Create, Agent.%New, UseToolSet,
CreateSession, Chat and Session.GetStats signatures inspected on this exact build.
This is compiled integration code, not proof of an actual provider/tool invocation.
LIVE readiness stays false until two different successful destinations with
instrumented tool calls and native sessions are recorded for the published release.

The gateway runs through `Studio.Admin.ControlPlane.Dispatch`; its compiled
metadata and Publisher remain constrained to recognized managed BPL. Schema 2
stores ordered bindings and pinned agent snapshots per point while preserving
legacy manifests. Each release installs its own BPL host; shared Operations are
not reconfigured. Native identity and permissions are rechecked by RuntimeBridge;
authenticated WSGI and browser interaction have been verified locally.

Load `tests/iris/VisualDesignerTest.cls` and run `Run(0)` against a running synthetic
Production to reproduce the multipoint regression. It creates isolated test
agents, drafts and release hosts. New `Run(1)` LIVE validation was not executed:
automatic approval review requires explicit authorization for provider, payload
and possible cost. Existing historical LIVE receipts do not validate this extension.

Runtime audit is in application-owned globals; configuration revisions use
Studio.Model persistent classes. API credentials are not stored in those entities.

`Studio.Admin.RuntimeProbe.Selected()` reports selected SDK signatures;
`CapabilityProbe.Inspect()` provides the bounded full inventory. Neither invokes
models or changes provider configuration. `Studio.Tests.WSGISmoke.Run()` executes
Flask against the real native gateway in an already authenticated job, not a browser
login. See [control plane](../../docs/CONTROL_PLANE.md) for release compatibility
and publication scope. Reload WSGI workers after updating Python/templates; do
not overwrite an installed Production from an original template during upgrades.
