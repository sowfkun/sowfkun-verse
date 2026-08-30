@echo off
title Sowfkun Master CLI Tool
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sowfkun.ps1" %*
if "%1"=="" pause
