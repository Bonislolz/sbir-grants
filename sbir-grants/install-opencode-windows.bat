@echo off
chcp 65001 >nul
echo SBIR Skill - OpenCode Windows Installer
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0install-opencode-windows.ps1"
if errorlevel 1 pause
