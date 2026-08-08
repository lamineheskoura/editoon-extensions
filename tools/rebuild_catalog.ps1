# rebuilds catalog.json deterministically from packages/<slug>/ folders
# usage: .\tools\rebuild_catalog.ps1 [-BaseUrl https://raw.githubusercontent.com/lamineheskoura/editoon-extensions/main]
# requirements per package:
#   packages/<slug>/manifest.json        (v2: slug/name/version/minApi/description/author)
#   packages/<slug>/<slug>-<version>.zip (from build_extension.ps1 or a GitHub Release asset)
# NOTE: the JSON is emitted by hand (fixed key order, LF line endings, no BOM) so the
# output is byte-identical on Windows PowerShell 5.1, pwsh 7, and any CI runner.
param(
  [string]$BaseUrl = 'https://raw.githubusercontent.com/lamineheskoura/editoon-extensions/main'
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$packagesDir = Join-Path $root 'packages'

if (-not (Test-Path -LiteralPath $packagesDir)) {
  throw "missing $packagesDir"
}

function ConvertTo-JsonString([string]$Value) {
  if ($null -eq $Value) { return '""' }
  return '"' + $Value.Replace('\', '\\').Replace('"', '\"') + '"'
}

$nl = "`n"
function AppendLine([System.Text.StringBuilder]$Sb, [string]$Text) {
  [void]$Sb.Append($Text).Append($nl)
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
  $category = if ($m.category) { $m.category } else { 'tool' }
  $subcategory = if ($m.subcategory) { $m.subcategory } else { '' }

  $entries += [ordered]@{
    slug        = $slug
    name        = $m.name
    description = if ($m.description) { $m.description } else { '' }
    author      = if ($m.author) { $m.author } else { '' }
    version     = $m.version
    minApi      = $minApi
    category    = $category
    subcategory = $subcategory
    archiveUrl  = "$BaseUrl/packages/$slug/$zipName"
    iconUrl     = $icon
    sizeBytes   = $zipSize
    sha256      = $hash
  }
}

$updatedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd')

$sb = [System.Text.StringBuilder]::new()
AppendLine $sb '{'
AppendLine $sb '  "version": 1,'
AppendLine $sb '  "catalogVersion": "1.0.0",'
AppendLine $sb "  `"updatedAt`": `"$updatedAt`","
AppendLine $sb '  "extensions": ['
for ($i = 0; $i -lt $entries.Count; $i++) {
  $e = $entries[$i]
  $comma = if ($i -lt $entries.Count - 1) { ',' } else { '' }
AppendLine $sb '    {'
  AppendLine $sb ('      "slug": ' + (ConvertTo-JsonString $e.slug) + ',')
  AppendLine $sb ('      "name": ' + (ConvertTo-JsonString $e.name) + ',')
  AppendLine $sb ('      "description": ' + (ConvertTo-JsonString $e.description) + ',')
  AppendLine $sb ('      "author": ' + (ConvertTo-JsonString $e.author) + ',')
  AppendLine $sb ('      "version": ' + (ConvertTo-JsonString $e.version) + ',')
  AppendLine $sb ("      `"minApi`": $($e.minApi),")
  AppendLine $sb ('      "category": ' + (ConvertTo-JsonString $e.category) + ',')
  AppendLine $sb ('      "subcategory": ' + (ConvertTo-JsonString $e.subcategory) + ',')
  AppendLine $sb ('      "archiveUrl": ' + (ConvertTo-JsonString $e.archiveUrl) + ',')
  AppendLine $sb ('      "iconUrl": ' + (ConvertTo-JsonString $e.iconUrl) + ',')
  AppendLine $sb ("      `"sizeBytes`": $($e.sizeBytes),")
  AppendLine $sb ("      `"sha256`": `"$($e.sha256)`"")
  AppendLine $sb "    }$comma"
}
AppendLine $sb '  ]'
AppendLine $sb '}'

$out = Join-Path $root 'catalog.json'
[System.IO.File]::WriteAllText($out, $sb.ToString(), [System.Text.UTF8Encoding]::new($false))
Write-Host "catalog.json rebuilt: $($entries.Count) extension(s) -> $out"