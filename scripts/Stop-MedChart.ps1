$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent)).TrimEnd('\')
$data = Join-Path $root 'data'
function Stop-RecordedProcess([string]$name, [string[]]$allowedNames) {
    $pidFile = Join-Path $data "$name.pid"
    if (!(Test-Path $pidFile)) { return }
    $idText = (Get-Content $pidFile -Raw).Trim()
    $idNumber = 0
    if (![int]::TryParse($idText, [ref]$idNumber)) { Write-Warning "Invalid $name PID"; return }
    $proc = Get-CimInstance Win32_Process -Filter "ProcessId=$idNumber" -ErrorAction SilentlyContinue
    if (!$proc) { Remove-Item $pidFile -Force; return }
    $actualPath = [string]$proc.ExecutablePath
    if ($allowedNames -notcontains [string]$proc.Name -or !$actualPath.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase)) {
        Write-Warning "Refusing to stop $name PID ${idNumber}: process does not belong to MedChart ($actualPath)."
        return
    }
    # PHP's built-in server does not provide a graceful shutdown command.
        if (Get-Process -Id $idNumber -ErrorAction SilentlyContinue) {
            & taskkill.exe /PID $idNumber /T /F 2>&1 | Out-Host
        }
        Start-Sleep -Milliseconds 400
        if (Get-Process -Id $idNumber -ErrorAction SilentlyContinue) {
            Stop-Process -Id $idNumber -Force -ErrorAction SilentlyContinue
        }
    if (!(Get-Process -Id $idNumber -ErrorAction SilentlyContinue)) {
        Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
        Write-Host "Stopped $name."
    } else { Write-Warning "Could not stop $name PID $idNumber." }
}
Stop-RecordedProcess 'php' @('php.exe')
# Never erase sessions while a recorded MedChart PHP process is still running.
$phpPidFile = Join-Path $data 'php.pid'
if (!(Test-Path -LiteralPath $phpPidFile)) {
    foreach ($folder in @((Join-Path $data 'sessions'), $data)) {
        if (Test-Path -LiteralPath $folder) {
            Get-ChildItem -LiteralPath $folder -File -Filter 'sess_*' -ErrorAction SilentlyContinue |
                Remove-Item -Force -ErrorAction Stop
        }
    }
    Write-Host 'MedChart session files cleared.'
} else {
    Write-Warning 'PHP shutdown not confirmed; session files preserved.'
}
Remove-Item (Join-Path $data 'stop-request.flag') -Force -ErrorAction SilentlyContinue
Write-Host 'MedChart stop sequence completed.'
