# Boot jarvis_phone (if needed), wait until ADB-ready, then flutter run.
# Or power off a running AVD with -Kill.
# Docs: docs/dev-mobile.md
# Agent skill: .cursor/skills/run-emulator/SKILL.md
#
# Usage (repo root):
#   powershell -NoProfile -ExecutionPolicy Bypass -File tooling/run_emulator.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File tooling/run_emulator.ps1 -Uninstall
#   powershell -NoProfile -ExecutionPolicy Bypass -File tooling/run_emulator.ps1 -BootOnly
#   powershell -NoProfile -ExecutionPolicy Bypass -File tooling/run_emulator.ps1 -DebugLogs
#   powershell -NoProfile -ExecutionPolicy Bypass -File tooling/run_emulator.ps1 -Kill
param(
  [string]$AvdName = 'jarvis_phone',
  [switch]$Uninstall,
  [switch]$BootOnly,
  [switch]$DebugLogs,
  [switch]$Kill,
  [int]$TimeoutSec = 300
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

$sdkRoot = if ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT }
  elseif ($env:ANDROID_HOME) { $env:ANDROID_HOME }
  else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }

$emulator = Join-Path $sdkRoot 'emulator\emulator.exe'
$adb = Join-Path $sdkRoot 'platform-tools\adb.exe'
if (-not (Test-Path $adb)) {
  throw "adb.exe not found under $sdkRoot. Run tooling/setup_android_sdk.ps1 first."
}

function Invoke-AdbText {
  param(
    [Parameter(Mandatory)]
    [string[]]$AdbArgs
  )
  # adb often prints "daemon starting" on stderr; do not treat that as a terminating error.
  # Call as: Invoke-AdbText -AdbArgs @('devices') — do not splat into this function
  # (a leading '-s' would bind as a phantom parameter name).
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $chunks = & $adb @AdbArgs 2>&1 | ForEach-Object {
      if ($_ -is [System.Management.Automation.ErrorRecord]) { $_.Exception.Message }
      else { "$_" }
    }
    return ($chunks -join "`n")
  } finally {
    $ErrorActionPreference = $prev
  }
}

function Get-EmulatorDeviceId {
  # Only a fully online "device" is usable for flutter run / shell.
  $lines = Invoke-AdbText -AdbArgs @('devices')
  $m = [regex]::Match($lines, '(emulator-\d+)\s+device\b')
  if ($m.Success) { return $m.Groups[1].Value }
  return $null
}

function Test-AnyEmulatorListed {
  $lines = Invoke-AdbText -AdbArgs @('devices')
  return [regex]::IsMatch($lines, 'emulator-\d+\s+(?:device|offline|unauthorized)\b')
}

function Get-AllEmulatorSerials {
  $lines = Invoke-AdbText -AdbArgs @('devices')
  $found = [regex]::Matches($lines, '(emulator-\d+)\s+(?:device|offline|unauthorized)\b')
  return @($found | ForEach-Object { $_.Groups[1].Value })
}

if ($Kill) {
  if ($Uninstall -or $BootOnly -or $DebugLogs) {
    throw '-Kill cannot be combined with -Uninstall, -BootOnly, or -DebugLogs.'
  }
  $serials = Get-AllEmulatorSerials
  if ($serials.Count -eq 0) {
    Write-Host 'No emulator listed in adb devices. Nothing to kill.'
    exit 0
  }
  foreach ($serial in $serials) {
    Write-Host "Killing $serial (adb emu kill)..."
    $killOut = Invoke-AdbText -AdbArgs @('-s', $serial, 'emu', 'kill')
    if ($killOut.Trim()) { Write-Host $killOut }
  }
  Start-Sleep -Seconds 2
  $left = Get-AllEmulatorSerials
  if ($left.Count -eq 0) {
    Write-Host 'Emulator stopped.'
  } else {
    Write-Host ("Still listed after kill: " + ($left -join ', ') + '. Close the emulator window or retry.')
    exit 1
  }
  exit 0
}

if (-not (Test-Path $emulator)) {
  throw "emulator.exe not found under $sdkRoot. Run tooling/setup_android_sdk.ps1 first."
}

function Wait-EmulatorReady {
  param([int]$Seconds)
  $deadline = (Get-Date).AddSeconds($Seconds)
  while ((Get-Date) -lt $deadline) {
    $id = Get-EmulatorDeviceId
    if ($id) {
      $boot = (Invoke-AdbText -AdbArgs @('-s', $id, 'shell', 'getprop', 'sys.boot_completed')).Trim()
      # getprop may be buried if adb stderr was merged; accept a trailing 1.
      if ($boot -eq '1' -or $boot -match '(?m)^1\s*$') {
        # Package manager can lag a few seconds after boot_completed.
        Start-Sleep -Seconds 3
        return $id
      }
    }
    Start-Sleep -Seconds 3
  }
  throw "Timed out after ${Seconds}s waiting for $AvdName (adb device + boot_completed)."
}

$deviceId = Get-EmulatorDeviceId
if (-not $deviceId) {
  if (-not (Test-AnyEmulatorListed)) {
    Write-Host "Starting AVD '$AvdName' (cold boot, swiftshader)..."
    Start-Process -FilePath $emulator -ArgumentList @(
      '-avd', $AvdName,
      '-no-snapshot-load',
      '-no-boot-anim',
      '-gpu', 'swiftshader_indirect'
    ) -WindowStyle Normal | Out-Null
  } else {
    Write-Host "Emulator listed but not ready yet (offline); waiting..."
  }
  $deviceId = Wait-EmulatorReady -Seconds $TimeoutSec
} else {
  Write-Host "Emulator already online: $deviceId"
  $boot = (Invoke-AdbText -AdbArgs @('-s', $deviceId, 'shell', 'getprop', 'sys.boot_completed')).Trim()
  if (-not ($boot -eq '1' -or $boot -match '(?m)^1\s*$')) {
    $deviceId = Wait-EmulatorReady -Seconds $TimeoutSec
  }
}

Write-Host "Ready: $deviceId"

if ($Uninstall) {
  Write-Host 'Uninstalling com.example.jarvis_app (if present)...'
  & $adb -s $deviceId uninstall com.example.jarvis_app 2>$null | Out-Null
}

if ($BootOnly) {
  Write-Host "Boot only. Next: flutter run -d $deviceId"
  exit 0
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'flutter not found on PATH.'
}

Write-Host "flutter pub get..."
flutter pub get
$flutterArgs = @('run', '-d', $deviceId)
if ($DebugLogs) {
  $flutterArgs += '-v'
  Write-Host "flutter run -v -d $deviceId (debug logs)"
} else {
  Write-Host "flutter run -d $deviceId"
}
& flutter @flutterArgs
