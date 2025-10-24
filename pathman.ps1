# Adds or removes if exist a directory from the user PATH environment variable

param(
    [string]$Path,
    [switch]$List
)
# List current user PATH if -List is specified
if ($List) {
    $currentPath = [System.Environment]::GetEnvironmentVariable('PATH', 'User')
    $currentPath -split [IO.Path]::PathSeparator | ForEach-Object { Write-Host $_ }
    exit 0
}
# If no path provided, use current directory
if (-not $Path) {
    $pwd = Get-Location
    if ($pwd.Provider.Name -ne 'FileSystem') { Write-Warning "Not a filesystem path."; exit 1 }
    $Path = $pwd.ProviderPath
}
if (-not (Test-Path -Path $Path)) { Write-Warning "The directory '$Path' does not exist." ; exit 1 }
if ($Path -match '^[.]|^\\(?!\\)') {Write-Warning "Only absolute paths or UNC are allowed." ; exit 1}

# Get current User PATH
$currentPath = [System.Environment]::GetEnvironmentVariable('PATH', 'User')
# Split PATH into array
$arrPath = if ([string]::IsNullOrEmpty($currentPath)) { @() } else { $currentPath -split [IO.Path]::PathSeparator }
# Check if already exists + removing trailing backslashes
$exists = ($arrPath | ForEach-Object TrimEnd('\')) -contains $Path.TrimEnd('\')

if ($exists) {
    Write-Host "Remove from PATH? " -ForegroundColor Magenta -NoNewline; Write-Host $Path.TrimEnd('\'); pause
    $newPath = ($arrPath | Where-Object { $_.TrimEnd('\') -ne $Path.TrimEnd('\') }) -join [IO.Path]::PathSeparator
} else {
    if (-not $PSBoundParameters.ContainsKey('Path')) {Write-Host "Add current directory to PATH?"; pause}
    $newPath = ($arrPath + $Path.TrimEnd('\')) -join [IO.Path]::PathSeparator
    Write-Host "Added to PATH: " -ForegroundColor Green -NoNewline; Write-Host $Path.TrimEnd('\')
}
[System.Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')
Write-Host "`nDONE."
sleep 1