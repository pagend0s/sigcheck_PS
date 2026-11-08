#Sigcheck VirusTotal Scanner

A simple Windows scanner that uses Microsoft Sysinternals Sigcheck to inspect executable files and check available results from VirusTotal.

Requirements
Windows PowerShell 5.1 or later
sigcheck64.exe
Internet connection for VirusTotal checks

Project structure
project
├── Start_Sigcheck.bat
└── resources
    ├── sigcheck.ps1
    └── sigcheck64.exe
Usage

Run the existing BAT file:

  Start_Sigcheck.bat

The launcher runs:
powershell -WindowStyle Normal -ExecutionPolicy Bypass -File .\resources\sigcheck.ps1 -SaveResults "wyniki.txt"

After starting:

Select a folder to scan.
Wait for the scan to complete.
Enter Q when asked whether to scan another folder.

Scanned files
By default, the script scans:
.exe
.dll
.sys
.ocx
.msi
.drv
A random delay is applied between files to reduce the frequency of VirusTotal requests.

