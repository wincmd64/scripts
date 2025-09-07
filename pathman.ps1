# Adds or removes if exist a directory from the user PATH environment variable

param([string]$Path)
if (-not $Path) {Write-Host "Usage: .\pathman.ps1 'X:\your\path'" ; exit 1 }
if (-not (Test-Path -Path $Path)) { Write-Warning "The directory '$Path' does not exist." ; exit 1 }

# Get current User PATH
$currentPath = [System.Environment]::GetEnvironmentVariable('PATH', 'User')
$arrPath = @()
if (-not [string]::IsNullOrEmpty($currentPath)) {
    $arrPath = $currentPath -split [IO.Path]::PathSeparator
}

# Check if path exists
$exists = $false
foreach ($item in $arrPath) {
    if ($item.TrimEnd('\') -eq $Path.TrimEnd('\')) {
        $exists = $true
        break
    }
}

if ($exists) {
    # Remove all occurrences
    $newPath = ($arrPath | Where-Object { $_.TrimEnd('\') -ne $Path.TrimEnd('\') }) -join [IO.Path]::PathSeparator
    [System.Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')
    Write-Host "Removed from PATH: " -ForegroundColor Magenta -NoNewline; Write-Host $Path.TrimEnd('\')
} else {
    # Add normalized path
    $newPath = ($arrPath + $Path.TrimEnd('\')) -join [IO.Path]::PathSeparator
    [System.Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')
    Write-Host "Added to PATH: " -ForegroundColor Green -NoNewline; Write-Host $Path.TrimEnd('\')
}

sleep 2