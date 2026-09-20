@echo off
setlocal
REM Windows CPU convenience launcher. Extra arguments are forwarded to QND.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0qnd.ps1" start -Profile windows-cpu -Bind 0.0.0.0 %*
endlocal
