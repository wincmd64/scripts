# Adds or removes if exist a directory from the user PATH environment variable

param([string]$Path)
if (-not $Path) {Write-Host "Usage: .\pathman.ps1 'X:\your\path'" ; exit 1 }
if (-not (Test-Path -Path $Path)) { Write-Warning "The directory '$Path' does not exist." ; exit 1 }

# Get current User PATH
$currentPath = [System.Environment]::GetEnvironmentVariable('PATH', 'User')
# Split PATH into array
$arrPath = if ([string]::IsNullOrEmpty($currentPath)) { @() } else { $currentPath -split [IO.Path]::PathSeparator }
# Check if already exists + removing trailing backslashes
$exists = ($arrPath | ForEach-Object TrimEnd('\')) -contains $Path.TrimEnd('\')

if ($exists) {
    $newPath = ($arrPath | Where-Object { $_.TrimEnd('\') -ne $Path.TrimEnd('\') }) -join [IO.Path]::PathSeparator
    Write-Host "Removed from PATH: " -ForegroundColor Magenta -NoNewline; Write-Host $Path.TrimEnd('\')
} else {
    $newPath = ($arrPath + $Path.TrimEnd('\')) -join [IO.Path]::PathSeparator
    Write-Host "Added to PATH: " -ForegroundColor Green -NoNewline; Write-Host $Path.TrimEnd('\')
}
[System.Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')
sleep 2