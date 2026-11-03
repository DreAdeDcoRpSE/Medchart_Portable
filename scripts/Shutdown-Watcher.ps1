$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$data = Join-Path $root 'data'
$flag = Join-Path $data 'stop-request.flag'
$instanceFile = Join-Path $data 'instance-id.txt'
$heartbeats = Join-Path $data 'heartbeats'
$started = [DateTime]::UtcNow
$seenBrowser = $false
try {
    while ($true) {
        Start-Sleep -Seconds 5
        if (Test-Path $flag) {
            & (Join-Path $PSScriptRoot 'Stop-MedChart.ps1')
            break
        }
        $phpPid = Join-Path $data 'php.pid'
        if (!(Test-Path $phpPid)) { break }
        $phpId = 0
        if (![int]::TryParse((Get-Content $phpPid -Raw).Trim(), [ref]$phpId)) { break }
        if (!(Get-Process -Id $phpId -ErrorAction SilentlyContinue)) { break }
        if (!(Test-Path $instanceFile)) { continue }
        $runId = (Get-Content $instanceFile -Raw).Trim()
        if ($runId -notmatch '^[a-f0-9]{32}$') { continue }
        $now = [DateTime]::UtcNow
        $recent = $false
        if (Test-Path $heartbeats) {
            foreach ($file in (Get-ChildItem $heartbeats -Filter "$runId-*.beat" -File -ErrorAction SilentlyContinue)) {
                $age = ($now - $file.LastWriteTimeUtc).TotalSeconds
                if ($age -le 60) { $recent = $true; $seenBrowser = $true }
                if ($age -gt 3600) { Remove-Item $file.FullName -Force -ErrorAction SilentlyContinue }
            }
        }
        if (!$recent) {
            if ($seenBrowser -or ($now - $started).TotalMinutes -ge 10) {
                & (Join-Path $PSScriptRoot 'Stop-MedChart.ps1')
                break
            }
        }
    }
} catch {
    $logs = Join-Path $root 'logs'
    New-Item -ItemType Directory -Path $logs -Force | Out-Null
    Add-Content (Join-Path $logs 'watcher-error.log') "$(Get-Date -Format o) $($_.Exception.Message)"
} finally {
    Remove-Item (Join-Path $data 'watcher.pid') -Force -ErrorAction SilentlyContinue
}
