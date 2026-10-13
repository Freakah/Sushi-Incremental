@echo off
REM Double-click to start Rojo, then in Studio: Plugins > Rojo > Connect.
REM Close this window to stop syncing.
cd /d "%~dp0"
rojo.exe serve
pause
