@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0qnd.ps1" start -Profile nvidia-rtx3060 -Bind 0.0.0.0 %*
endlocal
