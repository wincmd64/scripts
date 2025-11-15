<#
.SYNOPSIS
  Removes zero-length files and empty directories within a given directory tree.

.DESCRIPTION
  -dir      Directory to scan; default is %temp%
  -test     Test mode. No deletions are performed; only counts are displayed. Logging is ignored.
  -nolog    Disables logging. By default, script logs to %TEMP%\<scriptname>.log

.EXAMPLE
  powershell -Ep Bypass empty.ps1 -dir 'C:\temp'
  
.LINK
  https://github.com/wincmd64
#>

param (
    [string]$dir = $env:TEMP,
    [switch]$test,
    [switch]$nolog
)

# --- Path validation ---
if (-not (Test-Path -LiteralPath $dir)) {
    Write-Warning "The directory '$dir' does not exist."
    exit 1
}
# Normalize path (resolve relative paths if possible)
$resolvedDir = (Resolve-Path -LiteralPath $dir -ErrorAction SilentlyContinue).Path
if (-not $resolvedDir) { $resolvedDir = $dir }
Write-Host "`n Scanning path: $resolvedDir"

# --- Logging settings ---
$DateFormat = 'yyyy-MM-dd HH:mm'  # Change timestamp format if needed
$DoLog = -not $nolog.IsPresent -and -not $test      # logging is ignored in test mode
$logFile = Join-Path $env:TEMP "$(($MyInvocation.MyCommand.Name -split '\.')[0]).log"

# Error log buffer and index (reset on each run)
$script:logEntries = @()
$script:logIndex   = 1

function Add-ErrorLogEntry {
    param(
        [Parameter(Mandatory)][System.IO.FileSystemInfo]$Item,
        [Parameter(Mandatory)]$ErrorRecord
    )
    if (-not $DoLog) { return }

    $stamp = Get-Date -Format $DateFormat
    # Single-line exception text (strip CR/LF), WITHOUT a separate file/dir name
    $msg = ($ErrorRecord.Exception.Message -replace '\r?\n',' ').Trim()

    # Example: 2025-09-09-14-04 [1] Access is denied for path "C:\...\file.tmp".
    $script:logEntries += ("{0} [{1}] {2}" -f $stamp, $script:logIndex, $msg)
    $script:logIndex++
}

# --- Counters ---
$deletedFiles   = 0
$deletedFolders = 0
$errors         = 0

# --- Deletion with error handling ---
function Try-Remove {
    param($item)
    try {
        Remove-Item -LiteralPath $item.FullName -Force -ErrorAction Stop
        return $true
    } catch {
        Add-ErrorLogEntry -Item $item -ErrorRecord $_
        $script:errors++
        return $false
    }
}

# --- Remove empty files (skip reparse points) ---
Get-ChildItem -Path $resolvedDir -File -Recurse -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Length -eq 0 -and -not $_.Attributes.HasFlag([IO.FileAttributes]::ReparsePoint) } |
    ForEach-Object {
        if ($test) { $deletedFiles++ } else { if (Try-Remove $_) { $deletedFiles++ } }
    }

# --- Remove empty folders (deepest-first, skip reparse points) ---
Get-ChildItem -Path $resolvedDir -Directory -Recurse -Force -ErrorAction SilentlyContinue |
    Where-Object { -not $_.Attributes.HasFlag([IO.FileAttributes]::ReparsePoint) } |
    Sort-Object { ($_.FullName -split '[\\/]').Count } -Descending |
    ForEach-Object {
        # Fast emptiness check: probe only the first child
        $hasAny = Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $hasAny) {
            if ($test) { $deletedFolders++ } else { if (Try-Remove $_) { $deletedFolders++ } }
        }
    }

# --- Console summary ---
if ($test) {
    $summary = "TEST MODE. Would remove:`n  empty files:   $deletedFiles`n  empty folders: $deletedFolders"
    Write-Host " $summary`n" -ForegroundColor Cyan
} else {
    Write-Host " Deleted empty files:   $deletedFiles"
    Write-Host " Deleted empty folders: $deletedFolders"
    Write-Host " Errors: $errors"
    Write-Host ""
}

# --- Log summary (append) ---
if ($DoLog) {
    $stamp = Get-Date -Format $DateFormat

    # Run summary
    $block = @(
        "$stamp Path: $resolvedDir"
        "$stamp Deleted empty files:   $deletedFiles"
        "$stamp Deleted empty folders: $deletedFolders"
    )

    if ($errors -gt 0) {
        # If there are errors, add the "Errors" line and immediately follow with error lines (no blank line between)
        $block += "$stamp Errors: $errors"
        if ($script:logEntries.Count -gt 0) {
            $block += $script:logEntries
        }
    }
    # Add a blank line only at the end of the run block as a separator
    $block += ''

    # Ensure the file exists and append the block
    if (-not (Test-Path -LiteralPath $logFile)) {
        $null = New-Item -ItemType File -Path $logFile -Force -ErrorAction SilentlyContinue
    }
    $block | Out-File -FilePath $logFile -Encoding UTF8 -Append

    Write-Host " Log file: $logFile`n" -ForegroundColor Cyan
}
