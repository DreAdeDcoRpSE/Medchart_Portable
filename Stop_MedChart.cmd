@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Stop-MedChart.ps1"
echo.
echo If MedChart is still accessible, check the messages above.
pause
