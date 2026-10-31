[CmdletBinding()]
param([string]$Container = 'agentic-bpl-studio-iris-1')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$nativeCommands = @'
Do $SYSTEM.OBJ.Load("/opt/studio/tests/RuntimeIntegration.cls","ck")
Write "STUDIO_EVIDENCE=",##class(Studio.Tests.RuntimeIntegration).Run(),!
Halt
'@
$nativeOutput = $nativeCommands | & docker exec -i $Container iris session IRIS -U USER
if ($LASTEXITCODE -ne 0) { throw 'Native IRIS command failed.' }
$evidenceLine = $nativeOutput | Where-Object { $_.StartsWith('STUDIO_EVIDENCE=') } | Select-Object -Last 1
if (-not $evidenceLine) { throw 'IRIS returned no validation evidence. Inspect compiler/runtime errors.' }
$evidenceJson = $evidenceLine.Substring('STUDIO_EVIDENCE='.Length)
$evidence = $evidenceJson | ConvertFrom-Json
$validationDir = Join-Path $projectRoot 'validation'
New-Item -ItemType Directory -Force -Path $validationDir | Out-Null
Set-Content -LiteralPath (Join-Path $validationDir 'iris154.json') -Value $evidenceJson -Encoding utf8
if (-not $evidence.ok) { throw 'Native simulation integration failed. See validation/iris154.json.' }
Write-Output "Native IRIS simulation: PASS ($($evidence.runs.Count) traced messages). AI provider: NOT VALIDATED."
