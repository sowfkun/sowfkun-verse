@echo off
chcp 65001 >nul
title Sowfkun Verse - Core API Multi-Cluster Deployer
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy-api.ps1" %*
pause
