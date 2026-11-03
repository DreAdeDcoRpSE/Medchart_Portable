# MedChart Portable uninstaller. Does not require elevation.
# Deletes only this portable folder and shortcuts pointing into it.
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent)).TrimEnd('\')
$stop = Join-Path $PSScriptRoot 'Stop-MedChart.ps1'
$data = Join-Path $root 'data'
$runtime = Join-Path $root 'runtime'
$site = Join-Path $root 'medchart'
if (!(Test-Path (Join-Path $root 'Start_MedChart.cmd')) -or
    !(Test-Path $stop) -or !(Test-Path $site) -or !(Test-Path $runtime)) {
    Write-Host 'Uninstall refused: this does not look like a MedChart Portable installation.' -ForegroundColor Red
    exit 1
}
Write-Host ''
Write-Host '=== MedChart Portable Uninstaller ===' -ForegroundColor Cyan
Write-Host "Installation: $root"
Write-Host ''
Write-Host 'This removes the bundled PHP and MariaDB runtimes, MedChart source,'
Write-Host 'local database, encryption configuration, logs and installed files.'
Write-Host 'Medical records stored in this folder will be PERMANENTLY DELETED.' -ForegroundColor Yellow
Write-Host 'Before proceeding, export your records from MedChart if you need them.'
Write-Host ''
$answer = (Read-Host 'Are you sure you want to uninstall MedChart and delete all local records? (Y/N)').Trim()
if ($answer -ine 'Y') { Write-Host 'Cancelled. Nothing removed.'; exit 0 }
Write-Host 'Stopping MedChart servers...'
try { & $stop } catch { Write-Warning "Shutdown reported: $($_.Exception.Message)" }
# Do not remove the folder while one of its recorded servers remains alive.
foreach ($name in @('php','mariadb')) {
    $pidPath = Join-Path $data "$name.pid"
    if (!(Test-Path $pidPath)) { continue }
    $procId = 0
    $pidText = (Get-Content $pidPath -Raw).Trim()
    if (![int]::TryParse($pidText, [ref]$procId)) { continue }
    $process = Get-CimInstance Win32_Process -Filter "ProcessId=$procId" -ErrorAction SilentlyContinue
    if ($process -and [string]$process.ExecutablePath -and
        ([string]$process.ExecutablePath).StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase)) {
        Write-Host "Cannot uninstall: $name is still running (PID $procId)." -ForegroundColor Red
        Write-Host 'Close MedChart, run Stop_MedChart.cmd, and try again.'
        exit 1
    }
}
# Stop only our own watcher process (if still running).
$watcherPidPath = Join-Path $data 'watcher.pid'
if (Test-Path $watcherPidPath) {
    $watcherId = 0
    if ([int]::TryParse((Get-Content $watcherPidPath -Raw).Trim(), [ref]$watcherId)) {
        $watcher = Get-CimInstance Win32_Process -Filter "ProcessId=$watcherId" -ErrorAction SilentlyContinue
        if ($watcher -and $watcher.Name -eq 'powershell.exe' -and
            ([string]$watcher.CommandLine).IndexOf('Shutdown-Watcher.ps1',[StringComparison]::OrdinalIgnoreCase) -ge 0 -and
            ([string]$watcher.CommandLine).IndexOf($root,[StringComparison]::OrdinalIgnoreCase) -ge 0) {
            Stop-Process -Id $watcherId -Force -ErrorAction SilentlyContinue
        }
    }
}
# Only delete shortcuts whose actual target points into this installation.
$desktopPaths = @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('CommonDesktopDirectory')) | Select-Object -Unique
$ws = New-Object -ComObject WScript.Shell
foreach ($desktop in $desktopPaths) {
    if (!(Test-Path $desktop)) { continue }
    foreach ($shortcut in @(Get-ChildItem $desktop -Filter '*.lnk' -File -ErrorAction SilentlyContinue)) {
        try {
            $link = $ws.CreateShortcut($shortcut.FullName)
            $target = [string]$link.TargetPath
            $arguments = [string]$link.Arguments
            $isOurs = ($target.StartsWith($root + '\',[StringComparison]::OrdinalIgnoreCase) -or
                ($target -match '(?i)powershell(?:\.exe)?$' -and $arguments.IndexOf($root,[StringComparison]::OrdinalIgnoreCase) -ge 0))
            if ($isOurs) {
                Remove-Item $shortcut.FullName -Force
                Write-Host "Removed desktop shortcut: $($shortcut.Name)"
            }
        } catch { Write-Warning "Could not inspect shortcut $($shortcut.Name): $($_.Exception.Message)" }
    }
}
# A temporary CMD outside the application deletes the folder after this script exits.
# No registry changes, no global uninstall actions, no admin privileges.
$cleanup = Join-Path ([IO.Path]::GetTempPath()) ("medchart-uninstall-" + [guid]::NewGuid().ToString('N') + '.cmd')
# The path is quoted in CMD. Refuse CMD metacharacters that can break safe quoting.
if ($root.IndexOfAny([char[]]@('"','%','!','^')) -ge 0) {
    Write-Host 'The installation path contains characters unsafe for automatic removal.' -ForegroundColor Red
    Write-Host "Delete this folder manually after stopping MedChart: $root"
    exit 1
}
$cmd = @"
@echo off
setlocal DisableDelayedExpansion
ping -n 3 127.0.0.1 >nul
rmdir /s /q "$root"
if exist "$root\" (
  echo MedChart folder could not be completely removed. Close open files and delete it manually.
) else (
  echo MedChart Portable was removed.
)
del /f /q "%~f0" >nul 2>&1
"@
[IO.File]::WriteAllText($cleanup,$cmd,[Text.Encoding]::ASCII)
Write-Host 'Uninstall confirmed. The application folder will now be removed.'
Start-Process -FilePath $env:ComSpec -ArgumentList @('/c', ('"' + $cleanup + '"')) -WindowStyle Hidden
