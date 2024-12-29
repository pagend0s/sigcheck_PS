@echo off
pushd %~dp0

powershell -WindowStyle Normal -ExecutionPolicy Bypass -File .\resources\sigcheck.ps1

goto EXIT

:EXIT
