$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$runtime=Join-Path $root 'runtime'
$data=Join-Path $root 'data'
$logs=Join-Path $root 'logs'
$site=Join-Path $root 'medchart'
foreach($p in @($runtime,$data,$logs)) {New-Item -ItemType Directory -Force -Path $p | Out-Null}
# Keep launcher logs bounded across restarts (5 MB per file, 3 archives).
function Rotate-PortableLogs {
  $limit = 5MB
  foreach ($file in (Get-ChildItem -Path $logs -File -Filter '*.log' -ErrorAction SilentlyContinue)) {
    if ($file.Length -lt $limit) { continue }
    $oldest = "$($file.FullName).3"
    Remove-Item $oldest -Force -ErrorAction SilentlyContinue
    for ($i = 2; $i -ge 1; $i--) {
      $from = "$($file.FullName).$i"
      $to = "$($file.FullName).$($i+1)"
      if (Test-Path $from) { Move-Item $from $to -Force }
    }
    Move-Item $file.FullName "$($file.FullName).1" -Force
  }
}
Rotate-PortableLogs
function RandomSecret {
  $b=New-Object byte[] 30
  [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b)
  return [Convert]::ToBase64String($b).TrimEnd('=').Replace('+','A').Replace('/','B')
}
function FindExe([string]$name) {
  $items=Get-ChildItem $runtime -Recurse -Filter $name -File -ErrorAction SilentlyContinue
  if($items) { return @($items)[0].FullName }
  return $null
}
function DownloadZip([string]$url,[string]$destination) {
  Write-Host "Downloading portable runtime from $url"
  [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
  Invoke-WebRequest -Uri $url -OutFile $destination -UseBasicParsing
  if((Get-Item $destination).Length -lt 1000000) {throw 'Runtime download is unexpectedly small.'}
}
# Official Windows PHP release manifest. Only PHP 8.4 NTS x64 VS17 is eligible.
function Get-PhpRelease {
  try {
    [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
    $manifest=Invoke-RestMethod -Uri 'https://downloads.php.net/~windows/releases/releases.json' -TimeoutSec 12 -UseBasicParsing
    $release=$manifest.'8.4'
    $zip=$release.'nts-vs17-x64'.zip
    if (!$release -or !$zip) { throw 'Missing PHP 8.4 Windows release metadata.' }
    $name=[string]$zip.path
    $hash=[string]$zip.sha256
    if ($name -notmatch '^php-8\.4\.(\d+)(?:-\d+)?-nts-Win32-vs17-x64\.zip$') {throw 'Unexpected PHP release filename.'}
    $id=80400+[int]$Matches[1]
    if ($hash -notmatch '^[0-9a-fA-F]{64}$') {throw 'Unexpected PHP release checksum.'}
    if ($id -lt 80427) { throw 'PHP release metadata is older than the required security baseline.' }
    return @{Id=$id; Version=[string]$release.version; Url=('https://downloads.php.net/~windows/releases/'+$name); Sha256=$hash}
  } catch {
    Write-Host "Could not check PHP updates: $($_.Exception.Message)" -ForegroundColor Yellow
    return $null
  }
}
function Test-PhpZip([string]$archive,[string]$expectedHash) {
  if ((Get-Item -LiteralPath $archive).Length -lt 1000000) {throw 'PHP ZIP is unexpectedly small.'}
  if ($expectedHash) {
    $actual=(Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
    if ($actual -ine $expectedHash) {throw 'PHP ZIP SHA-256 verification failed.'}
  }
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zip=[IO.Compression.ZipFile]::OpenRead($archive)
  try {
    if (!(@($zip.Entries | Where-Object { $_.FullName -eq 'php.exe' }).Count)) {throw 'PHP ZIP does not contain php.exe.'}
  } finally {$zip.Dispose()}
}
function Install-PhpRelease($release,[bool]$isUpdate) {
  $archive=Join-Path $runtime 'php-update.zip'
  $stage=Join-Path $runtime 'php-stage'
  $active=Join-Path $runtime 'php'
  $backup=Join-Path $runtime 'php-backup'
  if (Test-Path $backup) {throw 'A previous PHP backup exists. Resolve runtime\php-backup before updating.'}
  Remove-Item $archive -Force -ErrorAction SilentlyContinue
  Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
  $movedOld=$false
  try {
    DownloadZip $release.Url $archive
    Test-PhpZip $archive $release.Sha256
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    Expand-Archive -LiteralPath $archive -DestinationPath $stage -Force
    $candidate=Join-Path $stage 'php.exe'
    if (!(Test-Path $candidate)) {throw 'Downloaded PHP runtime is missing php.exe.'}
    $candidateId=[int](& $candidate -n -r 'echo PHP_VERSION_ID;' 2>$null)
    if ($LASTEXITCODE -ne 0 -or $candidateId -ne [int]$release.Id) {throw 'Downloaded PHP runtime version does not match the official release.'}
    if ($isUpdate) {
      $oldIni=Join-Path $active 'php.ini'
      if (Test-Path $oldIni) {Copy-Item -LiteralPath $oldIni -Destination (Join-Path $stage 'php.ini') -Force}
    }
    if (Test-Path $active) {Move-Item -LiteralPath $active -Destination $backup; $movedOld=$true}
    try {
      Move-Item -LiteralPath $stage -Destination $active
    } catch {
      if ($movedOld -and !(Test-Path $active)) {Move-Item -LiteralPath $backup -Destination $active}
      throw
    }
    # Keep the previous runtime available for rollback if a future startup fails.
    # It is removed only after the updated PHP executable has passed verification.
    $newId=[int](& (Join-Path $active 'php.exe') -n -r 'echo PHP_VERSION_ID;' 2>$null)
    if ($LASTEXITCODE -ne 0 -or $newId -ne [int]$release.Id) {throw 'Updated PHP failed its startup check.'}
    if ($movedOld) {Remove-Item -LiteralPath $backup -Recurse -Force}
    Write-Host "PHP $($release.Version) installed successfully." -ForegroundColor Green
    return $true
  } catch {
    Write-Host "PHP installation failed: $($_.Exception.Message)" -ForegroundColor Yellow
    if ($movedOld -and (Test-Path $backup)) {
      if (Test-Path $active) {Remove-Item -LiteralPath $active -Recurse -Force -ErrorAction SilentlyContinue}
      if (!(Test-Path $active)) {Move-Item -LiteralPath $backup -Destination $active}
      Write-Host 'Previous PHP runtime restored.' -ForegroundColor Yellow
    }
    if (!$isUpdate -and !(Test-Path (Join-Path $active 'php.exe'))) {throw}
    return $false
  } finally {
    Remove-Item $archive -Force -ErrorAction SilentlyContinue
    Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
  }
}
function Check-PhpUpdate([string]$exe) {
  $stamp=Join-Path $runtime 'php-update-check.txt'
  if (Test-Path $stamp) {
    try {
      $last=[datetime]::Parse((Get-Content $stamp -Raw).Trim())
      if (([datetime]::UtcNow-$last.ToUniversalTime()).TotalHours -lt 24) {return}
    } catch {}
  }
  $release=Get-PhpRelease
  if (!$release) {return}
  # Cache a successful check for one day, including when the user declines.
  [datetime]::UtcNow.ToString('o') | Set-Content -LiteralPath $stamp -Encoding ASCII
  $current=[int](& $exe -r 'echo PHP_VERSION_ID;')
  if ([int]$release.Id -le $current) {return}
  Write-Host "`nPHP update available: $(& $exe -r 'echo PHP_VERSION;') -> $($release.Version)" -ForegroundColor Cyan
  $answer=Read-Host 'Install this official PHP 8.4 security update now? (y/N)'
  if ($answer -notmatch '^(?i:y|yes)$') {Write-Host 'Update skipped.';return}
  # Never replace PHP while the local MedChart server is running.
  $pidFile=Join-Path $data 'php.pid'
  if (Test-Path $pidFile) {
    $pidText=(Get-Content $pidFile -Raw).Trim()
    $running=Get-Process -Id $pidText -ErrorAction SilentlyContinue
    if ($running -and $running.ProcessName -ieq 'php') {
      Write-Host 'PHP update deferred: MedChart is already running. Stop it first.' -ForegroundColor Yellow
      return
    }
  }
  [void](Install-PhpRelease $release $true)
}
function EnsurePhp {
  $exe=FindExe 'php.exe'
  if(!$exe) {
  $archive=Join-Path $runtime 'php.zip'
  if(!(Test-Path $archive)) {
    # Use the official direct release artifact. Scraping the PHP download HTML
    # is unreliable because download links are generated by the website.
    $urls=@(
      'https://downloads.php.net/~windows/releases/php-8.4.27-1-nts-Win32-vs17-x64.zip'
    )
    $success=$false
    foreach($url in $urls) {
      try {
        DownloadZip $url $archive
        # Reject incomplete or non-ZIP downloads before attempting extraction.
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $test=[IO.Compression.ZipFile]::OpenRead($archive)
        try {
          if(!(@($test.Entries | Where-Object { $_.FullName -eq 'php.exe' }).Count)) {throw 'Downloaded ZIP does not contain php.exe.'}
        } finally {$test.Dispose()}
        $success=$true
        break
      } catch {
        Write-Host "PHP download attempt failed: $($_.Exception.Message)" -ForegroundColor Yellow
        Remove-Item $archive -Force -ErrorAction SilentlyContinue
      }
    }
    if(!$success) {throw 'PHP download failed. Download the official PHP 8.4.27 x64 NTS ZIP and save it as runtime\php.zip.'}
  }
  $dir=Join-Path $runtime 'php'
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  Expand-Archive $archive $dir -Force
  $exe=FindExe 'php.exe'
  if(!$exe) {throw 'PHP ZIP does not contain php.exe.'}
  }
  $version = & $exe -r 'echo PHP_VERSION_ID;'
  if ([int]$version -lt 80427 -or [int]$version -ge 80500) { throw 'This build requires PHP 8.4.27 or later in the 8.4 series. Remove the old runtime\php directory and restart to download the patched version.' }
  $phpDir=Split-Path $exe -Parent
  $ini=Join-Path $phpDir 'php.ini'
  # Refresh path-dependent PHP settings on every launch. The entire portable
  # folder may have been moved since PHP was first downloaded.
  $extensionDir=(Join-Path $phpDir 'ext').Replace('\','/')
  $sessionDir=(Join-Path $data 'sessions').Replace('\','/')
  if(!(Test-Path $ini)) {
    @"
[PHP]
extension_dir="$extensionDir"
extension=pdo_sqlite
extension=sqlite3
extension=openssl
extension=sodium
extension=mbstring
extension=fileinfo
extension=gd
extension=zip
date.timezone=UTC
expose_php=Off
upload_max_filesize=30M
post_max_size=32M
max_execution_time=120
session.save_path="$sessionDir"
session.gc_maxlifetime=1800
session.gc_probability=1
session.gc_divisor=100
display_errors=Off
display_startup_errors=Off
log_errors=On
error_reporting=E_ALL
"@ | Set-Content -Path $ini -Encoding ASCII
  } else {
    # Preserve the existing PHP configuration, only update relocated paths.
    $iniText=[IO.File]::ReadAllText($ini)
    $lineEnd=if($iniText.Contains("`r`n")){"`r`n"}else{"`n"}
    foreach($entry in @(
      @{Name='session.save_path'; Value='"'+$sessionDir+'"'},
      @{Name='session.gc_maxlifetime'; Value='1800'},
      @{Name='session.gc_probability'; Value='1'},
      @{Name='session.gc_divisor'; Value='100'},
      @{Name='display_errors'; Value='Off'},
      @{Name='display_startup_errors'; Value='Off'},
      @{Name='log_errors'; Value='On'},
      @{Name='error_reporting'; Value='E_ALL'},
      @{Name='extension_dir'; Value='"'+$extensionDir+'"'}
    )) {
      $pattern='(?m)^\s*'+[regex]::Escape($entry.Name)+'\s*=.*$'
      $replacement=$entry.Name+'='+$entry.Value
      if([regex]::IsMatch($iniText,$pattern)) {
        $iniText=[regex]::Replace($iniText,$pattern,[System.Text.RegularExpressions.MatchEvaluator]{param($m) $entry.Name+'='+$entry.Value})
      } else {
        $iniText=$iniText.TrimEnd("`r","`n")+$lineEnd+$replacement+$lineEnd
      }
    }
    foreach($extension in @('pdo_sqlite','sqlite3')) {
      if($iniText -notmatch ('(?m)^\s*extension\s*=\s*'+$extension+'\s*$')) {$iniText+=$lineEnd+'extension='+$extension+$lineEnd}
    }
    # Sodium is required to import Argon2id-encrypted chart exports.
    # Ensure it is enabled for already-installed portable PHP runtimes too.
    if($iniText -notmatch '(?m)^\s*extension\s*=\s*["'']?(?:php_)?sodium(?:\.dll)?["'']?\s*(?:;.*)?$') {
      $iniText+=$lineEnd+'extension=sodium'+$lineEnd
    }
    [IO.File]::WriteAllText($ini,$iniText,[Text.Encoding]::ASCII)
  }
  return $exe
}
function FreePort([int]$preferred) {
  $listener=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,$preferred)
  try {$listener.Start(); return ([Net.IPEndPoint]$listener.LocalEndpoint).Port} finally {$listener.Stop()}
}
function WaitPort([int]$port,[int]$seconds) {
  for($i=0;$i -lt $seconds*5;$i++) {
    $client=New-Object Net.Sockets.TcpClient
    try {$client.Connect('127.0.0.1',$port);return $true} catch {Start-Sleep -Milliseconds 200} finally {$client.Dispose()}
  }
  return $false
}
try {
  Write-Host 'MedChart Portable SQLite - preparing local PHP runtime...'
  Write-Host 'First-time download and environment setup may take up to 10+ minutes.'
  Write-Host 'Please leave this window open until MedChart launches.'
  $php=EnsurePhp
  Check-PhpUpdate $php
  $php=EnsurePhp
  # Protect existing MariaDB installations. Conversion of their data is required
  # before running the SQLite edition; never create a blank replacement silently.
  if ((Test-Path (Join-Path $data 'database')) -or (Test-Path (Join-Path $data 'db-provisioned.txt'))) {
    throw 'Existing MariaDB data detected. Back up and migrate the original installation before using the SQLite edition. No files have been deleted.'
  }
  $env:MEDCHART_DB_DRIVER='sqlite'
  $phpPortFile=Join-Path $data 'php-port.txt'
  if(Test-Path $phpPortFile) {$phpPort=[int](Get-Content $phpPortFile -Raw).Trim()} else {$phpPort=FreePort 0;Set-Content $phpPortFile $phpPort}
  $phpPidFile=Join-Path $data 'php.pid'
  $phpRunning=$false
  if(Test-Path $phpPidFile) {
    $existing=Get-Process -Id ([int](Get-Content $phpPidFile -Raw)) -ErrorAction SilentlyContinue
    if($existing -and (WaitPort $phpPort 1)) {$phpRunning=$true}
  }
  if(!$phpRunning) {
    # No MedChart PHP server is running: invalidate any sessions left by a
    # crash, forced termination, or an earlier portable release.
    $sessionFolder = Join-Path $data 'sessions'
    New-Item -ItemType Directory -Force -Path $sessionFolder | Out-Null
    foreach ($folder in @($sessionFolder, $data)) {
      Get-ChildItem -LiteralPath $folder -File -Filter 'sess_*' -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction Stop
    }
    $phpProcess=Start-Process -FilePath $php -ArgumentList @('-S',"127.0.0.1:$phpPort",'-t',"`"$site`"", "`"$(Join-Path $site 'router.php')`"") -WorkingDirectory $site -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logs 'php.out.log') -RedirectStandardError (Join-Path $logs 'php.err.log')
    Set-Content $phpPidFile $phpProcess.Id
    if(!(WaitPort $phpPort 15)) {throw 'PHP failed to start. See logs\php.err.log.'}
  }
  Remove-Item (Join-Path $data 'stop-request.flag') -Force -ErrorAction SilentlyContinue
  $watcherPidFile = Join-Path $data 'watcher.pid'
  $watcherAlive = $false
  if (Test-Path $watcherPidFile) {
    $watcherId = 0
    if ([int]::TryParse((Get-Content $watcherPidFile -Raw).Trim(), [ref]$watcherId)) {
      $watcherAlive = [bool](Get-Process -Id $watcherId -ErrorAction SilentlyContinue)
    }
  }
  if (!$watcherAlive) {
    # New instance invalidates heartbeat files left from a previous run.
    $instanceBytes = New-Object byte[] 16
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($instanceBytes)
    $instanceId = [BitConverter]::ToString($instanceBytes).Replace('-', '').ToLowerInvariant()
    Set-Content (Join-Path $data 'instance-id.txt') $instanceId -Encoding ASCII
    $watcher = Join-Path $PSScriptRoot 'Shutdown-Watcher.ps1'
    $watcherProc = Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',"`"$watcher`"") -WindowStyle Hidden -PassThru
    Set-Content $watcherPidFile $watcherProc.Id
  }
  # Create (or repair) a shortcut for this installation. The shortcut must
  # launch the CMD file, not the localhost URL, so the runtimes start first.
  try {
    $desktop = [Environment]::GetFolderPath('DesktopDirectory')
    if ([string]::IsNullOrWhiteSpace($desktop) -or !(Test-Path -LiteralPath $desktop)) {
      $desktop = [Environment]::GetFolderPath('Desktop')
    }
    if ([string]::IsNullOrWhiteSpace($desktop) -or !(Test-Path -LiteralPath $desktop)) {
      throw 'Windows desktop folder could not be found.'
    }
    $launcher = Join-Path $root 'Start_MedChart.cmd'
    $iconFile = Join-Path $root 'assets\MedChart.ico'
    $linkFile = Join-Path $desktop 'MedChart.lnk'
    $shell = New-Object -ComObject WScript.Shell
    $needsShortcut = $true
    if (Test-Path -LiteralPath $linkFile) {
      $oldLink = $shell.CreateShortcut($linkFile)
      if ([string]::Equals([string]$oldLink.TargetPath, $launcher, [StringComparison]::OrdinalIgnoreCase) -and
          [string]::Equals([string]$oldLink.IconLocation.Split(',')[0], $iconFile, [StringComparison]::OrdinalIgnoreCase)) {
        $needsShortcut = $false
      } elseif (![string]::Equals([string]$oldLink.TargetPath, $launcher, [StringComparison]::OrdinalIgnoreCase)) {
        # Repair stale shortcuts after relocating the portable folder, but
        # never replace a shortcut that still points to an existing installation.
        $previousTarget=[string]$oldLink.TargetPath
        $staleMedChartLink=([IO.Path]::GetFileName($previousTarget) -ieq 'Start_MedChart.cmd') -and !(Test-Path -LiteralPath $previousTarget)
        if(!$staleMedChartLink) {
          $linkFile = Join-Path $desktop 'MedChart Portable.lnk'
        }
        $needsShortcut = $true
      }
    }
    if ($needsShortcut) {
      $link = $shell.CreateShortcut($linkFile)
      $link.TargetPath = $launcher
      $link.WorkingDirectory = $root
      $link.Description = 'Start MedChart Portable'
      if (Test-Path -LiteralPath $iconFile) { $link.IconLocation = $iconFile + ',0' }
      $link.Save()
      Write-Host "Desktop shortcut created: $linkFile"
    }
  } catch {
    Write-Warning "Could not create MedChart desktop shortcut: $($_.Exception.Message)"
  }
  $url="http://127.0.0.1:$phpPort/login.php"
  Write-Host "Opening MedChart at $url"
  Start-Process $url
  Write-Host 'MedChart is running. To stop PHP, double-click Stop_MedChart.cmd.'
} catch {
  Write-Host "`nSTARTUP FAILED: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host 'Check logs in the logs folder. No medical records were deleted.'
  exit 1
}
