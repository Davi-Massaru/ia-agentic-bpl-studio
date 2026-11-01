# Product demonstration script

Target: five minutes after installation and provider setup. Timing is a presentation plan, not a performance measurement.

| Segment | Show | Explain |
|---|---|---|
| 0:00–0:40 | README and native BPL screenshot | Reusable AI decision components for existing IRIS integrations; BloodDemo is only Hello World |
| 0:40–1:30 | Explorer → Create an AI Hub component | Agent instructions, authorized tools, pinned revision, new Operation name and fallback |
| 1:30–2:20 | Native Production and BPL Call | Published Operation, request/response mappings, multiple decision points and native routing |
| 2:20–3:20 | Native Visual Trace | Follow requests and validated responses; inspect AI session and execution IDs |
| 3:20–4:10 | Managed Designer and Publisher | Optional guided templates, typed mappings, source diff and immutable releases |
| 4:10–5:00 | Evidence and scope | Actual tool observations and tokens; USER/READ-tool limits and submission status |

Use the [native guide](NATIVE_BPL.md) for exact mappings. Use the [BloodDemo walkthrough](GETTING_STARTED.md) to teach first use. State that stock and the independent event reviewer are different synthetic tasks; do not present the event agent as a second stock auditor.

Prefer inspecting recorded traces when a fresh call is unnecessary. Label LIVE receipts, SIMULATION and saved-trace inspection accurately. A saved trace incurs no new provider invocation. Keep credentials out of frame.

Closing message: **IRIS executes the workflow. AI Hub supplies the agent. Studio connects configuration, publication and evidence.**

Explain the editing boundary precisely: Studio's managed Designer edits recognized slots; the native BPL editor supports general composition with published agent Operations. No physical stock transfer, measured ROI or official contest approval is claimed. Public video and hosted demo links are not currently supplied.
