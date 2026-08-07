# validates the whole store: every package folder + catalog consistency
# usage: .\tools\validate_store.ps1
# exits 1 with a report if anything is broken (run in CI on every push).
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$packagesDir = Join-Path $root 'packages'
$catalogPath = Join-Path $root 'catalog.json'

$errors = @()
$warnings = @()

if (-not (Test-Path -LiteralPath $catalogPath)) { throw 'missing catalog.json' }
$catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json

foreach ($slug in ($catalog.extensions | ForEach-Object { $_.slug })) {
  $dir = Join-Path $packagesDir $slug
  if (-not (Test-Path -LiteralPath $dir)) {
    $errors += "catalog entry '${slug}' has no packages/${slug} folder"
    continue
  }
  $manifestPath = Join-Path $dir 'manifest.json'
  if (-not (Test-Path -LiteralPath $manifestPath)) {
    $errors += "${slug}: missing manifest.json"
    continue
  }
  $m = [System.IO.File]::ReadAllText($manifestPath, [System.Text.UTF8Encoding]::new($false)) | ConvertFrom-Json

  if ($m.slug -ne $slug) { $errors += "${slug}: manifest slug '$($m.slug)' != folder" }
  if (-not $m.version) { $errors += "${slug}: manifest missing version" }
  if ($null -eq $m.minApi) { $errors += "${slug}: manifest missing minApi" }
  if (-not $m.name) { $errors += "${slug}: manifest missing name" }
  if ($m.minApi -gt 2) { $warnings += "${slug}: minApi $($m.minApi) > 2 - releases older than OEP(2) will reject it" }

  foreach ($f in @('init.lua')) {
    if (-not (Test-Path -LiteralPath (Join-Path $dir $f))) { $errors += "${slug}: missing $f" }
  }
  $iconOk = Test-Path -LiteralPath (Join-Path $dir 'icon.png')
  $catalogEntry = $catalog.extensions | Where-Object { $_.slug -eq $slug }
  if (-not $iconOk -and $catalogEntry.iconUrl) { $warnings += "${slug}: catalog has iconUrl but no icon.png in folder" }
  if ($m.icon -and -not $iconOk) { $errors += "${slug}: manifest declares icon '$($m.icon)' but file missing" }

  $zipName = "${slug}-$($m.version).zip"
  $zipPath = Join-Path $dir $zipName
  if (-not (Test-Path -LiteralPath $zipPath)) {
    $errors += "${slug}: missing $zipName - run .\tools\build_extension.ps1 or attach to a GitHub Release"
  } else {
    if (-not $catalogEntry.sha256) { $errors += "${slug}: catalog entry missing sha256" }
    $hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
    if ($hash -ne $catalogEntry.sha256) { $errors += "${slug}: sha256 mismatch - run .\tools\rebuild_catalog.ps1" }
    if ($catalogEntry.archiveUrl -notmatch "${slug}-$([regex]::Escape($m.version))\.zip$") { $warnings += "${slug}: archiveUrl doesn't match folder version" }
    if ($null -eq $catalogEntry.sizeBytes) { $errors += "${slug}: catalog entry missing sizeBytes" }
    elseif ($catalogEntry.sizeBytes -ne (Get-Item -LiteralPath $zipPath).Length) {
      $errors += "${slug}: sizeBytes mismatch - run .\tools\rebuild_catalog.ps1"
    }
  }

  try {
    $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
    $innerManifest = $zip.Entries | Where-Object { $_.Name -eq 'manifest.json' } | Select-Object -First 1
    if ($innerManifest) {
      $reader = [System.IO.StreamReader]::new($innerManifest.Open())
      $innerJson = $reader.ReadToEnd() | ConvertFrom-Json
      $reader.Dispose()
      if ($innerJson.slug -ne $slug) { $errors += "${slug}: zip contains manifest with slug '$($innerJson.slug)'" }
      if ($innerJson.version -ne $m.version) { $errors += "${slug}: zip version '$($innerJson.version)' != folder version '$($m.version)'" }
    } else {
      $errors += "${slug}: zip has no manifest.json at any level"
    }
    $zip.Dispose()
  } catch {
    $errors += "${slug}: zip unreadable ($_)"
  }
}

Write-Host '=== store validation ==='
Write-Host "extensions in catalog: $($catalog.extensions.Count)"
if ($warnings.Count) { Write-Host 'warnings:'; $warnings | ForEach-Object { Write-Host "  WARN $_" } }
if ($errors.Count) {
  Write-Host 'errors:' -ForegroundColor Red
  $errors | ForEach-Object { Write-Host "  ERR $_" -ForegroundColor Red }
  Write-Host "validation FAILED ($($errors.Count) error(s))" -ForegroundColor Red
  exit 1
}
Write-Host 'validation OK' -ForegroundColor Green
exit 0
