@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Uninstall-MedChart.ps1"
if errorlevel 1 (
  echo.
  echo Uninstall was cancelled or could not complete.
  pause
)
