@echo off
setlocal
REM Adds LAN bind only; profile selection and any extra arguments remain with QND.
REM For the Debian/LXC CPU target, use start-cpu-lan.sh instead.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0qnd.ps1" start -Bind 0.0.0.0 %*
endlocal
