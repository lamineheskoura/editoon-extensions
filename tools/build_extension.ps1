# builds a store package zip + prints its sha256 + ready catalog entry
# usage: .\tools\build_extension.ps1 -Slug progress -Version 1.0.0
param(
  [Parameter(Mandatory = $true)][string]$Slug,
  [Parameter(Mandatory = $true)][string]$Version,
  [string]$Name = $Slug,
  [string]$Description = '',
  [string]$Author = 'HunterToon',
  [int]$MinApi = 2
)

$ErrorActionPreference = 'Stop'
$dir = Join-Path (Join-Path $PSScriptRoot '..\packages') $Slug
if (-not (Test-Path -LiteralPath (Join-Path $dir 'manifest.json'))) {
  throw "missing $dir\manifest.json"
}

$zipName = "$Slug-$Version.zip"
$zipPath = Join-Path $dir $zipName

$files = @('manifest.json', 'init.lua')
foreach ($f in @('queue.lua', 'fit.lua', 'inspect.lua', 'icon.png')) {
  if (Test-Path -LiteralPath (Join-Path $dir $f)) { $files += $f }
}
$src = foreach ($f in $files) { Join-Path $dir $f }

Compress-Archive -Path $src -DestinationPath $zipPath -Force

$hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
$size = (Get-Item -LiteralPath $zipPath).Length
$owner = (git config --global remote.origin.url 2>$null | Out-String).Trim()
$base = "https://raw.githubusercontent.com/lamineheskoura/editoon-extensions/main"
$icon = if (Test-Path -LiteralPath (Join-Path $dir 'icon.png')) { "$base/packages/$Slug/icon.png" } else { '' }

Write-Host "`nbuilt $zipPath ($size bytes)"
Write-Host "sha256: $hash`n"
Write-Host "catalog entry:"
Write-Host '  {'
Write-Host "    `"slug`": `"$Slug`","
Write-Host "    `"name`": `"$Name`","
Write-Host "    `"description`": `"$Description`","
Write-Host "    `"author`": `"$Author`","
Write-Host "    `"version`": `"$Version`","
Write-Host "    `"minApi`": $MinApi,"
Write-Host "    `"archiveUrl`": `"$base/packages/$Slug/$zipName`","
Write-Host "    `"iconUrl`": `"$icon`","
Write-Host "    `"sizeBytes`": $size,"
Write-Host "    `"sha256`": `"$hash`""
Write-Host '  }'
