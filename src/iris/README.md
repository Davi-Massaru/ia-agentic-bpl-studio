# IRIS sources — current validation

Community 2026.3.0AI Build154U is running in the local project container. Studio
classes, the BPL template and READ ToolSet have compiled successfully. Native
administrative tests and three Production messages passed. Evidence and current
limits: `../../SPEC/IMPLEMENTATION_STATUS.md` and `../../validation/iris154.json`.

Run `scripts/bootstrap-iris.ps1` from the project root to compile/install the
allowlisted example, and `scripts/native-smoke.ps1` for deterministic native tests.
The scripts preserve a dedicated Docker volume and refuse unrelated Productions.

`Studio.AI.AgentRuntimeAdapter` uses Provider.Create, Agent.%New, UseToolSet,
CreateSession, Chat and Session.GetStats signatures inspected on this exact build.
This is compiled integration code, not proof of an actual provider/tool invocation.
LIVE readiness stays false until two different successful destinations with
instrumented tool calls and native sessions are recorded for the published release.

The gateway runs through `Studio.Admin.ControlPlane.Dispatch`; its compiled
metadata and Publisher are constrained to the installed managed BPL. Native
identity and permissions are rechecked by `RuntimeBridge`. Web-account creation
and the authenticated WSGI application are pending explicit approval.

Runtime audit is in application-owned globals; configuration revisions use
Studio.Model persistent classes. API credentials are not stored in those entities.

`Studio.Admin.RuntimeProbe.Selected()` reports selected SDK signatures;
`CapabilityProbe.Inspect()` provides the bounded full inventory. Neither invokes
models or changes provider configuration. `Studio.Tests.WSGISmoke.Run()` executes
Flask against the real native gateway in an already authenticated job, not a browser
login. See `docs/CONTROL_PLANE.md` for release compatibility and publication scope.
