<# Load a user-supplied EAP archive and verify an explicit image ID/name.
   No download, image publication, container start or namespace mutation.
   Example: ./deploy/prepare-image.ps1 -Archive C:/Downloads/iris-community-2026.3.0AI.154.0-docker.tar.gz -LoadedImage '<loaded-image-name>'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Archive,
    [Parameter(Mandatory = $true)][string]$LoadedImage
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $Archive -PathType Leaf)) {
    throw 'EAP archive not found. Obtain Community AI Hub build 154 from the InterSystems portal.'
}
if ([string]::IsNullOrWhiteSpace($LoadedImage) -or $LoadedImage.StartsWith('-')) {
    throw 'Provide the explicit loaded image name or ID.'
}
$archivePath = (Resolve-Path -LiteralPath $Archive).Path
$engineVersion = & docker info --format '{{.ServerVersion}}'
if ($LASTEXITCODE -ne 0 -or "$engineVersion" -notmatch '^\d+\.\d+\.\d+[\w.+-]*$') { throw 'Docker Engine unavailable.' }
& docker image load --input $archivePath
if ($LASTEXITCODE -ne 0) { throw 'Image load failed.' }
& docker image inspect $LoadedImage --format '{{.Id}}'
if ($LASTEXITCODE -ne 0) { throw 'Loaded image not found. Inspect docker image ls and supply its exact name.' }
$targetTag = 'iris-community:2026.3.0AI.154.0'
$existingId = & docker image inspect $targetTag --format '{{.Id}}' 2>$null
$sourceId = & docker image inspect $LoadedImage --format '{{.Id}}'
if ($LASTEXITCODE -ne 0 -or "$sourceId" -notmatch '^sha256:[a-f0-9]{64}$') { throw 'Cannot inspect source image.' }
if ($existingId -and ($existingId -ne $sourceId)) {
    throw 'Target tag already identifies another image. Resolve this conflict explicitly before retrying.'
}
& docker image tag $LoadedImage $targetTag
if ($LASTEXITCODE -ne 0) { throw 'Local image tagging failed.' }
Write-Output 'Local alias prepared. Verify $ZVERSION inside IRIS; a tag does not prove build compatibility.'
