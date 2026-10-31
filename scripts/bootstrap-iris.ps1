[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$composePath = Join-Path $projectRoot 'deploy/docker-compose.yaml'
$engine = & docker info --format '{{.ServerVersion}}'
if ($LASTEXITCODE -ne 0 -or "$engine" -notmatch '^\d+\.\d+\.\d+[\w.+-]*$') { throw 'Docker Engine is unavailable.' }
& docker compose -p agentic-bpl-studio -f $composePath up -d
if ($LASTEXITCODE -ne 0) { throw 'Compose startup failed. Load/tag the Community build154 image first.' }
$ready = $false
for ($attempt = 0; $attempt -lt 30; $attempt++) {
    $instance = & docker exec agentic-bpl-studio-iris-1 iris qlist IRIS 2>$null
    if ($LASTEXITCODE -eq 0 -and "$instance" -match '\^running,') { $ready = $true; break }
    Start-Sleep -Seconds 2
}
if (-not $ready) { throw 'IRIS startup timed out; inspect docker logs.' }
& docker exec -u irisowner agentic-bpl-studio-iris-1 python3 -m pip install --target /durable/studio-python 'Flask>=3.0,<4' 'jsonschema>=4.23,<5'
if ($LASTEXITCODE -ne 0) { throw 'Python dependency installation failed.' }
$output = Get-Content -LiteralPath (Join-Path $projectRoot 'deploy/bootstrap/install.script') | & docker exec -i agentic-bpl-studio-iris-1 iris session IRIS -U USER
$output | Write-Output
if ($LASTEXITCODE -ne 0 -or -not ($output -contains 'STUDIO_BOOTSTRAP_OK=1')) { throw 'Native compilation/bootstrap failed.' }
Write-Output 'IRIS Studio classes and sandbox Production installed. Web authentication and AI provider require their explicit configuration.'
