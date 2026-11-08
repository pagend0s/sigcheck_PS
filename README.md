# Sigcheck VirusTotal Scanner

A Windows PowerShell scanner that uses Sigcheck, an official utility from Microsoft Sysinternals, to inspect digital signatures, calculate file hashes, and check available VirusTotal results.
https://learn.microsoft.com/sysinternals/downloads/sigcheck

Project Structure

```
sigcheck_PS/
├── sigcheck.bat
└── resources/
    ├── sigcheck.ps1
    └── sigcheck64.exe

```

Usage
Run:

Start sigcheck.bat
Select a folder and wait for the scan to complete.

The results as default are saved to:

powershell -WindowStyle Normal -ExecutionPolicy Bypass -File .\resources\sigcheck.ps1 -SaveResults "result.txt"

Scanned File Types
.exe
.dll
.sys
.ocx
.msi
.drv

## A random delay is applied between files to reduce the frequency of VirusTotal requests.
