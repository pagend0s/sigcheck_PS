param(
    [switch]$SaveResults,
    [string]$ResultsPath
)

# ============================================================
# Configuration
# ============================================================

$resourcesMainDir = Split-Path -Path $PSCommandPath -Parent
$sigcheck = Join-Path `
    -Path $resourcesMainDir `
    -ChildPath 'sigcheck64.exe'

# Scan only common executable file types.
$Extensions = @(
    '*.exe',
    '*.dll',
    '*.sys',
    '*.ocx',
    '*.msi',
    '*.drv'
)

# To scan all files, use:
# $Extensions = $null

# Random delay between VirusTotal requests.
# The maximum value is exclusive.
# This configuration produces delays from 10 to 15 seconds.
[int]$MinimumDelaySeconds = 10
[int]$MaximumDelaySeconds = 16

# ============================================================
# Validate configuration
# ============================================================

if ($MinimumDelaySeconds -lt 0) {
    Write-Host `
        'MinimumDelaySeconds cannot be lower than zero.' `
        -ForegroundColor Red

    exit 1
}

if ($MaximumDelaySeconds -le $MinimumDelaySeconds) {
    Write-Host `
        'MaximumDelaySeconds must be greater than MinimumDelaySeconds.' `
        -ForegroundColor Red

    exit 1
}

# ============================================================
# Validate Sigcheck
# ============================================================

if (-not (Test-Path -LiteralPath $sigcheck -PathType Leaf)) {
    Write-Host `
        'sigcheck64.exe was not found:' `
        -ForegroundColor Red

    Write-Host $sigcheck -ForegroundColor Yellow

    exit 1
}

# ============================================================
# Configure results file
# ============================================================

if ($SaveResults) {
    if (
        $null -eq $ResultsPath -or
        $ResultsPath.Trim().Length -eq 0
    ) {
        $timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'

        $ResultsPath = Join-Path `
            -Path $resourcesMainDir `
            -ChildPath "Sigcheck_Results_$timestamp.txt"
    }
    elseif (-not [System.IO.Path]::IsPathRooted($ResultsPath)) {
        $ResultsPath = Join-Path `
            -Path $resourcesMainDir `
            -ChildPath $ResultsPath
    }

    try {
        $resultsDirectory = Split-Path `
            -Path $ResultsPath `
            -Parent

        if (
            $null -ne $resultsDirectory -and
            $resultsDirectory.Trim().Length -gt 0 -and
            -not (Test-Path -LiteralPath $resultsDirectory)
        ) {
            New-Item `
                -Path $resultsDirectory `
                -ItemType Directory `
                -Force |
                Out-Null
        }

        $header = @"
SIGCHECK / VIRUSTOTAL SCAN RESULTS
Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Sigcheck: $sigcheck
============================================================

"@

        # Creates a fresh UTF-8 results file.
        $header | Out-File `
            -LiteralPath $ResultsPath `
            -Encoding UTF8 `
            -Force

        Write-Host `
            'Results will be saved to:' `
            -ForegroundColor Green

        Write-Host `
            $ResultsPath `
            -ForegroundColor Cyan
    }
    catch {
        Write-Host `
            "Unable to create the results file: $ResultsPath" `
            -ForegroundColor Red

        Write-Host `
            $_.Exception.Message `
            -ForegroundColor Red

        exit 1
    }
}

# ============================================================
# Logging functions
# ============================================================

function Add-TextToResultsFile {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )

    if (-not $SaveResults) {
        return
    }

    try {
        $Text | Out-File `
            -LiteralPath $ResultsPath `
            -Encoding UTF8 `
            -Append `
            -ErrorAction Stop
    }
    catch {
        Write-Host `
            "Unable to write to the results file: $ResultsPath" `
            -ForegroundColor Red

        Write-Host `
            $_.Exception.Message `
            -ForegroundColor Red
    }
}

function Write-ScanLog {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Message,

        [string]$ForegroundColor = 'Gray'
    )

    Write-Host `
        $Message `
        -ForegroundColor $ForegroundColor

    if ($SaveResults) {
        Add-TextToResultsFile -Text $Message
    }
}

# ============================================================
# Folder selector
# ============================================================

function Select-Folder {
    param(
        [string]$Description = 'Select a folder to scan'
    )

    Add-Type `
        -AssemblyName System.Windows.Forms `
        -ErrorAction Stop

    while ($true) {
        $dialog = New-Object `
            System.Windows.Forms.FolderBrowserDialog

        try {
            if (
                $null -ne $script:text_msg -and
                $null -ne $script:text_msg.selectdir -and
                $script:text_msg.selectdir.ToString().Trim().Length -gt 0
            ) {
                $Description = $script:text_msg.selectdir.ToString()
            }

            $dialog.Description = $Description
            $dialog.ShowNewFolderButton = $false

            $result = $dialog.ShowDialog()

            if ($result.ToString() -eq 'OK') {
                return $dialog.SelectedPath
            }

            Write-Host `
                'Please select a folder.' `
                -ForegroundColor Red
        }
        finally {
            $dialog.Dispose()
        }
    }
}

# ============================================================
# Read Sigcheck redirected output
# ============================================================

function Read-SigcheckOutput {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return ''
    }

    try {
        $outputFile = Get-Item `
            -LiteralPath $Path `
            -ErrorAction Stop

        if ($outputFile.Length -eq 0) {
            return ''
        }
    }
    catch {
        return ''
    }

    try {
        # Sigcheck redirected output is normally UTF-16 LE.
        $text = Get-Content `
            -LiteralPath $Path `
            -Encoding Unicode `
            -Raw `
            -ErrorAction Stop

        if ($null -eq $text) {
            return ''
        }

        # Remove any remaining NUL characters.
        $text = $text -replace "`0", ''

        return $text.TrimEnd()
    }
    catch {
        # Fallback for Sigcheck versions using the Windows
        # system encoding instead of UTF-16.
        try {
            $text = Get-Content `
                -LiteralPath $Path `
                -Encoding Default `
                -Raw `
                -ErrorAction Stop

            if ($null -eq $text) {
                return ''
            }

            $text = $text -replace "`0", ''

            return $text.TrimEnd()
        }
        catch {
            return ''
        }
    }
}

# ============================================================
# Run Sigcheck
# ============================================================

function Invoke-Sigcheck {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    $stdoutTempFile = $null
    $stderrTempFile = $null

    try {
        if (
            $null -eq $FilePath -or
            $FilePath.Trim().Length -eq 0
        ) {
            throw 'The file path is empty.'
        }

        if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
            throw "The file does not exist: $FilePath"
        }

        $stdoutTempFile = New-TemporaryFile
        $stderrTempFile = New-TemporaryFile

        $stdoutPath = $stdoutTempFile.FullName
        $stderrPath = $stderrTempFile.FullName

        # Keep the file path as one argument, including paths
        # containing spaces or apostrophes.
        $escapedPath = $FilePath.Replace('"', '\"')
        $quotedPath = '"' + $escapedPath + '"'

        $arguments = @(
            '-accepteula'
            '-nobanner'
            '-vt'
            '-vrs'
            '-h'
            $quotedPath
        )

        $process = Start-Process `
            -FilePath $sigcheck `
            -ArgumentList $arguments `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath `
            -WindowStyle Hidden `
            -Wait `
            -PassThru `
            -ErrorAction Stop

        [int]$exitCode = $process.ExitCode

        [string]$standardOutput = Read-SigcheckOutput `
            -Path $stdoutPath

        [string]$errorOutput = Read-SigcheckOutput `
            -Path $stderrPath

        if (
            $null -ne $standardOutput -and
            $standardOutput.Trim().Length -gt 0
        ) {
            Write-Host $standardOutput

            if ($SaveResults) {
                Add-TextToResultsFile `
                    -Text $standardOutput
            }
        }

        if (
            $null -ne $errorOutput -and
            $errorOutput.Trim().Length -gt 0
        ) {
            Write-Host `
                $errorOutput `
                -ForegroundColor Yellow

            if ($SaveResults) {
                Add-TextToResultsFile `
                    -Text $errorOutput
            }
        }

        return New-Object PSObject -Property @{
            ExitCode = $exitCode
            Success  = ($exitCode -eq 0)
        }
    }
    catch {
        $errorMessage = 'Sigcheck execution error: {0}' -f `
            $_.Exception.Message

        Write-ScanLog `
            -Message $errorMessage `
            -ForegroundColor Red

        return New-Object PSObject -Property @{
            ExitCode = -1
            Success  = $false
        }
    }
    finally {
        if ($null -ne $stdoutTempFile) {
            Remove-Item `
                -LiteralPath $stdoutTempFile.FullName `
                -Force `
                -ErrorAction SilentlyContinue
        }

        if ($null -ne $stderrTempFile) {
            Remove-Item `
                -LiteralPath $stderrTempFile.FullName `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }
}

# ============================================================
# Main loop
# ============================================================

do {
    $inputDirectory = Select-Folder

    Write-ScanLog `
        -Message "`r`nSelected directory: $inputDirectory" `
        -ForegroundColor Yellow

    Write-Host `
        'Collecting files...' `
        -ForegroundColor DarkGray

    if ($null -ne $Extensions -and $Extensions.Count -gt 0) {
        $files = @(
            Get-ChildItem `
                -Path $inputDirectory `
                -Recurse `
                -File `
                -Include $Extensions `
                -ErrorAction SilentlyContinue
        )
    }
    else {
        $files = @(
            Get-ChildItem `
                -LiteralPath $inputDirectory `
                -Recurse `
                -File `
                -ErrorAction SilentlyContinue
        )
    }

    if ($files.Count -eq 0) {
        Write-ScanLog `
            -Message "No files were found under: $inputDirectory" `
            -ForegroundColor Yellow
    }
    else {
        [int]$count = $files.Count
        [int]$i = 0

        Write-ScanLog `
            -Message "Files found: $count" `
            -ForegroundColor Green

        foreach ($file in $files) {
            $i++

            if ($count -gt 0) {
                [double]$percentComplete = (
                    100.0 *
                    [double]$i /
                    [double]$count
                )

                if ($percentComplete -lt 0) {
                    $percentComplete = 0
                }

                if ($percentComplete -gt 100) {
                    $percentComplete = 100
                }
            }
            else {
                [double]$percentComplete = 0
            }

            [int]$progressValue = $percentComplete

            Write-Progress `
                -Activity 'Sigcheck / VirusTotal scan' `
                -Status "Scanning $i of $count`: $($file.Name)" `
                -CurrentOperation $file.FullName `
                -PercentComplete $progressValue

            $scanStart = Get-Date

            $scanHeader = @"

============================================================
File: $($file.FullName)
Scan: $i of $count
Progress: $progressValue%
Started: $($scanStart.ToString('yyyy-MM-dd HH:mm:ss'))
============================================================
"@

            Write-ScanLog `
                -Message $scanHeader `
                -ForegroundColor Cyan

            $sigcheckResult = Invoke-Sigcheck `
                -FilePath $file.FullName

            [int]$sigcheckExitCode = $sigcheckResult.ExitCode

            $scanEnd = Get-Date
            $duration = $scanEnd - $scanStart

            Write-ScanLog `
                -Message "Sigcheck exit code: $sigcheckExitCode" `
                -ForegroundColor DarkGray

            $finishedMessage = 'Finished: {0}' -f `
                $scanEnd.ToString('yyyy-MM-dd HH:mm:ss')

            Write-ScanLog `
                -Message $finishedMessage `
                -ForegroundColor DarkGray

            $durationMessage = 'Duration: {0:N1} seconds' -f `
                $duration.TotalSeconds

            Write-ScanLog `
                -Message $durationMessage `
                -ForegroundColor DarkGray

            # Do not delay after the final file.
            if ($i -lt $count) {
                [int]$delaySeconds = Get-Random `
                    -Minimum $MinimumDelaySeconds `
                    -Maximum $MaximumDelaySeconds

                Write-Host `
                    "Waiting $delaySeconds seconds to throttle VirusTotal requests." `
                    -ForegroundColor DarkGray

                Start-Sleep `
                    -Seconds $delaySeconds
            }
        }

        Write-Progress `
            -Activity 'Sigcheck / VirusTotal scan' `
            -Completed
    }

    # ========================================================
    # Directory summary
    # ========================================================

    if ($SaveResults) {
        $directorySummary = @"

============================================================
Directory scan finished: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Directory: $inputDirectory
Files processed: $($files.Count)
============================================================
"@

        Add-TextToResultsFile `
            -Text $directorySummary

        Write-Host `
            "`nResults were saved to:" `
            -ForegroundColor Green

        Write-Host `
            $ResultsPath `
            -ForegroundColor Cyan
    }

    # ========================================================
    # Continue or exit
    # ========================================================

    Write-Host `
        'Do you want to scan another folder? Type Q to quit: ' `
        -ForegroundColor Yellow `
        -NoNewline

    [string]$answer = Read-Host

    if ($null -eq $answer) {
        $answer = 'q'
    }

} until ($answer.Trim() -ieq 'q')

# ============================================================
# Final log entry
# ============================================================

if ($SaveResults) {
    $finishedMessage = "`r`nScript finished: {0}" -f `
        (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

    Add-TextToResultsFile `
        -Text $finishedMessage

    Write-Host `
        "`nFinal results file:" `
        -ForegroundColor Green

    Write-Host `
        $ResultsPath `
        -ForegroundColor Cyan
}
