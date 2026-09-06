@echo off
chcp 65001 >nul
title Sowfkun Verse - Egress Gateway Multi-Cluster Deployer
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy-gateway.ps1" %*
pause
