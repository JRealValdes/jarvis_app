# Build a personal-sideload release APK and publish it under .app_release/.
# See .cursor/skills/build-apk/SKILL.md
[CmdletBinding()]
param(
  [switch]$SkipFlutterBuild,
  [switch]$NoUpdateReadme,
  [switch]$RemoveOldApks
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

$pubspec = Join-Path $repoRoot 'pubspec.yaml'
if (-not (Test-Path $pubspec)) {
  throw "pubspec.yaml not found at $pubspec"
}

$versionLine = Select-String -Path $pubspec -Pattern '^\s*version:\s*(\S+)' | Select-Object -First 1
if (-not $versionLine) {
  throw 'Could not parse version: from pubspec.yaml'
}
$rawVersion = $versionLine.Matches[0].Groups[1].Value
# Flutter allows 1.2.3+45 — filename uses the name part only.
$versionName = ($rawVersion -split '\+', 2)[0]
if ([string]::IsNullOrWhiteSpace($versionName)) {
  throw "Empty version name parsed from '$rawVersion'"
}

$outDir = Join-Path $repoRoot '.app_release'
$destName = "jarvis_$versionName.apk"
$destPath = Join-Path $outDir $destName
$builtApk = Join-Path $repoRoot 'build\app\outputs\flutter-apk\app-release.apk'

$keyProps = Join-Path $repoRoot 'android\key.properties'
$keystoreHint = Join-Path $repoRoot 'android\sideload.keystore'

Write-Host "Repo:    $repoRoot"
Write-Host "Version: $versionName (pubspec: $rawVersion)"
Write-Host "Output:  $destPath"

if (-not (Test-Path $keyProps)) {
  throw @"
Missing android\key.properties — required for a stable sideload signature.
Copy android\key.properties.example → android\key.properties and point storeFile at the shared sideload keystore (same cert as CI ANDROID_SIDELOAD_* secrets).
See docs\dev-mobile.md. Expected keystore path (gitignored): $keystoreHint
"@
}

if (-not $SkipFlutterBuild) {
  Write-Host 'Running flutter build apk --release ...'
  flutter pub get
  if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed ($LASTEXITCODE)" }
  flutter build apk --release
  if ($LASTEXITCODE -ne 0) { throw "flutter build apk failed ($LASTEXITCODE)" }
}

if (-not (Test-Path $builtApk)) {
  throw "Built APK not found: $builtApk"
}

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

if ($RemoveOldApks) {
  Get-ChildItem -Path $outDir -Filter 'jarvis_*.apk' -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -ne $destPath } |
    ForEach-Object {
      Write-Host "Removing old artifact $($_.Name)"
      Remove-Item $_.FullName -Force
    }
}

Copy-Item -Path $builtApk -Destination $destPath -Force
$item = Get-Item $destPath
$sizeMb = [math]::Round($item.Length / 1MB, 2)
Write-Host "Copied $($item.Length) bytes ($sizeMb MB) -> $destPath"

if (-not $NoUpdateReadme) {
  $readme = Join-Path $repoRoot 'README.md'
  if (-not (Test-Path $readme)) {
    Write-Warning "README.md missing; skipped link update."
  } else {
    $content = Get-Content -Path $readme -Raw -Encoding utf8
    $link = ".app_release/$destName"
    # Match the markdown link only (avoid emoji encoding issues in this script).
    $pattern = '\[Download APK\]\(\.app_release/[^)]+\)[^\r\n]*'
    $replacement = "[Download APK]($link)"
    if ($content -notmatch $pattern) {
      Write-Warning 'README Download line not found; skipped link update.'
    } else {
      $updated = [regex]::Replace($content, $pattern, $replacement, 1)
      if ($updated -ne $content) {
        # UTF8 without BOM keeps README diffs clean on Windows PowerShell 5.x
        $utf8 = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($readme, $updated, $utf8)
        Write-Host "Updated README Download link -> $link"
      } else {
        Write-Host 'README Download link already up to date.'
      }
    }
  }
}

Write-Host ''
Write-Host 'Done.'
Write-Host "APK_PATH=$destPath"
Write-Host "APK_VERSION=$versionName"
Write-Host "APK_BYTES=$($item.Length)"
Write-Host 'SIGNING=sideload-keystore (android/key.properties)'
