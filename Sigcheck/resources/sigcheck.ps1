$recources_main_dir = Split-Path $PSCommandPath -Parent
$sigcheck            = Join-Path $recources_main_dir 'sigcheck64.exe'

# Optional: limit to common executable types (uncomment to reduce VT calls)
$Extensions = @('*.exe','*.dll','*.sys','*.ocx','*.msi','*.drv')
# $Extensions = $null

function Select-Folder {
    param([string]$Description = 'Select Folder')
    Add-Type -AssemblyName System.Windows.Forms

    $dir = 0
    do {
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        if ($script:text_msg -and $script:text_msg.selectdir) {
            $Description = $script:text_msg.selectdir
        }
        $dialog.Description = $Description

        $result = $dialog.ShowDialog()
        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            return $dialog.SelectedPath
        } else {
            Write-Host 'PLEASE SET DIR !!!' -ForegroundColor Red
            $dir = 0
        }
    } while ($dir -eq 0)
}

do {
    $input_directory = Select-Folder

    # Collect files recursively; filter if $Extensions is defined
    if ($Extensions) {
        $files = Get-ChildItem -Path $input_directory -Recurse -File -Include $Extensions -ErrorAction SilentlyContinue
    } else {
        $files = Get-ChildItem -Path $input_directory -Recurse -File -ErrorAction SilentlyContinue
    }

    if (-not $files) {
        Write-Host "No files found under: $input_directory" -ForegroundColor Yellow
    } else {
        $count = $files.Count
        $i = 0

        foreach ($file in $files) {
            $i++

            # Proper progress bar
            Write-Host "Scanning $i of $count`n" -PercentComplete ([math]::Round(100.0 * $i / $count, 2)) -ForegroundColor Yellow
            Write-Host "Scanning (VT): $($file.FullName)" -ForegroundColor Cyan

            # --- Run sigcheck (upload unknowns; open report on detections; show hashes) ---
            & $sigcheck -vt -vrs -h "$($file.FullName)"
            # If you prefer not to auto-open reports, switch to:  -vs  (instead of -vrs)

            # --- Random sleep PER FILE: 3..6 seconds (Max is exclusive, so use 7) ---
            $delaySeconds = Get-Random -Minimum 10 -Maximum 15   # 3,4,5,6
            Write-Host ("Sleeping {0}s to throttle VT" -f $delaySeconds) -ForegroundColor DarkGray
            Start-Sleep -Seconds $delaySeconds

            # Alternative with millisecond jitter:
            # $delayMs = Get-Random -Minimum 3000 -Maximum 6001  # 3000..6000 inclusive
            # Write-Host ("Sleeping {0} ms to throttle VT…" -f $delayMs) -ForegroundColor DarkGray
            # Start-Sleep -Milliseconds $delayMs
        }
    }

    Write-Host 'DO YOU WANT TO CONTINUE ? WHEN NOT HIT q: ' -ForegroundColor Yellow -NoNewLine
    [string]$s = Read-Host

} until ($s -eq 'q')
