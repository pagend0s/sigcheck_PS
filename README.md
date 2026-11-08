# Sigcheck VirusTotal Scanner
A Windows scanner that uses Microsoft Sysinternals Sigcheck to inspect executable files and check available VirusTotal results.

Requirements
Windows PowerShell 5.1 or later
sigcheck64.exe
Internet connection

## Project Structure

---
project/
├── Start_Sigcheck.bat
└── resources/
    ├── sigcheck.ps1
    └── sigcheck64.exe
---

Usage
Run:

Start_Sigcheck.bat
Select a folder and wait for the scan to complete.

The results are saved to:

wyniki.txt
Scanned File Types
.exe
.dll
.sys
.ocx
.msi
.drv
