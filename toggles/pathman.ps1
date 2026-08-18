<#
Adds (or removes if exists) a directory in the User PATH environment variable.

Examples:
  .\pathman.ps1                    Toggles current directory in User PATH
  .\pathman.ps1 D:\soft\bin        Toggles specified directory in User PATH
  .\pathman.ps1 .\ -Recurse        Toggles current dir and first-level subdirectories
  .\pathman.ps1 -List              Displays all User PATH entries (invalid paths in red)

by github.com/wincmd64
#>


# Supports -Confirm and -WhatIf switches
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Position = 0, ValueFromPipeline = $true)]
    [string]$Path,

    [switch]$List,
    [switch]$Recurse
)

# 1. Display list of User PATH entries if -List is specified
if ($List) {
    $currentPaths = [System.Environment]::GetEnvironmentVariable('PATH', 'User') -split [IO.Path]::PathSeparator
    foreach ($p in $currentPaths) {
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        if (Test-Path -LiteralPath $p -PathType Container) { Write-Host $p }
        else { Write-Host $p -ForegroundColor Red }
    }
    exit 0
}

# 2. Resolve relative paths (.\, ..\, subfolder -> absolute path)
if (-not $Path) { $Path = $PWD.Path }
$Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)

# 3. Validation
if (-not (Test-Path -LiteralPath $Path)) { Write-Warning "Directory '$Path' does not exist."; exit 1 }
if (-not (Test-Path -LiteralPath $Path -PathType Container)) { Write-Warning "Path '$Path' is a file. You can only add directories to PATH."; exit 1 }

# 4. Get target directories (including first-level subdirectories if -Recurse is set)
$pathsToProcess = @($Path.TrimEnd('\'))
if ($Recurse) {
    try {
        Get-ChildItem -LiteralPath $Path -Directory -ErrorAction Stop | ForEach-Object {
            $pathsToProcess += $_.FullName.TrimEnd('\')
        }
    }
    catch {
        Write-Warning "Cannot access subdirectories of '$Path': $($_.Exception.Message)"
    }
}

# 5. Retrieve current User PATH
$rawUserPath = [System.Environment]::GetEnvironmentVariable('PATH', 'User')
$arrPath = if ([string]::IsNullOrEmpty($rawUserPath)) { @() } else { $rawUserPath -split [IO.Path]::PathSeparator }

# Normalize array entries for exact string comparison (strip trailing backslashes)
$arrPathNormalized = $arrPath | ForEach-Object { $_.TrimEnd('\') }

$pathsToAdd = @()
$pathsToRemove = @()

foreach ($p in $pathsToProcess) {
    if ($arrPathNormalized -contains $p) {
        $pathsToRemove += $p
    } else {
        $pathsToAdd += $p
    }
}

# 6. Execute operations
if ($pathsToRemove.Count -gt 0) {
    Write-Host
    foreach ($item in $pathsToRemove) {
        if ($PSCmdlet.ShouldProcess($item, "Remove from User PATH")) {
            $arrPath = $arrPath | Where-Object { $_.TrimEnd('\') -ne $item }
            Write-Host " - Removed: $item" -ForegroundColor Magenta
        }
    }
}

if ($pathsToAdd.Count -gt 0) {
    Write-Host
    foreach ($item in $pathsToAdd) {
        if ($PSCmdlet.ShouldProcess($item, "Add to User PATH")) {
            $arrPath += $item
            Write-Host " + Added: $item" -ForegroundColor Green
        }
    }
}

# 7. Apply and save updated PATH to User environment registry
$newPath = ($arrPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join [IO.Path]::PathSeparator
[System.Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')

# Exiting
Write-Host
for ($s = 3; $s -gt 0; $s--) {
    Write-Host -NoNewline "`r Press any key to continue (or wait $s seconds)... " -BackgroundColor DarkGray
    for ($j = 0; $j -lt 20; $j++) {
        if ([Console]::KeyAvailable) { [Console]::ReadKey($true) | Out-Null; exit }
        Start-Sleep -m 50
    }
}