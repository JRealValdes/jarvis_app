# One-time Android SDK + AVD bootstrap for jarvis_app on Windows.
# Docs: docs/dev-mobile.md
$ErrorActionPreference = 'Stop'

$sdkRoot = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$cmdToolsZip = Join-Path $env:TEMP 'cmdline-tools.zip'
$cmdToolsUrl = 'https://dl.google.com/android/repository/commandlinetools-win-13114758_latest.zip'
$avdName = 'jarvis_phone'
$systemImage = 'system-images;android-35;google_apis;x86_64'

function Find-JavaHome {
  if ($env:JAVA_HOME -and (Test-Path $env:JAVA_HOME)) {
    return $env:JAVA_HOME
  }
  $msRoot = 'C:\Program Files\Microsoft'
  if (Test-Path $msRoot) {
    $jdk = Get-ChildItem $msRoot -Directory -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -like 'jdk-*' } |
      Sort-Object Name -Descending |
      Select-Object -First 1
    if ($jdk) { return $jdk.FullName }
  }
  throw 'JAVA_HOME not found. Install Microsoft OpenJDK 17 (winget install Microsoft.OpenJDK.17).'
}

function Ensure-UserEnv {
  param([string]$Name, [string]$Value)
  [Environment]::SetEnvironmentVariable($Name, $Value, 'User')
}

function Ensure-UserPathEntry {
  param([string]$Entry)
  $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  if ([string]::IsNullOrEmpty($userPath)) { $userPath = '' }
  if ($userPath -notlike "*$Entry*") {
    [Environment]::SetEnvironmentVariable('Path', "$Entry;$userPath", 'User')
  }
}

$javaHome = Find-JavaHome
$env:JAVA_HOME = $javaHome
$env:ANDROID_HOME = $sdkRoot
$env:ANDROID_SDK_ROOT = $sdkRoot

New-Item -ItemType Directory -Force -Path $sdkRoot | Out-Null

$sdkmanager = Join-Path $sdkRoot 'cmdline-tools\latest\bin\sdkmanager.bat'
if (-not (Test-Path $sdkmanager)) {
  Write-Host "Downloading Android cmdline-tools..."
  Invoke-WebRequest -Uri $cmdToolsUrl -OutFile $cmdToolsZip -UseBasicParsing
  $extract = Join-Path $env:TEMP 'cmdline-tools-extract'
  if (Test-Path $extract) { Remove-Item $extract -Recurse -Force }
  Expand-Archive -Path $cmdToolsZip -DestinationPath $extract -Force
  $destParent = Join-Path $sdkRoot 'cmdline-tools'
  New-Item -ItemType Directory -Force -Path $destParent | Out-Null
  $latest = Join-Path $destParent 'latest'
  if (Test-Path $latest) { Remove-Item $latest -Recurse -Force }
  Move-Item (Join-Path $extract 'cmdline-tools') $latest
}

$env:Path = "$javaHome\bin;$sdkRoot\cmdline-tools\latest\bin;$sdkRoot\platform-tools;$sdkRoot\emulator;$env:Path"

Write-Host "JAVA_HOME=$javaHome"
Write-Host "ANDROID_HOME=$sdkRoot"

# Seed common license hashes, then accept any remaining via sdkmanager.
$licDir = Join-Path $sdkRoot 'licenses'
New-Item -ItemType Directory -Force -Path $licDir | Out-Null
Set-Content -Path (Join-Path $licDir 'android-sdk-license') -Value "24333f8a63b6825ea9c5514f83c2829b004d1fee"
Set-Content -Path (Join-Path $licDir 'android-sdk-preview-license') -Value "84831b9409646a918e30573bab4c9c91346d8abd"
Set-Content -Path (Join-Path $licDir 'google-gdk-license') -Value "33b6a2b64607f11b759f320ef9dff4ae5c47d97a"
Set-Content -Path (Join-Path $licDir 'mips-android-sysimage-license') -Value "e9acab5b5f1891c7eb40c7ed7d5b00e8fbf09d98"

$yesFile = Join-Path $env:TEMP 'android-license-yes.txt'
(1..80 | ForEach-Object { 'y' }) -join "`n" | Set-Content -Path $yesFile -Encoding ascii
Get-Content $yesFile | & $sdkmanager --sdk_root=$sdkRoot --licenses | Out-Null

$packages = @(
  'platform-tools',
  'emulator',
  'platforms;android-35',
  'platforms;android-36',
  'build-tools;28.0.3',
  'build-tools;35.0.0',
  'build-tools;36.0.0',
  $systemImage
)

Write-Host "Installing SDK packages (may take several minutes)..."
& $sdkmanager --sdk_root=$sdkRoot --install $packages

$avdManager = Join-Path $sdkRoot 'cmdline-tools\latest\bin\avdmanager.bat'
$avdList = & $avdManager list avd 2>&1 | Out-String
if ($avdList -notmatch [regex]::Escape($avdName)) {
  Write-Host "Creating AVD $avdName..."
  "no" | & $avdManager create avd `
    --name $avdName `
    --package $systemImage `
    --device pixel_6 `
    --force
} else {
  Write-Host "AVD $avdName already exists."
}

Ensure-UserEnv -Name 'ANDROID_HOME' -Value $sdkRoot
Ensure-UserEnv -Name 'ANDROID_SDK_ROOT' -Value $sdkRoot
Ensure-UserEnv -Name 'JAVA_HOME' -Value $javaHome
Ensure-UserPathEntry -Entry "$javaHome\bin"
Ensure-UserPathEntry -Entry "$sdkRoot\cmdline-tools\latest\bin"
Ensure-UserPathEntry -Entry "$sdkRoot\platform-tools"
Ensure-UserPathEntry -Entry "$sdkRoot\emulator"

Write-Host ""
Write-Host "SDK bootstrap finished. Next:"
Write-Host "  flutter config --android-sdk `"$sdkRoot`""
Write-Host "  flutter doctor --android-licenses"
Write-Host "  flutter doctor"
Write-Host "  See docs/dev-mobile.md for emulator launch tips."
