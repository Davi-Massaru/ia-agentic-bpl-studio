[CmdletBinding()]
param([string]$Container = 'agentic-bpl-studio-iris-1')
$ErrorActionPreference = 'Stop'
$commands = @'
Set sc=$SYSTEM.OBJ.Load("/opt/studio/tests/WorkspaceTest.cls","ck")
If $SYSTEM.Status.IsError(sc) Halt
Set sc=$SYSTEM.OBJ.Load("/opt/studio/tests/WorkflowRuntimeTest.cls","ck")
If $SYSTEM.Status.IsError(sc) Halt
Set evidence=##class(Studio.Tests.WorkspaceTest).Run()
Write "WORKSPACE_EVIDENCE=",evidence,!
Set result=##class(%DynamicObject).%FromJSON(evidence)
Set sc=##class(Studio.Tests.WorkflowRuntimeTest).Run(result.releaseId)
If $SYSTEM.Status.IsError(sc) Do $SYSTEM.Status.DisplayError(sc) Halt
Write "STUDIO_GENERIC_OK=1",!
Halt
'@
$output = $commands | & docker exec -i $Container iris session IRIS -U USER
$output | Write-Output
if ($LASTEXITCODE -ne 0 -or -not ($output -contains 'STUDIO_GENERIC_OK=1')) { throw 'Generic native validation failed.' }
Write-Output 'Native publication, rollback and explicit local simulation passed. LIVE AI remains separate.'
