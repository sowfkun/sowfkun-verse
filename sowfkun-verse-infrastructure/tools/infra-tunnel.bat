@echo off
chcp 65001 >nul
title Sowfkun Verse - JIT SSH Direct Infrastructure Controller
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0infra-tunnel.ps1" %*
if "%~1"=="" pause
