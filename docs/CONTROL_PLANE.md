# Native administrative control plane

The current UI uses an authenticated WSGI/Flask API backed by IRIS classes and Embedded Python. It targets `USER` and requires native `%Development` access. JSON does not select a different identity or namespace. CSRF is required for mutations.

## Current responsibility split

| Component | Responsibility |
|---|---|
| `backend/studio/api/routes.py` | HTTP payload boundaries and gateway dispatch |
| `Studio.Admin.Workspace` + `studio.native.workspace` | Production discovery, template drafts, generated BPL releases, portable components and host installation |
| `Studio.Admin.ControlPlane` | Agent revisions, authorization and retained legacy blood-routing configuration APIs |
| `Studio.Admin.BPLReader` | Native source and activity inspection |
| `Studio.Interop.PortableAgentOperation` | Execute a pinned agent configuration when called by a native workflow |

The original fixed `blood-routing` APIs remain in the source for the earlier example. They do not describe the scope of the current Workspace UI. Consult the dispatch in [workspace.py](../backend/studio/native/workspace.py) for the current behavior.

## Two publication paths

**Managed workflow:** create a draft from an installed template, attach its decision slot, map typed inputs and outputs, choose an agent revision and static destinations, validate, preview the source/configuration diff and publish. Source hash and revision checks detect conflicts. Each release has a generated BPL class and its own host. Idempotency keys replay the same successful publication and reject different payload reuse. Activation requires the target Production to be running. A rollback prepares a new draft from a prior release; it does not undo external effects.

**Portable component:** `POST /api/v1/components` requires exactly `production`, `hostName`, `agentId`, `agentRevision`, `allowedActions`, `fallbackAction` and `policy`. Publication verifies the selected installed Production and agent revision, validates actions/policy, compiles a subclass of `Studio.Interop.PortableAgentOperation`, stores a pinned agent snapshot and installs a new host. It refuses host-name collisions. It requires no managed workflow or release. This path has no managed Publisher diff or equivalent idempotency key. To update behavior, publish another host and deliberately change the native caller.

Generated Operations expose `ComponentId` in native Production settings. Runtime verifies that the stored Production and host match the running host. Native BPL owns message mappings, deadline handling and downstream routing.

## Persistence and restoration

Current Workspace drafts, manifests, component snapshots and indexes are stored under `^StudioWorkspace`; shared agent revisions use `Studio.Model.AgentDefinition`. The retained legacy control plane uses `^StudioControl` and its model classes. Do not substitute a latest draft for a pinned runtime snapshot.

`Studio.Admin.Workspace.ReconcileDeployments()` restores generated release hosts whose source hash matches and installed portable component hosts. Manually added example Services/Processes are not in that registry and may need re-adding after a source bootstrap reload. Compilation and Production configuration are operational side effects; metadata alone is not an atomic rollback of those effects.

## Runtime and evidence

Managed tests support SIMULATION and LIVE. Portable agent Operations currently execute LIVE; SIMULATION is not an option on that path. Publication itself makes no provider call and does not certify provider readiness. Agent/session creation occurs per invocation through AI Hub. Tools are allowlisted READ ToolSets; additional domain tools and policies require code.

Native messages and Visual Trace show request/response transport. Studio audit records agent revision, component or release identity, AI session, decision, observed tools and usage. Exported reasoning is redacted; native message bodies remain subject to IRIS message permissions. Correlation between a native message session and portable agent traces is demonstrated by the test harness; it should not be confused with every audit row automatically containing a message ID.

[Native composition](NATIVE_BPL.md) · [Managed configuration](AGENT_GUIDE.md) · [Provider setup](CONFIGURATION.md)
