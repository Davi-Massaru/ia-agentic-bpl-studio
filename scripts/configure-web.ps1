[CmdletBinding()]
param([string]$Container = 'agentic-bpl-studio-iris-1')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$privateDir = Join-Path $projectRoot '.local'
New-Item -ItemType Directory -Force -Path $privateDir | Out-Null
$credentialPath = Join-Path $privateDir 'studio-auth.json'
if (-not (Test-Path -LiteralPath $credentialPath)) {
    $bytes = New-Object byte[] 32
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    $json = @{username='studio'; password=[Convert]::ToBase64String($bytes)} | ConvertTo-Json
    [System.IO.File]::WriteAllText($credentialPath, $json, (New-Object System.Text.UTF8Encoding($false)))
}
& docker cp $credentialPath "${Container}:/tmp/studio-auth.json"
if ($LASTEXITCODE -ne 0) { throw 'Credential staging failed.' }
try {
    $commands = @'
Set sc=##class(Studio.Admin.WebSetup).Configure()
If $SYSTEM.Status.IsError(sc) Do $SYSTEM.Status.DisplayError(sc) Halt
Set sc=##class(Studio.Admin.Settings).Provision()
If $SYSTEM.Status.IsError(sc) Do $SYSTEM.Status.DisplayError(sc) Halt
Write "STUDIO_WEB_OK=1",!
Halt
'@
    $output = $commands | & docker exec -i $Container iris session IRIS -U USER
    if ($LASTEXITCODE -ne 0 -or -not ($output -contains 'STUDIO_WEB_OK=1')) { throw 'Web configuration failed.' }
} finally {
    & docker exec -u root $Container rm -f /tmp/studio-auth.json | Out-Null
}
Write-Output 'Studio: http://127.0.0.1:52773/csp/studio/ . Credentials are in .local/studio-auth.json; keep this file private.'
