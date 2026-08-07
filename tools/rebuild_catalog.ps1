# rebuilds catalog.json deterministically from packages/<slug>/ folders
# usage: .\tools\rebuild_catalog.ps1 [-BaseUrl https://raw.githubusercontent.com/lamineheskoura/editoon-extensions/main]
# requirements per package:
#   packages/<slug>/manifest.json        (v2: slug/name/version/minApi/description/author)
#   packages/<slug>/<slug>-<version>.zip (from build_extension.ps1 or a GitHub Release asset)
param(
  [string]$BaseUrl = 'https://raw.githubusercontent.com/lamineheskoura/editoon-extensions/main'
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$packagesDir = Join-Path $root 'packages'

if (-not (Test-Path -LiteralPath $packagesDir)) {
  throw "missing $packagesDir"
}

$entries = @()
Get-ChildItem -LiteralPath $packagesDir -Directory | Sort-Object Name | ForEach-Object {
  $slug = $_.Name
  if ($slug.StartsWith('_')) { return }          # convention: dev folders are skipped
  $manifestPath = Join-Path $_.FullName 'manifest.json'
  if (-not (Test-Path -LiteralPath $manifestPath)) { throw "missing manifest.json in $($_.FullName)" }

  $m = [System.IO.File]::ReadAllText($manifestPath, [System.Text.UTF8Encoding]::new($false)) | ConvertFrom-Json
  if ($m.slug -ne $slug) { throw "manifest slug '$($m.slug)' != folder '$slug'" }
  if (-not $m.version) { throw "manifest.json in $slug is missing version" }

  $zipName = "$slug-$($m.version).zip"
  $zipPath = Join-Path $_.FullName $zipName
  if (-not (Test-Path -LiteralPath $zipPath)) {
    Write-Warning "no $zipName in $slug - add it with .\tools\build_extension.ps1 or attach it to a GitHub Release"
    return
  }

  $hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
  $zipSize = (Get-Item -LiteralPath $zipPath).Length
  $icon = if (Test-Path -LiteralPath (Join-Path $_.FullName 'icon.png')) { "$BaseUrl/packages/$slug/icon.png" } else { '' }
  $minApi = 1
  if ($null -ne $m.minApi) { $minApi = [int]$m.minApi }

  $entries += [ordered]@{
    slug        = $slug
    name        = $m.name
    description = if ($m.description) { $m.description } else { '' }
    author      = if ($m.author) { $m.author } else { '' }
    version     = $m.version
    minApi      = $minApi
    archiveUrl  = "$BaseUrl/packages/$slug/$zipName"
    iconUrl     = $icon
    sizeBytes   = $zipSize
    sha256      = $hash
  }
}

$catalog = [ordered]@{
  version        = 1
  catalogVersion = '1.0.0'
  updatedAt      = (Get-Date -Format 'yyyy-MM-dd')
  extensions     = $entries
}

$out = Join-Path $root 'catalog.json'
$json = $catalog | ConvertTo-Json -Depth 6
[System.IO.File]::WriteAllText($out, $json + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
Write-Host "catalog.json rebuilt: $($entries.Count) extension(s) -> $out"