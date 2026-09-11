@echo off
chcp 65001 >nul
title Sowfkun Verse - Infrastructure Container Logs
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0infra-logs.ps1" %*
pause
